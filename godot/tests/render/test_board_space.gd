## Where the sim's cells go in the 3D world. One script knows this (the board
## is drawn turned so the road runs left to right; the sim is untouched).
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func test_the_board_is_centred_on_the_origin() -> void:
	var first := BoardSpace.cell_to_world(0, 0)
	var last := BoardSpace.cell_to_world(RULES.GRID_COLS - 1, RULES.GRID_ROWS - 1)
	assert_almost_eq(first.x + last.x, 0.0, 1e-9)
	assert_almost_eq(first.z + last.z, 0.0, 1e-9)
	assert_eq(first.y, 0.0)


func test_the_road_runs_left_to_right() -> void:
	# sim row 0 is the spawn row, the last row holds the Heartstone
	var spawn := BoardSpace.cell_to_world(4, 0)
	var heartstone := BoardSpace.cell_to_world(4, RULES.GRID_ROWS - 1)
	assert_lt(spawn.x, heartstone.x)
	assert_almost_eq(spawn.z, heartstone.z, 1e-9)


func test_neighbouring_cells_are_one_unit_apart() -> void:
	var a := BoardSpace.cell_to_world(3, 5)
	assert_almost_eq(a.distance_to(BoardSpace.cell_to_world(4, 5)), 1.0, 1e-9)
	assert_almost_eq(a.distance_to(BoardSpace.cell_to_world(3, 6)), 1.0, 1e-9)


func test_a_higher_column_is_further_from_the_camera() -> void:
	# the camera sits at +z and looks along -z: a larger sim column has a smaller z
	assert_lt(BoardSpace.cell_to_world(8, 0).z, BoardSpace.cell_to_world(0, 0).z)


func test_the_turn_is_a_rotation_not_a_mirror() -> void:
	# the sim's axes are (column across, row down). Turned a quarter, a row step
	# must go to +x and a column step to -z, so (row step) x (column step) points
	# the same way as the sim's own across-down pair would (a rotation keeps the
	# handedness, a mirror flips it)
	var origin := BoardSpace.cell_to_world(3, 3)
	var row_step := BoardSpace.cell_to_world(3, 4) - origin
	var col_step := BoardSpace.cell_to_world(4, 3) - origin
	assert_eq(row_step, Vector3(1, 0, 0))
	assert_eq(col_step, Vector3(0, 0, -1))
	# column step x row step points down (-y) for the rotation the Three.js build
	# used; a mirror (z rising with the column) would make it point up (+y)
	assert_lt(col_step.cross(row_step).y, 0.0)


func test_size_is_rows_across_and_columns_deep() -> void:
	var size := BoardSpace.size()
	assert_eq(size.x, float(RULES.GRID_ROWS))
	assert_eq(size.y, float(RULES.GRID_COLS))


func test_corners_are_the_outer_edge_of_the_board() -> void:
	var corners := BoardSpace.corners()
	assert_eq(corners.size(), 4)
	for corner in corners:
		assert_almost_eq(absf(corner.x), float(RULES.GRID_ROWS) / 2.0, 1e-9)
		assert_almost_eq(absf(corner.z), float(RULES.GRID_COLS) / 2.0, 1e-9)
		assert_eq(corner.y, 0.0)
