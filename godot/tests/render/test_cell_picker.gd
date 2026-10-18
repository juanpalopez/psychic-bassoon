## A tap on the screen becomes a board cell, through the real camera.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func _rig() -> CameraRig:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.frame(16.0 / 9.0)
	return rig


func test_tapping_the_screen_point_of_a_cell_centre_picks_that_cell() -> void:
	var camera := _rig().camera()
	for row in RULES.GRID_ROWS:
		for col in RULES.GRID_COLS:
			var screen := camera.unproject_position(BoardSpace.cell_to_world(col, row))
			assert_eq(CellPicker.cell_at(camera, screen), Vector2i(col, row), "%d,%d" % [col, row])


func test_tapping_far_outside_the_board_picks_nothing() -> void:
	var camera := _rig().camera()
	assert_eq(CellPicker.cell_at(camera, Vector2(-500.0, -500.0)), BoardSpace.NO_CELL)


func test_tapping_the_sky_picks_nothing() -> void:
	# above the horizon the ray never reaches the ground
	var rig := _rig()
	var camera := rig.camera()
	var tilted := Camera3D.new()
	tilted.fov = 35.0
	tilted.position = Vector3(0.0, 5.0, 0.0)
	tilted.rotation = Vector3(deg_to_rad(40.0), 0.0, 0.0)
	add_child_autofree(tilted)
	assert_eq(CellPicker.cell_at(tilted, Vector2(576.0, 324.0)), BoardSpace.NO_CELL)
	assert_not_null(camera)


## A board and a camera, as the scene has them.
func _scene(map_seed: int) -> Dictionary:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.frame(16.0 / 9.0)
	return {"board": board, "camera": rig.camera()}


func test_a_tap_on_the_top_of_a_raised_tile_picks_that_tile() -> void:
	# a level 2 socket stands 2.0 high: cutting the ray with the ground alone
	# would pick the cell behind it
	var scene := _scene(7920)
	var board: Board = scene.board
	var camera: Camera3D = scene.camera
	var checked := {}
	for cell in board.map.sockets:
		var top := board.surface_height(cell)
		var centre := BoardSpace.cell_to_world(cell.x, cell.y)
		for dx in [-0.3, 0.0, 0.3]:
			for dz in [-0.3, 0.0, 0.3]:
				var point := centre + Vector3(dx, top, dz)
				var screen := camera.unproject_position(point)
				var picked := CellPicker.cell_at(camera, screen, board.surface_height)
				assert_eq(picked, cell, "socket %s level %d" % [cell, board.map.elevation_at(cell)])
		checked[board.map.elevation_at(cell)] = true
	assert_true(checked.has(0) and checked.has(1) and checked.has(2), "all three levels checked")


func test_a_tap_on_road_and_ground_still_picks_them() -> void:
	var scene := _scene(1)
	var board: Board = scene.board
	var camera: Camera3D = scene.camera
	for cell in [board.map.path[3], board.map.path[10]]:
		var top := board.surface_height(cell)
		var point := BoardSpace.cell_to_world(cell.x, cell.y) + Vector3(0.0, top, 0.0)
		assert_eq(
			CellPicker.cell_at(camera, camera.unproject_position(point), board.surface_height), cell
		)


func test_a_tap_off_the_board_still_picks_nothing_with_heights() -> void:
	var scene := _scene(1)
	var board: Board = scene.board
	var camera: Camera3D = scene.camera
	assert_eq(
		CellPicker.cell_at(camera, Vector2(-500.0, -500.0), board.surface_height),
		BoardSpace.NO_CELL
	)


func test_the_camera_the_picker_uses_is_turned_by_the_yaw() -> void:
	var camera := _rig().camera()
	var forward := -camera.global_transform.basis.z
	assert_gt(absf(forward.x), 0.1, "the view direction is not along the board's rows")


func test_the_round_trip_holds_zoomed_in_and_panned_with_the_yaw() -> void:
	var scene := _scene(7920)
	var board: Board = scene.board
	var camera: Camera3D = scene.camera
	var rig := camera.get_parent() as CameraRig
	rig.canvas_height = 720.0
	rig.set_zoom(0.8)
	rig.pan_by_pixels(Vector2(-150.0, 90.0))
	rig.release_pan()
	var size := get_viewport().get_visible_rect().size
	var picked := 0
	for row in board.map.rows:
		for col in board.map.cols:
			var cell := Vector2i(col, row)
			var point := BoardSpace.cell_to_world(col, row)
			point.y = board.surface_height(cell)
			var screen := camera.unproject_position(point)
			if screen.x < 0.0 or screen.y < 0.0 or screen.x > size.x or screen.y > size.y:
				continue
			var hit := CellPicker.cell_at(camera, screen, board.surface_height)
			if hit == cell:
				picked += 1
			else:
				# only a taller tile in front may hide the top of a cell
				assert_gt(board.surface_height(hit), board.surface_height(cell), str(cell))
	assert_gt(picked, 40, "many cells were in view and picked")
