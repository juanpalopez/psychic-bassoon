## The board drawn from the real map with the owner's terrain models.
##
## The paper mat under plain ground (and level 0 sockets), the lane under every road
## cell, a cardboard or paperboard rise under a socket block on elevation 1 or 2, an
## etched overlay on each socket, and a desk skirt two tiles thick around the board
## (with the odd eraser and pencil). One MultiMesh per model, so the board is a handful
## of draw calls. A missing model falls back to a plain coloured box. Set `map_seed`
## (also in the editor: this is a `@tool` script) and the board rebuilds from
## `MapGen.generate`. It only reads the map.
@tool
class_name Board
extends Node3D

const RULES := preload("res://content/map_rules.gd")
const TERRAIN := "res://assets/models/terrain/"
## The top of the lane, a hair above the mat so a foe walks on it.
const ROAD_HEIGHT := 0.01
const GROUND_HEIGHT := 0.0
## The top of the rise under a socket block, by elevation level.
const LEVEL_HEIGHTS: Array[float] = [0.0, 1.0, 2.0]
const SKIRT_THICKNESS := 2
## Every nth skirt tile is an eraser or a pencil instead of plain desk.
const ERASER_EVERY := 23
const PENCIL_EVERY := 29
## Fallback box colours, used only when a model file is missing.
const MAT_COLOUR := Color("2f5a3a")
const LANE_COLOUR := Color("8a6a43")
const LEVEL_COLOURS: Array[Color] = [Color("e9e4d0"), Color("c9a46a"), Color("8d6e4a")]
const OVERLAY_COLOUR := Color("f4efe0")
const DESK_COLOUR := Color("1c2b22")
const SPAWN_COLOUR := Color("c0392b")
const HEARTSTONE_COLOUR := Color("2ee6d6")
## The owner's greybox Heartstone and how much of its footprint's width it fills.
const HEARTSTONE_MODEL := "res://assets/models/towers/heartstone.glb"
const HEARTSTONE_FILL := 0.9

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
## The cells of the desk skirt, off the grid, kept for the same reason.
var skirt_cells: Array[Vector2i] = []
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
	skirt_cells.clear()
	map = MapGen.generate(map_seed)
	_add_tiles()
	_add_markers()


## The height of the top of a cell: the lane is a hair above the mat, and a socket
## block stands on the mat, cardboard or paperboard of its elevation level.
func surface_height(cell: Vector2i) -> float:
	if map == null:
		return GROUND_HEIGHT
	if map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD:
		return ROAD_HEIGHT
	if map.socket_anchor_at(cell) != GameMap.NO_SOCKET:
		return LEVEL_HEIGHTS[map.elevation_at(cell)]
	return GROUND_HEIGHT


## The transform drawn for the index-th socket overlay (centred on its block, on its level).
func socket_transform(index: int) -> Transform3D:
	return _socket_transforms[index]


func _add_tiles() -> void:
	var road := {}
	for route in map.routes:
		for cell in route:
			road[cell] = true
	var mat: Array[Vector2i] = []
	var lane: Array[Vector2i] = []
	var rises: Array = [mat, [] as Array[Vector2i], [] as Array[Vector2i]]
	ground_count = 0
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			if road.has(cell):
				lane.append(cell)
			elif map.socket_anchor_at(cell) == GameMap.NO_SOCKET:
				mat.append(cell)
				ground_count += 1
			else:
				var level := map.elevation_at(cell)
				if level > 0:
					rises[level].append(cell)
				else:
					mat.append(cell)
	road_count = lane.size()
	socket_count = map.sockets.size()
	_add(_tiles("Mat", mat, "terrain_mat", MAT_COLOUR, 0.1))
	_add(_tiles("Lane", lane, "terrain_lane", LANE_COLOUR, ROAD_HEIGHT))
	_add(_tiles("Cardboard", rises[1], "terrain_cardboard_l1", LEVEL_COLOURS[1], 1.0))
	_add(_tiles("Paperboard", rises[2], "terrain_paperboard_l2", LEVEL_COLOURS[2], 2.0))
	var overlays := _tiles(
		"SocketOverlays",
		map.sockets,
		"overlay_socket_empty_2x2",
		OVERLAY_COLOUR,
		0.02,
		map.footprint
	)
	_add(overlays)
	_add_skirt()


## One MultiMesh holding a model per cell (or per block of `span` cells, given its
## top-left cell), standing on `surface_height`. The model's own origin is its centre
## on the ground plane. Without the file, a box `fallback_height` tall in `colour`.
func _tiles(
	node_name: String,
	cells: Array[Vector2i],
	model: String,
	colour: Color,
	fallback_height: float,
	span: int = 1
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := ModelLoader.mesh(TERRAIN + model + ".glb")
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	if mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(float(span), fallback_height, float(span))
		box.center_offset = Vector3(0.0, fallback_height / 2.0, 0.0)
		mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		instance.material_override = material
	multimesh.mesh = mesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		var at := BoardSpace.footprint_centre(cells[i], span)
		at.y = surface_height(cells[i]) if node_name == "SocketOverlays" else 0.0
		var tile := Transform3D(Basis.IDENTITY, at)
		multimesh.set_instance_transform(i, tile)
		if node_name == "SocketOverlays":
			_socket_transforms.append(tile)
	instance.multimesh = multimesh
	return instance


## The desk around the board, SKIRT_THICKNESS tiles thick, as three MultiMeshes (plain desk,
## erasers, pencils). Which tile is an eraser or a pencil comes from its cell, not a random
## stream, so the same board always looks the same.
func _add_skirt() -> void:
	var plain: Array[Vector2i] = []
	var erasers: Array[Vector2i] = []
	var pencils: Array[Vector2i] = []
	for row in range(-SKIRT_THICKNESS, map.rows + SKIRT_THICKNESS):
		for col in range(-SKIRT_THICKNESS, map.cols + SKIRT_THICKNESS):
			if col >= 0 and col < map.cols and row >= 0 and row < map.rows:
				continue
			var key := (col + SKIRT_THICKNESS) * 31 + (row + SKIRT_THICKNESS) * 17
			if key % ERASER_EVERY == 0:
				erasers.append(Vector2i(col, row))
			elif key % PENCIL_EVERY == 0:
				pencils.append(Vector2i(col, row))
			else:
				plain.append(Vector2i(col, row))
	_add(_skirt_tiles("Desk", plain, "skirt_desk", 0.15))
	_add(_skirt_tiles("Erasers", erasers, "skirt_eraser", 0.23))
	_add(_skirt_tiles("Pencils", pencils, "skirt_pencil", 0.23))


## Skirt tiles may lie off the grid, so they are placed by cell without `surface_height`.
func _skirt_tiles(
	node_name: String, cells: Array[Vector2i], model: String, height: float
) -> MultiMeshInstance3D:
	var instance := _tiles(node_name, [] as Array[Vector2i], model, DESK_COLOUR, height)
	skirt_cells.append_array(cells)
	var multimesh := instance.multimesh
	multimesh.instance_count = cells.size()
	for i in cells.size():
		multimesh.set_instance_transform(
			i, Transform3D(Basis.IDENTITY, BoardSpace.cell_to_world(cells[i].x, cells[i].y))
		)
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
