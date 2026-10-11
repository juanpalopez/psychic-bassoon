## The camera rig must fit the whole board for any landscape screen.
extends GutTest

const PITCH := 65.0  # the whole-board view is the most top-down one
const FOV := 35.0
const MARGIN := 1.05


## Project a world point as a camera at `distance` would see it: normalised
## device coordinates, each within -1..1 when the point is on screen. This is
## written out independently of `CameraRig.fit_distance`, so the test can fail.
func _ndc(point: Vector3, distance: float, aspect: float) -> Vector2:
	var pitch := deg_to_rad(PITCH)
	var forward := Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var camera := -forward * distance
	var offset := point - camera
	var depth := offset.dot(forward)
	var tan_v := tan(deg_to_rad(FOV) / 2.0)
	return Vector2(offset.x / (depth * tan_v * aspect), offset.dot(up) / (depth * tan_v))


func _fit(aspect: float) -> float:
	return CameraRig.fit_distance(BoardSpace.corners(), PITCH, FOV, aspect, MARGIN)


func test_every_corner_is_on_screen_at_the_fitted_distance() -> void:
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 19.5 / 9.0, 2.4]:
		var distance := _fit(aspect)
		for corner in BoardSpace.corners():
			var ndc := _ndc(corner, distance, aspect)
			assert_lte(absf(ndc.x), 1.0, "x, aspect %f" % aspect)
			assert_lte(absf(ndc.y), 1.0, "y, aspect %f" % aspect)


func test_the_fit_is_tight_so_the_board_is_not_tiny() -> void:
	# a little closer and some corner leaves the screen (margin aside)
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 19.5 / 9.0]:
		var closer := _fit(aspect) * 0.93
		var worst := 0.0
		for corner in BoardSpace.corners():
			var ndc := _ndc(corner, closer, aspect)
			worst = maxf(worst, maxf(absf(ndc.x), absf(ndc.y)))
		assert_gt(worst, 1.0, "aspect %f" % aspect)


func test_a_narrower_screen_needs_the_camera_further_back() -> void:
	assert_gt(_fit(4.0 / 3.0), _fit(16.0 / 9.0))


func test_the_margin_leaves_room_on_every_screen_shape() -> void:
	# whichever side limits the fit (width on a narrow screen, height on a wide
	# one), a bigger margin must move the camera back
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 2.4]:
		var tight := CameraRig.fit_distance(BoardSpace.corners(), PITCH, FOV, aspect, 1.0)
		var roomy := CameraRig.fit_distance(BoardSpace.corners(), PITCH, FOV, aspect, 1.2)
		assert_gt(roomy, tight, "aspect %f" % aspect)


func test_a_zero_or_negative_aspect_never_puts_the_camera_at_infinity() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	for aspect in [0.0, -1.0]:
		rig.frame(aspect)
		var camera := rig.get_child(0) as Camera3D
		assert_true(is_finite(camera.position.y), "aspect %f" % aspect)
		assert_true(is_finite(camera.position.z), "aspect %f" % aspect)


func test_the_rig_aims_the_camera_down_at_the_board() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.frame(16.0 / 9.0)
	var camera := rig.camera()
	assert_not_null(camera)
	assert_almost_eq(camera.rotation_degrees.x, -PITCH, 1e-4)
	assert_almost_eq(camera.fov, FOV, 1e-4)
	# the camera is behind the board (positive z) and above it
	assert_gt(camera.position.z, 0.0)
	assert_gt(camera.position.y, 0.0)


func test_pitch_runs_from_65_degrees_zoomed_out_to_30_zoomed_in() -> void:
	assert_eq(CameraRig.pitch_for(0.0), 65.0)
	assert_eq(CameraRig.pitch_for(1.0), 30.0)
	assert_almost_eq(CameraRig.pitch_for(0.5), 47.5, 1e-9)
	assert_eq(CameraRig.pitch_for(-3.0), 65.0)
	assert_eq(CameraRig.pitch_for(9.0), 30.0)


func test_the_closest_view_is_never_further_than_the_fit_and_shows_big_cells() -> void:
	var fit := 20.0
	# a tall canvas: cells reach the target size before the fit distance
	var close := CameraRig.closest_distance(FOV, 720.0, fit)
	assert_lt(close, fit)
	# 120 px per cell on a 720 px canvas
	assert_almost_eq(720.0 / (2.0 * close * tan(deg_to_rad(FOV) / 2.0)), 120.0, 1e-6)
	# a canvas so tall that cells are already bigger than that when the board
	# fits: there is nothing to zoom into, so the limit yields to the fit
	assert_eq(CameraRig.closest_distance(FOV, 100000.0, fit), fit)


