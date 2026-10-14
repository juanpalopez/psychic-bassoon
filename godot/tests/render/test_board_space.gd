## Where the sim's cells go in the 3D world. One script knows this. The board is
## landscape as the sim has it (22 columns across, 16 rows deep).
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func test_the_board_is_centred_on_the_origin() -> void:
	var first := BoardSpace.cell_to_world(0, 0)
	var last := BoardSpace.cell_to_world(RULES.GRID_COLS - 1, RULES.GRID_ROWS - 1)
	assert_almost_eq(first.x + last.x, 0.0, 1e-9)
	assert_almost_eq(first.z + last.z, 0.0, 1e-9)
	assert_eq(first.y, 0.0)


func test_a_higher_column_is_further_right() -> void:
	# the board is landscape as the sim has it: columns run across the screen
	assert_lt(BoardSpace.cell_to_world(0, 5).x, BoardSpace.cell_to_world(1, 5).x)
	assert_almost_eq(BoardSpace.cell_to_world(0, 5).z, BoardSpace.cell_to_world(1, 5).z, 1e-9)


func test_a_higher_row_is_nearer_the_camera() -> void:
	# the camera sits at +z and looks along -z: row 0 is the far edge
	assert_lt(BoardSpace.cell_to_world(4, 0).z, BoardSpace.cell_to_world(4, 1).z)


func test_a_road_from_the_left_edge_to_the_right_edge_runs_left_to_right() -> void:
	var spawn := BoardSpace.cell_to_world(0, 5)
	var heartstone := BoardSpace.cell_to_world(RULES.GRID_COLS - 1, 5)
	assert_lt(spawn.x, heartstone.x)
	assert_almost_eq(spawn.z, heartstone.z, 1e-9)


func test_neighbouring_cells_are_one_unit_apart() -> void:
	var a := BoardSpace.cell_to_world(3, 5)
	assert_eq(a.distance_to(BoardSpace.cell_to_world(4, 5)), 1.0)
	assert_eq(a.distance_to(BoardSpace.cell_to_world(3, 6)), 1.0)


func test_the_axes_are_not_mirrored() -> void:
	# a column step goes to +x and a row step to +z, as in the sim's own across-down pair
	var origin := BoardSpace.cell_to_world(3, 3)
	assert_eq(BoardSpace.cell_to_world(4, 3) - origin, Vector3(1, 0, 0))
	assert_eq(BoardSpace.cell_to_world(3, 4) - origin, Vector3(0, 0, 1))


func test_size_is_columns_across_and_rows_deep() -> void:
	var size := BoardSpace.size()
	assert_eq(size.x, float(RULES.GRID_COLS))
	assert_eq(size.y, float(RULES.GRID_ROWS))
	assert_eq([RULES.GRID_COLS, RULES.GRID_ROWS], [16, 11])


func test_corners_are_the_outer_edge_of_the_board() -> void:
	var corners := BoardSpace.corners()
	assert_eq(corners.size(), 4)
	for corner in corners:
		assert_almost_eq(absf(corner.x), float(RULES.GRID_COLS) / 2.0, 1e-9)
		assert_almost_eq(absf(corner.z), float(RULES.GRID_ROWS) / 2.0, 1e-9)
		assert_eq(corner.y, 0.0)


func test_the_middle_of_a_block_is_half_a_cell_further_in_for_each_extra_cell() -> void:
	var one := BoardSpace.footprint_centre(Vector2i(5, 4), 1)
	assert_eq(one, BoardSpace.cell_to_world(5, 4))
	var two := BoardSpace.footprint_centre(Vector2i(5, 4), 2)
	assert_almost_eq(two.x, BoardSpace.cell_to_world(5, 4).x + 0.5, 1e-9)
	assert_almost_eq(two.z, BoardSpace.cell_to_world(5, 4).z + 0.5, 1e-9)
	# it is the middle of the four cells
	var sum := Vector3.ZERO
	for cell in [Vector2i(5, 4), Vector2i(6, 4), Vector2i(5, 5), Vector2i(6, 5)]:
		sum += BoardSpace.cell_to_world(cell.x, cell.y)
	assert_almost_eq(two.x, sum.x / 4.0, 1e-9)
	assert_almost_eq(two.z, sum.z / 4.0, 1e-9)


