## The board drawn from the real map in the papercraft look.
##
## The cutting mat under plain ground, the lane cells and level 0 sockets, masking tape
## laid along every road, a corrugated cardboard or laminated grey board rise under a socket
## block on elevation 1 or 2, a pencil circle on each socket, spilled Blot ink at each spawn,
## a desk skirt two tiles thick around the board (with the odd eraser and pencil), and paper
## trees, shrubs and desk clutter scattered where nothing is played. The look comes from
## `PaperLook`. One MultiMesh per model, so the board is a handful of draw calls. A missing
## model falls back to a plain coloured box. Set `map_seed` (also in the editor: this is a
## `@tool` script) and the board rebuilds from `MapGen.generate`. It only reads the map, and
## every random-looking choice comes from a hash of the cell and the seed, so the same seed
## always looks the same.
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
const SPAWN_MODEL := "res://assets/models/terrain/blot_spawn.glb"
## The decor scattered on the board and the desk: model, cells from the road it must keep
## (Chebyshev), and the share of eligible cells that get one.
const DECOR := {
	"Trees": ["decor_tree_pine", 2, 0.4],
	"RoundTrees": ["decor_tree_round", 2, 0.25],
	"Shrubs": ["decor_shrub", 1, 0.35],
	"Grass": ["decor_grass", 1, 0.45],
	"Flowers": ["decor_flowers", 1, 0.14],
	"MatButtons": ["decor_buttons", 1, 0.05],
}
## Clutter on the desk skirt: model and its share of the plain desk tiles.
const CLUTTER := {
	"DeskButtons": ["decor_buttons", 0.1],
	"Pins": ["decor_pins", 0.08],
	"Glue": ["decor_glue", 0.06],
	"Scraps": ["decor_scrap", 0.08],
}
## The decor tall enough to cast a shadow worth its draw call; flat things cast none.
const CASTS_SHADOW: Array[String] = ["Trees", "RoundTrees", "Shrubs"]
## The desk sits this far below the mat (the mat's thickness).
const DESK_TOP := -0.12
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
## The board cells that hold decor, by decor name (the keys of DECOR).
var decor_cells := {}
## Every spilled-ink spawn drawn (the first is `spawn_marker`).
var spawn_count: int = 0
var _desk_cells: Array[Vector2i] = []
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
	decor_cells.clear()
	_desk_cells.clear()
	map = MapGen.generate(map_seed)
	PaperLook.set_board(Vector2(float(map.cols), float(map.rows)) / 2.0)
	_add_tiles()
	_add_tape()
	_add_markers()
	_add_decor()


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
	var mesh := PaperLook.dress(ModelLoader.mesh(TERRAIN + model + ".glb"))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	if node_name in ["Mat", "Lane", "SocketOverlays", "Desk"]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		var basis := _outward(cells[i]) if node_name == "Paperboard" else Basis.IDENTITY
		var tile := Transform3D(basis, at)
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
	_desk_cells = plain
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
	_use_spawn_model(spawn_marker, map.path)
	spawn_count = 1
	# the other spawn sources live under one node, so the board's children stay the same
	var others := Node3D.new()
	others.name = "OtherSpawns"
	for route in map.routes:
		if route[0] != start:
			var extra := MeshInstance3D.new()
			extra.position = BoardSpace.cell_to_world(route[0].x, route[0].y)
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


## The turn that faces a paperboard tile's stepped-in sides away from the middle of its
## block (the model steps in on its +x and +z sides).
func _outward(cell: Vector2i) -> Basis:
	var inside := cell - map.socket_anchor_at(cell)
	var east := inside.x * 2 >= map.footprint
	var south := inside.y * 2 >= map.footprint
	var quarter := 0
	if east and not south:
		quarter = 1
	elif not east and not south:
		quarter = 2
	elif not east and south:
		quarter = 3
	return Basis(Vector3.UP, float(quarter) * PI / 2.0)


## The spilled ink and its bottle at the start of `route`, the bottle lying off the board.
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


## Masking tape along every road (see TapeBuilder).
func _add_tape() -> void:
	var tape := MeshInstance3D.new()
	tape.name = "Tape"
	tape.mesh = TapeBuilder.build(map.routes, map_seed)
	tape.material_override = PaperLook.material("masking_tape")
	tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(tape)


