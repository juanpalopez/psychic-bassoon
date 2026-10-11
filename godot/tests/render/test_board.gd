## The board draws the real map: one tile per cell of the sim's map.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


func test_the_board_holds_the_map_for_its_seed() -> void:
	var board := _board(7920)
	var map := MapGen.generate(7920)
	assert_eq(board.map.path, map.path)
	assert_eq(board.map.routes.size(), map.routes.size())


func test_every_cell_is_either_a_road_tile_or_a_plot() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		assert_eq(board.road_count + board.plot_count, RULES.GRID_COLS * RULES.GRID_ROWS)
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
	assert_eq(board.road_count + board.plot_count, RULES.GRID_COLS * RULES.GRID_ROWS)


func test_the_same_seed_gives_the_same_tiles() -> void:
	var a := _board(42)
	var b := _board(42)
	assert_eq(a.road_count, b.road_count)
	assert_eq(a.plot_count, b.plot_count)


func test_spawn_and_heartstone_markers_sit_on_the_ends_of_the_road() -> void:
	var board := _board(1)
	var path := board.map.path
	var spawn := path[0]
	var heartstone := path[path.size() - 1]
	var spawn_at := BoardSpace.cell_to_world(spawn.x, spawn.y)
	var heartstone_at := BoardSpace.cell_to_world(heartstone.x, heartstone.y)
	assert_almost_eq(board.spawn_marker.position.x, spawn_at.x, 1e-6)
	assert_almost_eq(board.spawn_marker.position.z, spawn_at.z, 1e-6)
	assert_almost_eq(board.heartstone_marker.position.x, heartstone_at.x, 1e-6)
	assert_almost_eq(board.heartstone_marker.position.z, heartstone_at.z, 1e-6)
	assert_lt(board.spawn_marker.position.x, board.heartstone_marker.position.x)


func test_tiles_are_drawn_with_few_draw_calls() -> void:
	# one MultiMesh for plots and one for road, not a node per cell
	var board := _board(1)
	var multimeshes := 0
	for child in board.get_children():
		if child is MultiMeshInstance3D:
			multimeshes += 1
	assert_eq(multimeshes, 2)
