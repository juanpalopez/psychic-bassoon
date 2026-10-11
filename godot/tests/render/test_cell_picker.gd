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
