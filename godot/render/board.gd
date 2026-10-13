## The board as flat greybox tiles, drawn from the real map.
##
## A flat strip for every road cell (the main road brown, a detour lighter), a
## low dark tile for plain ground, a raised tile for every socket block (the pre-etched
## tower sites: higher on higher elevation levels, paler on the mat, browner on
## cardboard), and a marker for the spawn and the Heartstone. One MultiMesh each
## for the road, the ground and the sockets, so the board is a handful of draw
## calls. Set `map_seed` (also in the editor: this is a `@tool` script) and the
## board rebuilds from `MapGen.generate`. It only reads the map.
@tool
class_name Board
extends Node3D

const RULES := preload("res://content/map_rules.gd")
const FOOTPRINT := 0.9
const ROAD_FOOTPRINT := 0.96
const ROAD_HEIGHT := 0.06
const GROUND_HEIGHT := 0.12
const SOCKET_BASE_HEIGHT := 0.3
const SOCKET_LEVEL_STEP := 0.22
const GROUND_TILE_COLOUR := Color("2f5a3a")
const SOCKET_COLOURS: Array[Color] = [Color("e9e4d0"), Color("c9a46a"), Color("8d6e4a")]
const MAIN_ROAD_COLOUR := Color("8a6a43")
const DETOUR_ROAD_COLOUR := Color("b99a6b")
const GROUND_COLOUR := Color("1c2b22")
const SPAWN_COLOUR := Color("c0392b")
const HEARTSTONE_COLOUR := Color("2ee6d6")
## The owner's greybox Heartstone and how much of its footprint's width it fills.
const HEARTSTONE_MODEL := "res://assets/models/towers/heartstone.glb"
const HEARTSTONE_FILL := 0.9
const GROUND_MARGIN := 3.0

## The seed of the map to draw. Changing it rebuilds the board.
@export var map_seed: int = 1:
	set(value):
		map_seed = value
		if is_node_ready():
			rebuild()

var map: GameMap
var road_count: int = 0
var ground_count: int = 0
var socket_count: int = 0
var spawn_marker: MeshInstance3D
var heartstone_marker: MeshInstance3D
# what rebuild() made, so it never frees a node someone else put under the board
var _built: Array[Node] = []
# the transform of every socket tile, kept because the headless renderer cannot
# read a MultiMesh back
var _socket_transforms: Array[Transform3D] = []


func _ready() -> void:
	rebuild()


## Draws the map for `map_seed` again from scratch.
func rebuild() -> void:
	for child in _built:
		remove_child(child)
		child.queue_free()
	_built.clear()
	_socket_transforms.clear()
	map = MapGen.generate(map_seed)
	_add_ground()
	_add_tiles()
	_add_markers()


## The height of the tile on a cell: the road is flat, plain ground is low, and
## a socket stands higher with its elevation level.
func surface_height(cell: Vector2i) -> float:
	if map == null:
		return GROUND_HEIGHT
	if map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD:
		return ROAD_HEIGHT
	if map.socket_anchor_at(cell) != GameMap.NO_SOCKET:
		return SOCKET_BASE_HEIGHT + SOCKET_LEVEL_STEP * float(map.elevation_at(cell))
	return GROUND_HEIGHT


## The transform drawn for the index-th socket tile (its block's box).
func socket_transform(index: int) -> Transform3D:
	return _socket_transforms[index]


func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var size := BoardSpace.size()
	plane.size = Vector2(size.x + GROUND_MARGIN * 2.0, size.y + GROUND_MARGIN * 2.0)
	ground.mesh = plane
	ground.position.y = -0.01
	ground.material_override = _material(GROUND_COLOUR)
	_add(ground)


func _add_tiles() -> void:
	var main_cells := {}
	for cell in map.path:
		main_cells[cell] = true
	var road := {}
	for route in map.routes:
		for cell in route:
			road[cell] = main_cells.has(cell)
	var ground: Array[Vector2i] = []
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			if not road.has(cell) and map.socket_anchor_at(cell) == GameMap.NO_SOCKET:
				ground.append(cell)
	var road_cells: Array[Vector2i] = []
	var road_colours: Array[Color] = []
	for cell in road:
		road_cells.append(cell)
		road_colours.append(MAIN_ROAD_COLOUR if road[cell] else DETOUR_ROAD_COLOUR)
	var socket_colours: Array[Color] = []
	for cell in map.sockets:
		socket_colours.append(SOCKET_COLOURS[map.elevation_at(cell)])
	var ground_colours: Array[Color] = []
	ground_colours.resize(ground.size())
	ground_colours.fill(GROUND_TILE_COLOUR)
	road_count = road_cells.size()
	ground_count = ground.size()
	socket_count = map.sockets.size()
	_add(_tiles("Road", road_cells, road_colours, ROAD_FOOTPRINT))
	_add(_tiles("Ground", ground, ground_colours, FOOTPRINT))
	_add(_tiles("Sockets", map.sockets, socket_colours, FOOTPRINT, map.footprint))


## One MultiMesh holding a box per cell (or per block of `span` cells, given its
## top-left cell), each with its own colour, as tall as `surface_height` says.
func _tiles(
	node_name: String,
	cells: Array[Vector2i],
	colours: Array[Color],
	footprint: float,
	span: int = 1
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(footprint, 1.0, footprint)
	multimesh.mesh = box
	multimesh.instance_count = cells.size()
	for i in cells.size():
		var height := surface_height(cells[i])
		var at := BoardSpace.footprint_centre(cells[i], span)
		at.y = height / 2.0
		var tile := Transform3D(Basis.from_scale(Vector3(float(span), height, float(span))), at)
		multimesh.set_instance_transform(i, tile)
		if node_name == "Sockets":
			_socket_transforms.append(tile)
		multimesh.set_instance_color(i, colours[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
	return instance


func _add_markers() -> void:
	var start := map.path[0]
	var span := map.heartstone.size.x
	spawn_marker = _marker("Spawn", start, 1, SPAWN_COLOUR, Vector3(0.7, 0.9, 0.7))
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
	var mesh := ModelLoader.mesh(HEARTSTONE_MODEL)
	if mesh == null:
		return
	var box := mesh.get_aabb()
	var scale := float(span) * HEARTSTONE_FILL / box.size.x
	heartstone_marker.mesh = mesh
	heartstone_marker.material_override = null
	heartstone_marker.scale = Vector3(scale, scale, scale)
	heartstone_marker.position.y = -box.position.y * scale


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


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
