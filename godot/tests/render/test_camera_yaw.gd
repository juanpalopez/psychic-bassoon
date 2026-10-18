## The board camera's yaw: the fit, the drag and the cell size when the view is turned.
extends GutTest

const PITCH := 62.0
const FOV := 20.0
const MARGIN := 1.05


## Normalised device coordinates of a world point for a camera `distance` away, turned by `yaw`;
## written out independently of `CameraRig.fit_distance`, so the test can fail.
func _ndc(point: Vector3, distance: float, aspect: float, yaw: float) -> Vector2:
	var pitch := deg_to_rad(PITCH)
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var forward := turn * Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := turn * Vector3(0.0, cos(pitch), -sin(pitch))
	var right := turn * Vector3.RIGHT
	var offset := point + forward * distance
	var depth := offset.dot(forward)
	var tan_v := tan(deg_to_rad(FOV) / 2.0)
	return Vector2(offset.dot(right) / (depth * tan_v * aspect), offset.dot(up) / (depth * tan_v))


func _fit(aspect: float, yaw: float) -> float:
	return CameraRig.fit_distance(BoardSpace.corners(), PITCH, FOV, aspect, MARGIN, yaw)


## A rig in a viewport of its own, so the test does not depend on the window size.
func _rig_in(width: int, height: int) -> CameraRig:
	var port := SubViewport.new()
	port.size = Vector2i(width, height)
	add_child_autofree(port)
	var rig := CameraRig.new()
	rig.canvas_height = float(height)
	port.add_child(rig)
	rig.frame(float(width) / float(height))
	return rig


## The ground direction (x, z) that points right on the screen, and the one that points up it.
func _screen_axes(camera: Camera3D) -> Array[Vector2]:
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	return [Vector2(right.x, right.z).normalized(), Vector2(forward.x, forward.z).normalized()]


func test_every_corner_is_on_screen_at_the_fitted_distance_with_a_yaw() -> void:
	for yaw in [CameraRig.YAW_DEGREES, 35.0, 45.0, -40.0, 90.0]:
		for aspect in [1.0, 4.0 / 3.0, 16.0 / 9.0, 19.5 / 9.0, 2.4]:
			var distance := _fit(aspect, yaw)
			for corner in BoardSpace.corners():
				var ndc := _ndc(corner, distance, aspect, yaw)
				assert_lte(absf(ndc.x), 1.0 + 1e-9, "x, yaw %f aspect %f" % [yaw, aspect])
				assert_lte(absf(ndc.y), 1.0 + 1e-9, "y, yaw %f aspect %f" % [yaw, aspect])


func test_the_fit_with_a_yaw_is_tight() -> void:
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 19.5 / 9.0]:
		var closer := _fit(aspect, CameraRig.YAW_DEGREES) * 0.93
		var worst := 0.0
		for corner in BoardSpace.corners():
			var ndc := _ndc(corner, closer, aspect, CameraRig.YAW_DEGREES)
			worst = maxf(worst, maxf(absf(ndc.x), absf(ndc.y)))
		assert_gt(worst, 1.0, "aspect %f" % aspect)


func test_the_yaw_is_a_turn_of_about_30_degrees() -> void:
	assert_gte(CameraRig.YAW_DEGREES, 25.0)
	assert_lte(CameraRig.YAW_DEGREES, 35.0)