func test_world_to_cell_inverts_cell_to_world_for_every_cell() -> void:
	for row in RULES.GRID_ROWS:
		for col in RULES.GRID_COLS:
			var centre := BoardSpace.cell_to_world(col, row)
			assert_eq(BoardSpace.world_to_cell(centre), Vector2i(col, row))
			# anywhere inside the cell is the same cell
			assert_eq(
				BoardSpace.world_to_cell(centre + Vector3(0.49, 0.0, -0.49)), Vector2i(col, row)
			)
			assert_eq(
				BoardSpace.world_to_cell(centre + Vector3(-0.49, 0.0, 0.49)), Vector2i(col, row)
			)


func test_a_point_off_the_board_is_no_cell() -> void:
	var half := BoardSpace.size() / 2.0
	for point in [
		Vector3(-half.x - 0.01, 0.0, 0.0),
		Vector3(half.x + 0.01, 0.0, 0.0),
		Vector3(0.0, 0.0, half.y + 0.01),
		Vector3(0.0, 0.0, -half.y - 0.01),
	]:
		assert_eq(BoardSpace.world_to_cell(point), BoardSpace.NO_CELL, str(point))


func test_a_ray_that_points_down_hits_the_ground() -> void:
	var hit: Variant = BoardSpace.ground_hit(Vector3(1.0, 10.0, 2.0), Vector3(0.0, -1.0, 0.0))
	assert_not_null(hit)
	assert_eq(hit, Vector3(1.0, 0.0, 2.0))
	var slanted: Variant = BoardSpace.ground_hit(Vector3(0.0, 4.0, 0.0), Vector3(0.0, -1.0, -1.0))
	assert_almost_eq((slanted as Vector3).z, -4.0, 1e-9)
	assert_eq((slanted as Vector3).y, 0.0)


func test_a_ray_that_points_up_or_along_the_ground_misses() -> void:
	assert_null(BoardSpace.ground_hit(Vector3(0.0, 5.0, 0.0), Vector3(0.0, 1.0, 0.0)))
	assert_null(BoardSpace.ground_hit(Vector3(0.0, 5.0, 0.0), Vector3(1.0, 0.0, 0.0)))
	# a ray that starts below the ground and points down is behind it
	assert_null(BoardSpace.ground_hit(Vector3(0.0, -1.0, 0.0), Vector3(0.0, -1.0, 0.0)))


func test_a_sim_point_at_a_cell_centre_is_that_cells_world_position() -> void:
	# sim positions are in cells: x across (column + 0.5), y down (row + 0.5)
	for row in RULES.GRID_ROWS:
		for col in RULES.GRID_COLS:
			var from_point := BoardSpace.point_to_world(float(col) + 0.5, float(row) + 0.5)
			var from_cell := BoardSpace.cell_to_world(col, row)
			assert_almost_eq(from_point.x, from_cell.x, 1e-9)
			assert_almost_eq(from_point.z, from_cell.z, 1e-9)
			assert_eq(from_point.y, 0.0)


func test_a_point_between_two_cells_lies_between_them() -> void:
	var a := BoardSpace.cell_to_world(3, 4)
	var b := BoardSpace.cell_to_world(4, 4)
	var middle := BoardSpace.point_to_world(4.0, 4.5)
	assert_almost_eq(middle.x, (a.x + b.x) / 2.0, 1e-9)
	assert_almost_eq(middle.z, (a.z + b.z) / 2.0, 1e-9)


func test_the_spawn_point_left_of_the_first_column_is_off_the_left_edge() -> void:
	# a road that starts by going right begins 0.45 cells left of column 0
	var spawn := BoardSpace.point_to_world(-0.45, 7.5)
	assert_lt(spawn.x, BoardSpace.corners()[0].x)
