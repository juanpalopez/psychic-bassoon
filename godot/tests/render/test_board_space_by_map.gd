## BoardSpace on a board other than the game's (#480): the layout valley is 40 by 24, and
## every conversion, the size and the corners follow the map in use.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


## The board is static, so a test that names another board gives the game board back.
func after_each() -> void:
	BoardSpace.reset()


func test_the_game_board_is_the_size_of_the_rules_until_a_map_is_used() -> void:
	assert_eq(BoardSpace.size(), Vector2(RULES.GRID_COLS, RULES.GRID_ROWS))


func test_a_40_by_24_board_is_centred_and_its_corners_are_its_outer_edge() -> void:
	BoardSpace.use_map(40, 24)
	assert_eq(BoardSpace.size(), Vector2(40.0, 24.0))
	assert_eq(BoardSpace.cell_to_world(0, 0), Vector3(-19.5, 0.0, -11.5))
	assert_eq(BoardSpace.cell_to_world(39, 23), Vector3(19.5, 0.0, 11.5))
	var corners := BoardSpace.corners()
	assert_eq(corners[0], Vector3(-20.0, 0.0, -12.0))
	assert_eq(corners[2], Vector3(20.0, 0.0, 12.0))


func test_world_to_cell_inverts_cell_to_world_on_a_40_by_24_board() -> void:
	BoardSpace.use_map(40, 24)
	for row in 24:
		for col in 40:
			var centre := BoardSpace.cell_to_world(col, row)
			assert_eq(BoardSpace.world_to_cell(centre), Vector2i(col, row))
			assert_eq(
				BoardSpace.world_to_cell(centre + Vector3(0.49, 0.0, -0.49)), Vector2i(col, row)
			)


func test_the_edges_of_a_40_by_24_board_are_where_its_size_says() -> void:
	BoardSpace.use_map(40, 24)
	assert_eq(BoardSpace.world_to_cell(Vector3(19.9, 0.0, 11.9)), Vector2i(39, 23))
	assert_eq(BoardSpace.world_to_cell(Vector3(20.01, 0.0, 0.0)), BoardSpace.NO_CELL)
	assert_eq(BoardSpace.world_to_cell(Vector3(0.0, 0.0, 12.01)), BoardSpace.NO_CELL)
	# the game board's edge (16 across) is inside the 40 by 24 board
	assert_eq(BoardSpace.world_to_cell(Vector3(16.5, 0.0, 0.0)), Vector2i(36, 12))


func test_a_sim_point_at_a_cell_centre_is_that_cells_world_position_on_a_40_by_24_board() -> void:
	BoardSpace.use_map(40, 24)
	for row in 24:
		for col in 40:
			var from_point := BoardSpace.point_to_world(float(col) + 0.5, float(row) + 0.5)
			assert_eq(from_point, BoardSpace.cell_to_world(col, row))


func test_reset_gives_the_game_board_back() -> void:
	BoardSpace.use_map(40, 24)
	BoardSpace.reset()
	assert_eq(BoardSpace.size(), Vector2(RULES.GRID_COLS, RULES.GRID_ROWS))
	assert_eq(BoardSpace.cell_to_world(0, 0), Vector3(-15.5, 0.0, -9.5))