func _phone_rig() -> CameraRig:
	var rig := CameraRig.new()
	rig.canvas_height = 720.0
	add_child_autofree(rig)
	rig.frame(16.0 / 9.0)
	return rig


func test_zoom_in_moves_the_camera_closer_and_lower() -> void:
	var rig := _phone_rig()
	var camera := rig.camera()
	var far := camera.position.length()
	var far_pitch := camera.rotation_degrees.x
	rig.set_zoom(1.0)
	assert_lt(camera.position.length(), far)
	assert_gt(camera.rotation_degrees.x, far_pitch, "less negative: a lower angle")
	assert_almost_eq(camera.rotation_degrees.x, -30.0, 1e-4)


func test_zoom_is_clamped_to_the_range() -> void:
	var rig := _phone_rig()
	rig.zoom_by(1000.0)
	assert_eq(rig.zoom, 1.0)
	rig.zoom_by(0.0001)
	assert_eq(rig.zoom, 0.0)
	rig.zoom_steps(3.0)
	assert_almost_eq(rig.zoom, 3.0 * CameraRig.WHEEL_STEP, 1e-9)
	rig.zoom_steps(-100.0)
	assert_eq(rig.zoom, 0.0)


func test_a_pinch_that_spreads_zooms_in() -> void:
	var rig := _phone_rig()
	rig.zoom_by(1.5)
	assert_gt(rig.zoom, 0.0)
	var in_zoom := rig.zoom
	rig.zoom_by(1.0 / 1.5)
	assert_almost_eq(rig.zoom, 0.0, 1e-9)
	assert_gt(in_zoom, rig.zoom)


func test_there_is_nothing_to_pan_when_the_whole_board_is_in_view() -> void:
	assert_eq(CameraRig.pan_limit(0.0), Vector2.ZERO)
	var wide := CameraRig.pan_limit(1.0)
	assert_gt(wide.x, 0.0)
	assert_gt(wide.y, 0.0)
	assert_lte(wide.x, BoardSpace.size().x / 2.0)
	assert_lte(wide.y, BoardSpace.size().y / 2.0)


func test_rubber_band_lets_you_overscroll_a_little() -> void:
	assert_eq(CameraRig.rubber(2.0, 5.0), 2.0)
	assert_eq(CameraRig.rubber(-5.0, 5.0), -5.0)
	assert_almost_eq(CameraRig.rubber(9.0, 5.0), 5.0 + 4.0 * CameraRig.RUBBER, 1e-9)
	assert_almost_eq(CameraRig.rubber(-9.0, 5.0), -(5.0 + 4.0 * CameraRig.RUBBER), 1e-9)


func test_dragging_moves_the_scene_with_the_finger() -> void:
	var rig := _phone_rig()
	rig.set_zoom(1.0)
	rig.pan_by_pixels(Vector2(100.0, 0.0))
	# the scene follows the finger to the right, so the camera target moves to -x
	assert_lt(rig.pan.x, 0.0)
	assert_eq(rig.pan.y, 0.0)
	rig.release_pan()
	rig.pan_by_pixels(Vector2(0.0, 100.0))
	# dragging down pushes the scene toward the viewer: the target moves away (-z)
	assert_lt(rig.pan.y, 0.0)


func test_a_pan_stays_near_the_board_and_springs_back_after_release() -> void:
	var rig := _phone_rig()
	rig.set_zoom(1.0)
	rig.pan_by_pixels(Vector2(-2000.0, 0.0))
	var limit := CameraRig.pan_limit(1.0)
	# held: overscroll is damped, not unlimited
	assert_gt(rig.pan.x, limit.x)
	assert_lt(rig.pan.x, limit.x * 3.0)
	rig.release_pan()
	for i in 120:
		rig._process(1.0 / 60.0)
	assert_almost_eq(rig.pan.x, limit.x, 1e-3)


func test_zooming_out_pulls_a_panned_view_back_to_the_middle() -> void:
	var rig := _phone_rig()
	rig.set_zoom(1.0)
	rig.pan_by_pixels(Vector2(-300.0, 0.0))
	rig.release_pan()
	rig.set_zoom(0.0)
	for i in 240:
		rig._process(1.0 / 60.0)
	assert_almost_eq(rig.pan.x, 0.0, 1e-3)
	assert_almost_eq(rig.pan.y, 0.0, 1e-3)