## Paper trees, shrubs, grass and flowers on the open mat, and clutter on the desk. A cell
## gets decor only when it is plain ground far enough from the road (trees also keep off the
## socket blocks and the Heartstone); which decor, where in the cell and how it is turned
## come from a hash of the cell and the seed.
func _add_decor() -> void:
	var road := {}
	for route in map.routes:
		for cell in route:
			road[cell] = true
	var blocked := {}
	for anchor in map.sockets:
		for dy in map.footprint:
			for dx in map.footprint:
				blocked[anchor + Vector2i(dx, dy)] = true
	var heart := map.heartstone
	for dy in heart.size.y:
		for dx in heart.size.x:
			blocked[heart.position + Vector2i(dx, dy)] = true
	var placed := {}
	for key in DECOR:
		placed[key] = []
		decor_cells[key] = [] as Array[Vector2i]
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			if road.has(cell) or blocked.has(cell):
				continue
			var from_road := _distance_to(cell, road)
			var from_blocked := _distance_to(cell, blocked)
			var tree := CellHash.of(col, row, map_seed, 10)
			if (
				from_road >= 2
				and from_blocked >= 1
				and tree < DECOR["Trees"][2] + DECOR["RoundTrees"][2]
			):
				var key := "Trees" if tree < DECOR["Trees"][2] else "RoundTrees"
				_place(placed, key, cell, 0.0, 0.9, 1.25)
				continue
			if (
				from_road >= DECOR["Shrubs"][1]
				and CellHash.of(col, row, map_seed, 11) < DECOR["Shrubs"][2]
			):
				_place(placed, "Shrubs", cell, 0.0, 0.8, 1.2)
			for key in ["Grass", "Flowers", "MatButtons"]:
				var salt: int = 12 + DECOR.keys().find(key)
				if (
					from_road >= DECOR[key][1]
					and CellHash.of(col, row, map_seed, salt) < DECOR[key][2]
				):
					_place(placed, key, cell, 0.0, 0.8, 1.2)
	var decor := Node3D.new()
	decor.name = "Decor"
	for key in DECOR:
		decor.add_child(_scatter(key, DECOR[key][0], placed[key]))
	var clutter := {}
	for key in CLUTTER:
		clutter[key] = []
	var bottles := _bottle_cells()
	for cell in _desk_cells:
		if bottles.has(cell):
			continue
		var pick := CellHash.of(cell.x, cell.y, map_seed, 20)
		var share := 0.0
		for key in CLUTTER:
			share += CLUTTER[key][1]
			if pick < share:
				clutter[key].append(_spot(cell, DESK_TOP, 0.8, 1.1, 21))
				break
	for key in CLUTTER:
		decor.add_child(_scatter(key, CLUTTER[key][0], clutter[key]))
	_add(decor)


## Records decor `key` in `cell` with a hashed offset, turn and size.
func _place(
	placed: Dictionary, key: String, cell: Vector2i, y: float, small: float, big: float
) -> void:
	placed[key].append(_spot(cell, y, small, big, 30 + DECOR.keys().find(key)))
	decor_cells[key].append(cell)


## A transform somewhere inside `cell`, turned and sized by the hash of the cell.
func _spot(cell: Vector2i, y: float, small: float, big: float, salt: int) -> Transform3D:
	var at := BoardSpace.cell_to_world(cell.x, cell.y)
	at.x += (CellHash.of(cell.x, cell.y, map_seed, salt) - 0.5) * 0.5
	at.z += (CellHash.of(cell.x, cell.y, map_seed, salt + 50) - 0.5) * 0.5
	at.y = y
	var turn := CellHash.of(cell.x, cell.y, map_seed, salt + 100) * TAU
	var size := lerpf(small, big, CellHash.of(cell.x, cell.y, map_seed, salt + 150))
	return Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * size), at)


## One MultiMesh of a decor model at the given transforms.
func _scatter(node_name: String, model: String, spots: Array) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := PaperLook.dress(ModelLoader.mesh(TERRAIN + model + ".glb"))
	if mesh == null:
		mesh = BoxMesh.new()
		spots = []
	if not node_name in CASTS_SHADOW:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, spots[i])
	instance.multimesh = multimesh
	return instance


## The desk cells under the ink bottles, which keep their desk clear.
func _bottle_cells() -> Dictionary:
	var cells := {}
	for route in map.routes:
		var out: Vector2i = route[0] - route[1]
		for step in [1, 2]:
			cells[route[0] + out * step] = true
			cells[route[0] + out * step + Vector2i(out.y, out.x)] = true
	return cells


## How many cells (Chebyshev) from `cell` to the nearest cell in `cells`, at most 9.
func _distance_to(cell: Vector2i, cells: Dictionary) -> int:
	var best := 9
	for other in cells:
		var d: Vector2i = (other - cell).abs()
		best = mini(best, maxi(d.x, d.y))
	return best


func _add(node: Node) -> void:
	add_child(node)
	_built.append(node)


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material
