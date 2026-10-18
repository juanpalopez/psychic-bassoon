## The ground the camera shows and the pans that keep it over the board.
extends GutTest

const FOV := 20.0


func test_the_footprint_and_bounds_maths() -> void:
	var foot := Rect2(Vector2(-3.0, -2.0), Vector2(6.0, 5.0))
	var bounds := CameraRig.pan_bounds(Vector2(10.0, 8.0), foot)
	assert_eq(bounds.position, Vector2(-7.0, -6.0))
	assert_eq(bounds.end, Vector2(7.0, 5.0))
	# a view wider than the board has no range that fits: it collapses to the midpoint of the
	# limits (here the limits are 1 and -1 and a footprint off-centre moves it)
	var wide := CameraRig.pan_bounds(Vector2(2.0, 8.0), foot)
	assert_eq(wide.position.x, 0.0)
	assert_eq(wide.end.x, 0.0)
	var off := CameraRig.pan_bounds(
		Vector2(2.0, 8.0), Rect2(Vector2(-5.0, -2.0), Vector2(6.0, 5.0))
	)
	# low = -2 + 5 = 3, high = 2 - 1 = 1: the midpoint is 2
	assert_eq(off.position.x, 2.0)
	assert_eq(off.size.x, 0.0)


func test_the_ramp_narrows_the_pans_toward_nothing_when_zoomed_out() -> void:
	var bounds := Rect2(Vector2(-4.0, -2.0), Vector2(10.0, 4.0))
	assert_eq(CameraRig.pan_ramp(bounds, CameraRig.PAN_RAMP_ZOOM), bounds)
	var zero := CameraRig.pan_ramp(bounds, 0.0)
	assert_eq(zero.size, Vector2.ZERO)
	assert_eq(zero.position, Vector2.ZERO, "the pan nearest the middle")
	var half := CameraRig.pan_ramp(bounds, CameraRig.PAN_RAMP_ZOOM / 2.0)
	assert_eq(half.position, Vector2(-2.0, -1.0))
	assert_eq(half.end, Vector2(3.0, 1.0))
	# a collapsed axis (a midpoint) moves smoothly to 0
	var mid := CameraRig.pan_ramp(
		Rect2(Vector2(2.0, 0.0), Vector2(0.0, 0.0)), CameraRig.PAN_RAMP_ZOOM / 2.0
	)
	assert_eq(mid.position.x, 1.0)


func test_a_turned_footprint_is_the_box_around_the_turned_screen() -> void:
	var plain := CameraRig.footprint(20.0, 59.0, FOV, 16.0 / 9.0, 0.0)
	var turned := CameraRig.footprint(20.0, 59.0, FOV, 16.0 / 9.0, 40.0)
	# turning a wide, shallow screen makes its box deeper and narrower
	assert_gt(turned.size.y, plain.size.y)
	assert_lt(turned.size.x, plain.size.x * 1.2)
	# the screen is centred on the target at yaw 0
	assert_almost_eq(plain.position.x, -plain.end.x, 1e-6)


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


func test_the_footprint_is_the_box_around_where_the_screen_corners_meet_the_ground() -> void:
	for shape in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(2160, 720)]:
		for zoom_level in [0.0, 0.5, 1.0]:
			var rig := _rig_in(shape.x, shape.y)
			rig.set_zoom(zoom_level)
			var size := Vector2(shape)
			for share in [1.0, 0.5]:
				var low := Vector2(INF, INF)
				var high := Vector2(-INF, -INF)
				for corner in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2.ONE]:
					var pixel: Vector2 = size / 2.0 + (corner * size - size / 2.0) * share
					var ground := rig.ground_under(pixel)
					low = Vector2(minf(low.x, ground.x), minf(low.y, ground.y))
					high = Vector2(maxf(high.x, ground.x), maxf(high.y, ground.y))
				var foot := CameraRig.footprint(
					rig._distance(),
					CameraRig.pitch_for(zoom_level),
					rig.fov_degrees,
					size.x / size.y,
					CameraRig.YAW_DEGREES,
					share
				)
				var where := "%s zoom %s share %s" % [shape, zoom_level, share]
				assert_almost_eq(foot.position.x, low.x, 1e-3, "left, " + where)
				assert_almost_eq(foot.position.y, low.y, 1e-3, "far, " + where)
				assert_almost_eq(foot.end.x, high.x, 1e-3, "right, " + where)
				assert_almost_eq(foot.end.y, high.y, 1e-3, "near, " + where)
