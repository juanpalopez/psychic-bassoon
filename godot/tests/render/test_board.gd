## The board draws the real map: one tile per cell of the sim's map.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


func _cells_per_block(board: Board) -> int:
	return board.map.footprint * board.map.footprint


func test_the_board_holds_the_map_for_its_seed() -> void:
	var board := _board(7920)
	var map := MapGen.generate(7920)
	assert_eq(board.map.path, map.path)
	assert_eq(board.map.routes.size(), map.routes.size())


func test_every_cell_is_a_road_tile_a_socket_or_ground() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		assert_eq(
			board.road_count + board.ground_count + board.socket_count * _cells_per_block(board),
			RULES.GRID_COLS * RULES.GRID_ROWS
		)
		var road := {}
		for route in board.map.routes:
			for cell in route:
				road[cell] = true
		assert_eq(board.road_count, road.size(), "seed %d" % map_seed)


func test_changing_the_seed_rebuilds_the_board() -> void:
	var board := _board(1)
	var before := board.map.path
	board.map_seed = 7920
	assert_ne(board.map.path, before)
	assert_eq(board.map.path, MapGen.generate(7920).path)
	assert_eq(
		board.road_count + board.ground_count + board.socket_count * _cells_per_block(board),
		RULES.GRID_COLS * RULES.GRID_ROWS
	)


func test_the_same_seed_gives_the_same_tiles() -> void:
	var a := _board(42)
	var b := _board(42)
	assert_eq(a.road_count, b.road_count)
	assert_eq(a.socket_count, b.socket_count)
	assert_eq(a.ground_count, b.ground_count)


func test_spawn_and_heartstone_markers_sit_on_the_ends_of_the_road() -> void:
	var board := _board(1)
	var path := board.map.path
	var spawn := path[0]
	var heartstone := path[path.size() - 1]
	var spawn_at := BoardSpace.cell_to_world(spawn.x, spawn.y)
	var block := board.map.heartstone
	assert_true(block.has_point(heartstone), "the footprint holds the end of the road")
	var heartstone_at := BoardSpace.footprint_centre(block.position, block.size.x)
	assert_almost_eq(board.spawn_marker.position.x, spawn_at.x, 1e-6)
	assert_almost_eq(board.spawn_marker.position.z, spawn_at.z, 1e-6)
	assert_almost_eq(board.heartstone_marker.position.x, heartstone_at.x, 1e-6)
	assert_almost_eq(board.heartstone_marker.position.z, heartstone_at.z, 1e-6)
	assert_lt(board.spawn_marker.position.x, board.heartstone_marker.position.x)


func test_rebuilding_leaves_no_stale_children_and_keeps_foreign_ones() -> void:
	var board := _board(1)
	var foreign := Node3D.new()
	board.add_child(foreign)
	var before := board.get_child_count()
	for map_seed in [2, 3, 4]:
		board.map_seed = map_seed
	assert_eq(board.get_child_count(), before)
	assert_true(foreign.get_parent() == board, "a node someone else added is kept")


func test_tiles_are_drawn_with_few_draw_calls() -> void:
	# one MultiMesh each for road, ground and sockets, not a node per cell
	var board := _board(1)
	var multimeshes := 0
	for child in board.get_children():
		if child is MultiMeshInstance3D:
			multimeshes += 1
	assert_eq(multimeshes, 3)


func test_the_board_draws_one_socket_tile_per_socket() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		assert_eq(board.socket_count, board.map.sockets.size(), "seed %d" % map_seed)


func test_a_higher_socket_stands_taller_than_the_road_and_the_ground() -> void:
	var board := _board(7920)
	var heights := {}
	for cell in board.map.sockets:
		heights[board.map.elevation_at(cell)] = board.surface_height(cell)
	assert_true(heights.has(0) and heights.has(1) and heights.has(2))
	assert_lt(heights[0], heights[1])
	assert_lt(heights[1], heights[2])
	assert_lt(board.surface_height(board.map.path[3]), board.surface_height(board.map.sockets[0]))


func test_a_socket_is_drawn_as_a_block_as_wide_as_its_footprint() -> void:
	var board := _board(1)
	var anchor := board.map.sockets[0]
	var transform := board.socket_transform(0)
	var middle := BoardSpace.footprint_centre(anchor, board.map.footprint)
	assert_almost_eq(transform.origin.x, middle.x, 1e-5)
	assert_almost_eq(transform.origin.z, middle.z, 1e-5)
	assert_almost_eq(transform.basis.x.length(), float(board.map.footprint), 1e-5)
	assert_almost_eq(transform.basis.z.length(), float(board.map.footprint), 1e-5)


func test_every_cell_of_a_socket_block_has_the_blocks_height() -> void:
	var board := _board(7920)
	for anchor in board.map.sockets:
		var height := board.surface_height(anchor)
		for dy in board.map.footprint:
			for dx in board.map.footprint:
				assert_eq(board.surface_height(anchor + Vector2i(dx, dy)), height, str(anchor))


func test_the_heartstone_marker_covers_its_footprint() -> void:
	var board := _board(1)
	# the owner's model, scaled to most of the footprint (a box if the file is missing)
	var width := board.heartstone_marker.mesh.get_aabb().size.x * board.heartstone_marker.scale.x
	assert_gte(width, float(board.map.heartstone.size.x) * 0.6)
	assert_false(board.heartstone_marker.mesh is BoxMesh, "the model, not the box")
	assert_almost_eq(
		(
			board.heartstone_marker.position.y
			+ board.heartstone_marker.mesh.get_aabb().position.y * board.heartstone_marker.scale.y
		),
		0.0,
		1e-6,
		"standing on the ground"
	)
