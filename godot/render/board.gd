## The board: the diorama built from the real map, and the markers on it.
##
## The ground is a `Diorama` (#324): terraces from the map's terrain layer with corrugated
## cliffs, the river in its gorge, a road bed, scatter, and render-only country past the map
## that fades into the Environment's haze, so no edge of the world shows. On top of it the
## board draws a pencil circle on each socket, spilled Blot ink at each spawn and the
## Heartstone. Everything that stands on the board (towers, foes, guards, the highlight, the
## range ring, the tap picking) reads `surface_height`, which is the ground the diorama drew.
## Set `map_seed` (also in the editor: this is a `@tool` script) and the board rebuilds from
## `MapGen.generate`; `show_map` draws a map the game already made. It only reads the map, and
## every random-looking choice comes from a hash of the cell and the seed, so the same seed
## always looks the same.
@tool
class_name Board
extends Node3D

const TERRAIN := "res://assets/models/terrain/"
## The top of the road, where foes and guards walk (the valley floor is 0).
const ROAD_HEIGHT := TerrainField.ROAD_HEIGHT
const GROUND_HEIGHT := 0.0
## Metres from one terrace to the next (`TerrainField.TERRACE_STEP`), and the top of each
## terrace level, which is also the top of a socket block on that elevation level.
const TERRACE_STEP := TerrainField.TERRACE_STEP
const LEVEL_HEIGHTS: Array[float] = [
	0.0,
	TerrainField.TERRACE_STEP,
	2.0 * TerrainField.TERRACE_STEP,
	3.0 * TerrainField.TERRACE_STEP,
	4.0 * TerrainField.TERRACE_STEP,
]
## Fallback box colours, used only when a model file is missing; the dark one is also the
## back of the foes' health bars.
const OVERLAY_COLOUR := Color("f4efe0")
const DESK_COLOUR := Color("1c2b22")
const SPAWN_COLOUR := Color("c0392b")
const HEARTSTONE_COLOUR := Color("2ee6d6")
## The box that stands in for the spilled ink when its model is missing.
const SPAWN_BOX := Vector3(0.7, 0.9, 0.7)
const SPAWN_MODEL := "res://assets/models/terrain/blot_spawn.glb"
## The owner's greybox Heartstone and how much of its footprint's width it fills.
const HEARTSTONE_MODEL := "res://assets/models/towers/heartstone.glb"
const HEARTSTONE_FILL := 0.9

## The seed of the map to draw. Changing it rebuilds the board.
@export var map_seed: int = 1:
	set(value):
		map_seed = value
		if is_node_ready() and not _quiet:
			rebuild()

## Whether the board draws `map_seed` when it enters the tree. The game's scene turns it off,
## because main draws the game's own map at once (`show_map`), so the diorama is built once;
## the editor always draws.
@export var build_on_ready: bool = true

var map: GameMap
var road_count: int = 0
var ground_count: int = 0
var socket_count: int = 0
var spawn_marker: MeshInstance3D
var heartstone_marker: MeshInstance3D
## Every spilled-ink spawn drawn (the first is `spawn_marker`).
var spawn_count: int = 0
## The ground, rebuilt with the board (its builders are its children).
var diorama: Diorama
## How many times the board has built its diorama (a new map builds once).
var builds: int = 0
# what rebuild() made, so it never frees a node someone else put under the board
var _built: Array[Node] = []
# set while `show_map` records the seed, so the setter does not rebuild
var _quiet := false
# the transform of every socket overlay, kept because the headless renderer cannot
# read a MultiMesh back
var _socket_transforms: Array[Transform3D] = []


func _ready() -> void:
	if map == null and (build_on_ready or Engine.is_editor_hint()):
		rebuild()


## Gives the board's size back to the game board, so no later board inherits a map's size.
func _exit_tree() -> void:
	if map != null:
		BoardSpace.reset()


## Draws the map for `map_seed` again from scratch.
func rebuild() -> void:
	# the default board is the map the game plays (the sectioned valley, or its fallback)
	_draw(MapGen.game_map(map_seed))


## Draws a map the game made (the same map `map_seed` would give, without making it again),
## with the game's routes for the road beds. A map the board already shows is only adopted.
func show_map(source: GameMap, routes: Array[Route] = []) -> void:
	if (
		map != null
		and map.seed == source.seed
		and map.cols == source.cols
		and map.rows == source.rows
		and map.path == source.path
	):
		map = source
		diorama.field.map = source
		if not routes.is_empty():
			diorama.field.routes = routes
		return
	_quiet = true
	map_seed = source.seed
	_quiet = false
	_draw(source, routes)


## The height of the top of a cell: the road, the water in the river's gorge, or the terrace
## the diorama drew there (a socket block stands on its elevation level's terrace).
func surface_height(cell: Vector2i) -> float:
	if diorama == null or diorama.field == null:
		return GROUND_HEIGHT
	return diorama.field.surface_height(cell)


