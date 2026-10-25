## The board maps onto the minimap and a pixel maps back to a world point.
extends GutTest

const SIZE := Vector2(320.0, 200.0)


func test_the_minimap_keeps_the_boards_shape_inside_its_box() -> void:
	var size := MinimapMap.fit(32, 20, Vector2(240.0, 150.0))
	assert_almost_eq(size.x, 240.0, 0.001)
	assert_almost_eq(size.y, 150.0, 0.001)
	var square := MinimapMap.fit(20, 20, Vector2(240.0, 150.0))
	assert_almost_eq(square.x, 150.0, 0.001)
	assert_almost_eq(square.y, 150.0, 0.001)


func test_a_sim_position_scales_to_a_pixel() -> void:
	assert_eq(MinimapMap.to_pixel(Vector2(16.0, 10.0), 32, 20, SIZE), SIZE / 2.0)
	assert_eq(MinimapMap.to_pixel(Vector2.ZERO, 32, 20, SIZE), Vector2.ZERO)


func test_the_middle_pixel_is_the_world_origin() -> void:
	assert_eq(MinimapMap.to_world(SIZE / 2.0, 32, 20, SIZE), Vector2.ZERO)


func test_a_pixel_gives_the_world_point_the_board_space_gives_for_it() -> void:
	BoardSpace.use_map(32, 20)
	var pixel := Vector2(80.0, 150.0)
	var back := MinimapMap.to_world(pixel, 32, 20, SIZE)
	var sim := pixel / SIZE * Vector2(32.0, 20.0)
	var world := BoardSpace.point_to_world(sim.x, sim.y)
	BoardSpace.reset()
	assert_almost_eq(world.x, back.x, 0.0001)
	assert_almost_eq(world.z, back.y, 0.0001)


func test_a_pixel_off_the_minimap_is_held_to_the_board() -> void:
	assert_eq(MinimapMap.to_world(Vector2(-50.0, 9999.0), 32, 20, SIZE), Vector2(-16.0, 10.0))


func test_a_drawn_position_comes_back_through_the_pixel() -> void:
	var sim := Vector2(7.5, 3.25)
	var pixel := MinimapMap.to_pixel(sim, 32, 20, SIZE)
	var world := MinimapMap.to_world(pixel, 32, 20, SIZE)
	assert_almost_eq(world.x, sim.x - 16.0, 0.0001)
	assert_almost_eq(world.y, sim.y - 10.0, 0.0001)


func test_a_jump_on_the_layout_valley_centres_the_tapped_cell() -> void:
	# #550: the 40 by 24 layout valley is the game board, the board space follows the map
	var map := MapGen.generate_layout_valley(1)
	assert_eq([map.cols, map.rows], [40, 24])
	BoardSpace.use_map(map.cols, map.rows)
	var fitted := MinimapMap.fit(map.cols, map.rows, SIZE)
	var cell := Vector2i(30, 5)
	var pixel := MinimapMap.to_pixel(Vector2(cell) + Vector2(0.5, 0.5), map.cols, map.rows, fitted)
	var jump := MinimapMap.to_world(pixel, map.cols, map.rows, fitted)
	var centre := BoardSpace.cell_to_world(cell.x, cell.y)
	BoardSpace.reset()
	assert_almost_eq(jump.x, centre.x, 0.0001)
	assert_almost_eq(jump.y, centre.z, 0.0001)