func test_a_drag_follows_the_yaw_so_the_view_moves_the_way_the_finger_does() -> void:
	var rig := _rig_in(1280, 720)
	rig.set_zoom(1.0)
	var centre := rig.get_viewport().get_visible_rect().size / 2.0
	var before := rig.ground_under(centre)
	var point := before
	# the ground under the middle of the screen at the start; after a drag right it must sit
	# to the right of where the middle now is, along the camera's own right
	for drag in [Vector2(20.0, 0.0), Vector2(-20.0, 0.0), Vector2(0.0, 15.0), Vector2(0.0, -15.0)]:
		rig.pan = Vector2.ZERO
		rig._pan_raw = Vector2.ZERO
		rig._place()
		rig.pan_by_pixels(drag)
		# the raw drag, before the limits damp it
		rig.pan = rig._pan_raw
		rig._place()
		var camera := rig.camera()
		# where the starting ground point now appears on the screen
		var moved := camera.unproject_position(Vector3(point.x, 0.0, point.y))
		var shift := moved - centre
		assert_gt(shift.dot(drag), 0.0, "the scene moves with the finger for %s" % drag)
		# and roughly by the drag itself (perspective makes it inexact)
		assert_almost_eq(shift.length(), drag.length(), drag.length() * 0.25, "%s" % drag)
		rig.release_pan()


func test_cells_stay_at_least_40_pixels_wide_at_the_closest_zoom_with_the_yaw() -> void:
	for shape in [Vector2i(1280, 720), Vector2i(1558, 720), Vector2i(1024, 768)]:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(1.0)
		var camera := rig.camera()
		var height := float(shape.y)
		var scale := 720.0 / height
		for cell in [Vector2i(10, 8), Vector2i(3, 3), Vector2i(18, 12)]:
			var origin := BoardSpace.cell_to_world(cell.x, cell.y)
			var east := BoardSpace.cell_to_world(cell.x + 1, cell.y)
			var south := BoardSpace.cell_to_world(cell.x, cell.y + 1)
			var from := camera.unproject_position(origin)
			# the centre of the board is in view only when panned; measure on the 720 px canvas
			rig.pan = Vector2(origin.x, origin.z)
			rig._place()
			from = camera.unproject_position(origin)
			var across := from.distance_to(camera.unproject_position(east)) * scale
			var down := from.distance_to(camera.unproject_position(south)) * scale
			assert_gte(across, 40.0, "%s east at %s" % [cell, shape])
			assert_gte(down, 40.0, "%s south at %s" % [cell, shape])


func test_the_drag_maths_turns_with_the_yaw() -> void:
	# no yaw: a drag right moves the target to -x, a drag down moves it to -z
	var plain := CameraRig.ground_drag(Vector2(10.0, 0.0), 0.1, 60.0, 0.0)
	assert_almost_eq(plain.x, -1.0, 1e-6)
	assert_almost_eq(plain.y, 0.0, 1e-6)
	var down := CameraRig.ground_drag(Vector2(0.0, 10.0), 0.1, 60.0, 0.0)
	assert_almost_eq(down.y, -1.0 / sin(deg_to_rad(60.0)), 1e-6)
	# a quarter turn: the screen's right is now the ground's -z
	var quarter := CameraRig.ground_drag(Vector2(10.0, 0.0), 0.1, 60.0, 90.0)
	assert_almost_eq(quarter.x, 0.0, 1e-6)
	assert_almost_eq(quarter.y, 1.0, 1e-6)


func test_a_tall_point_at_a_board_corner_stays_on_screen_when_zoomed_out() -> void:
	var lift := CameraRig.top_height()
	# the cliff plus a tower: well above the ground, so the fit must allow for it
	assert_gte(lift, 2.0 + 1.0)
	for aspect in [1.0, 4.0 / 3.0, 16.0 / 9.0, 2.16, 2.4]:
		var rig := CameraRig.new()
		add_child_autofree(rig)
		rig.frame(aspect)
		var camera := rig.camera()
		var tan_v := tan(deg_to_rad(camera.fov) / 2.0)
		for corner in BoardSpace.corners():
			var local := (
				camera.global_transform.affine_inverse() * (corner + Vector3(0.0, lift, 0.0))
			)
			var depth := -local.z
			assert_gt(depth, 0.0)
			assert_lte(absf(local.y) / (depth * tan_v), 1.0 + 1e-6, "vertical, aspect %f" % aspect)
			assert_lte(absf(local.x) / (depth * tan_v * aspect), 1.0 + 1e-6, "horizontal")