## The transform drawn for the index-th socket overlay (centred on its block, on its level).
func socket_transform(index: int) -> Transform3D:
	return _socket_transforms[index]


func _draw(source: GameMap, routes: Array[Route] = []) -> void:
	for child in _built:
		remove_child(child)
		child.queue_free()
	_built.clear()
	_socket_transforms.clear()
	map = source
	# every BoardSpace conversion, the camera's framing and the pan limits follow this map's size
	BoardSpace.use_map(map.cols, map.rows)
	if diorama == null:
		diorama = Diorama.new()
		diorama.name = "Diorama"
		add_child(diorama)
	for builder_slot in Diorama.SLOTS:
		var part := diorama.builder(builder_slot)
		if part != null:
			part.clear()
	diorama.build(map, routes)
	builds += 1
	_count_cells()
	_add_socket_overlays()
	_add_markers()


func _count_cells() -> void:
	var road := {}
	for route in map.routes:
		for cell in route:
			road[cell] = true
	road_count = road.size()
	socket_count = map.sockets.size()
	ground_count = 0
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			if not road.has(cell) and map.socket_anchor_at(cell) == GameMap.NO_SOCKET:
				ground_count += 1


## The pencil circle on every socket block, centred on the block on top of its terrace.
func _add_socket_overlays() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var instance := MultiMeshInstance3D.new()
	instance.name = "SocketOverlays"
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := PaperLook.dress(ModelLoader.mesh(TERRAIN + "overlay_socket_empty_2x2.glb"))
	if mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(float(map.footprint), 0.02, float(map.footprint))
		box.center_offset = Vector3(0.0, 0.01, 0.0)
		mesh = box
		instance.material_override = _material(OVERLAY_COLOUR)
	multimesh.mesh = mesh
	multimesh.instance_count = map.sockets.size()
	for i in map.sockets.size():
		var anchor := map.sockets[i]
		var at := BoardSpace.footprint_centre(anchor, map.footprint)
		at.y = surface_height(anchor)
		var tile := Transform3D(Basis.IDENTITY, at)
		multimesh.set_instance_transform(i, tile)
		_socket_transforms.append(tile)
	instance.multimesh = multimesh
	_add(instance)


func _add_markers() -> void:
	var start := map.path[0]
	var span := map.heartstone.size.x
	spawn_marker = _marker("Spawn", start, 1, SPAWN_COLOUR, SPAWN_BOX)
	_use_spawn_model(spawn_marker, map.path)
	spawn_count = 1
	# the other spawn sources live under one node, so the board's children stay the same
	var others := Node3D.new()
	others.name = "OtherSpawns"
	for route in map.routes:
		if route[0] != start:
			var extra := MeshInstance3D.new()
			extra.position = BoardSpace.cell_to_world(route[0].x, route[0].y)
			# the box stands in when the model file is missing, as for the first spawn
			var box := BoxMesh.new()
			box.size = SPAWN_BOX
			extra.mesh = box
			extra.material_override = _material(SPAWN_COLOUR)
			extra.position.y = box.size.y / 2.0
			_use_spawn_model(extra, route)
			others.add_child(extra)
			spawn_count += 1
	_add(others)
	heartstone_marker = _marker(
		"Heartstone",
		map.heartstone.position,
		span,
		HEARTSTONE_COLOUR,
		Vector3(0.7 * float(span), 1.2, 0.7 * float(span))
	)
	_use_heartstone_model(span)


## The owner's Heartstone model instead of the box, as wide as most of its footprint and
## standing on the ground; a missing file leaves the box.
func _use_heartstone_model(span: int) -> void:
	var mesh := PaperLook.dress(ModelLoader.mesh(HEARTSTONE_MODEL))
	if mesh == null:
		return
	var box := mesh.get_aabb()
	var scale := float(span) * HEARTSTONE_FILL / box.size.x
	heartstone_marker.mesh = mesh
	heartstone_marker.material_override = null
	heartstone_marker.scale = Vector3(scale, scale, scale)
	heartstone_marker.position.y = (
		diorama.field.top_at(map.heartstone.position) - box.position.y * scale
	)


func _marker(
	node_name: String, cell: Vector2i, span: int, colour: Color, size: Vector3
) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = node_name
	var box := BoxMesh.new()
	box.size = size
	marker.mesh = box
	marker.position = BoardSpace.footprint_centre(cell, span) + Vector3(0.0, size.y / 2.0, 0.0)
	marker.material_override = _material(colour)
	_add(marker)
	return marker


## The spilled ink and its bottle at the start of `route`, the bottle lying off the map.
func _use_spawn_model(marker: MeshInstance3D, route: Array) -> void:
	var mesh := PaperLook.dress(ModelLoader.mesh(SPAWN_MODEL))
	if mesh == null:
		return
	var inward := Vector2(route[1] - route[0])
	marker.mesh = mesh
	marker.material_override = null
	marker.position.y = 0.0
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.rotation = Vector3(0.0, atan2(-inward.y, inward.x), 0.0)


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
