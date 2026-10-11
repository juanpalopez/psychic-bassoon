## The camera rig must fit the whole board for any landscape screen.
extends GutTest

const PITCH := 55.0
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


func test_the_rig_aims_the_camera_down_at_the_board() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	rig.frame(16.0 / 9.0)
	var camera := rig.get_child(0) as Camera3D
	assert_not_null(camera)
	assert_almost_eq(camera.rotation_degrees.x, -PITCH, 1e-4)
	assert_almost_eq(camera.fov, FOV, 1e-4)
	# the camera is behind the board (positive z) and above it
	assert_gt(camera.position.z, 0.0)
	assert_gt(camera.position.y, 0.0)
