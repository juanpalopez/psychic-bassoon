## The 44 pt rule: how big a socket is drawn, in points, and the zoom a tap needs.
extends GutTest

## The owner's phone class: 844 by 390 points, drawn at 3 pixels a point. The game's canvas is
## 720 px tall (the project stretches to a 720 px tall canvas), so it is 1558 by 720 there.
const PHONE_POINTS := Vector2(844.0, 390.0)
const PHONE_SCALE := 3.0
const PHONE_CANVAS := Vector2i(1558, 720)


func test_a_point_on_the_phone_is_390_720ths_of_a_canvas_pixel() -> void:
	var per_pixel := TapZoom.points_per_pixel(
		float(PHONE_CANVAS.y), PHONE_POINTS.y * PHONE_SCALE, PHONE_SCALE
	)
	assert_almost_eq(per_pixel, PHONE_POINTS.y / float(PHONE_CANVAS.y), 1e-9)


func test_a_desktop_window_without_scaling_has_a_point_per_pixel() -> void:
	assert_almost_eq(TapZoom.points_per_pixel(720.0, 720.0, 1.0), 1.0, 1e-9)
	# a retina Mac: twice the pixels, a scale of 2
	assert_almost_eq(TapZoom.points_per_pixel(720.0, 1440.0, 2.0), 1.0, 1e-9)


func test_a_hidden_window_never_divides_by_zero() -> void:
	for value in [
		TapZoom.points_per_pixel(0.0, 720.0, 1.0),
		TapZoom.points_per_pixel(720.0, 0.0, 1.0),
		TapZoom.points_per_pixel(720.0, 720.0, 0.0),
	]:
		assert_true(is_finite(value) and value > 0.0, "got %f" % value)


func test_the_narrowest_width_of_a_square_is_its_side_however_it_is_turned() -> void:
	for degrees in [0.0, 17.0, 30.0, 45.0, 80.0]:
		var corners := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			corners.append(Vector2(100.0, 50.0) + (corner * 20.0).rotated(deg_to_rad(degrees)))
		assert_almost_eq(TapZoom.narrowest_width(corners), 40.0, 1e-4, "turned %f" % degrees)


func test_the_narrowest_width_of_a_long_shape_is_its_short_side() -> void:
	var corners := PackedVector2Array(
		[Vector2(0, 0), Vector2(100, 0), Vector2(100, 30), Vector2(0, 30)]
	)
	assert_almost_eq(TapZoom.narrowest_width(corners), 30.0, 1e-6)
	# a trapezoid, the way the far edge of a socket is drawn shorter than its near edge
	var trapezoid := PackedVector2Array(
		[Vector2(10, 0), Vector2(90, 0), Vector2(100, 40), Vector2(0, 40)]
	)
	assert_almost_eq(TapZoom.narrowest_width(trapezoid), 40.0, 1e-6)


func test_the_square_corners_are_on_the_ground_around_the_centre() -> void:
	var corners := TapZoom.square_corners(Vector3(3.0, 0.5, -2.0), 2.0)
	assert_eq(corners.size(), 4)
	for corner in corners:
		assert_almost_eq(corner.y, 0.5, 1e-9)
		assert_almost_eq(absf(corner.x - 3.0), 1.0, 1e-9)
		assert_almost_eq(absf(corner.z + 2.0), 1.0, 1e-9)


## A rig in a viewport of its own, sized like the phone's canvas.
func _phone_rig() -> CameraRig:
	var port := SubViewport.new()
	port.size = PHONE_CANVAS
	add_child_autofree(port)
	var rig := CameraRig.new()
	rig.canvas_height = float(PHONE_CANVAS.y)
	port.add_child(rig)
	rig.frame(float(PHONE_CANVAS.x) / float(PHONE_CANVAS.y))
	return rig


func _points_per_pixel() -> float:
	return TapZoom.points_per_pixel(
		float(PHONE_CANVAS.y), PHONE_POINTS.y * PHONE_SCALE, PHONE_SCALE
	)


func _min_pixels() -> float:
	return TapZoom.MIN_POINTS / _points_per_pixel()


## The narrowest width of a 2x2 socket on screen, measured with the engine's own camera.
func _measured(rig: CameraRig, centre: Vector3) -> float:
	var corners := PackedVector2Array()
	for corner in TapZoom.square_corners(centre, 2.0):
		corners.append(rig.camera().unproject_position(corner))
	return TapZoom.narrowest_width(corners)


func test_the_rigs_socket_size_matches_what_the_engine_draws() -> void:
	var rig := _phone_rig()
	for zoom_level in [0.0, 0.4, 0.8, 1.0]:
		rig.set_zoom(zoom_level)
		for centre in [Vector3.ZERO, Vector3(5.0, 0.0, -3.0), Vector3(-9.0, 1.0, 4.0)]:
			var expected := _measured(rig, centre)
			assert_almost_eq(
				rig.square_pixels(centre, 2.0),
				expected,
				expected * 1e-4,
				"zoom %s at %s" % [zoom_level, centre]
			)


func test_on_the_phone_the_overview_is_too_small_to_tap() -> void:
	# decision for #328: the whole 32x20 map does not fit at 44 pt sockets on the phone, so the
	# overview is for reading the map and a tap there zooms in first
	var rig := _phone_rig()
	rig.set_zoom(0.0)
	var points := rig.square_pixels(Vector3.ZERO, 2.0) * _points_per_pixel()
	assert_lt(points, TapZoom.MIN_POINTS, "a socket in the middle of the overview, %f pt" % points)
	assert_gt(points, 10.0, "but still big enough to read")


func test_the_zoom_a_tap_needs_makes_a_centred_socket_just_44_points() -> void:
	var rig := _phone_rig()
	var needed := rig.zoom_to_show(Vector3.ZERO, 2.0, _min_pixels())
	assert_gt(needed, 0.0)
	assert_lt(needed, 1.0)
	rig.set_zoom(needed)
	var points := _measured(rig, Vector3.ZERO) * _points_per_pixel()
	assert_gte(points, TapZoom.MIN_POINTS - 1e-3)
	assert_lt(points, TapZoom.MIN_POINTS + 0.5, "the least zoom that does, not a closer one")
	rig.set_zoom(needed - 0.02)
	assert_lt(_measured(rig, Vector3.ZERO) * _points_per_pixel(), TapZoom.MIN_POINTS)


func test_the_closest_zoom_draws_sockets_well_over_44_points() -> void:
	var rig := _phone_rig()
	rig.set_zoom(1.0)
	assert_gt(_measured(rig, Vector3.ZERO) * _points_per_pixel(), 2.0 * TapZoom.MIN_POINTS)


func test_every_socket_of_the_valley_can_be_flown_to_and_drawn_at_44_points() -> void:
	var rig := _phone_rig()
	var tried := 0
	for map_seed in [1, 7, 42, 2026]:
		var map := MapGen.generate(map_seed)
		for anchor in map.sockets:
			var centre := BoardSpace.footprint_centre(anchor, map.footprint)
			rig.set_zoom(0.0)
			var needed := rig.zoom_to_show(centre, float(map.footprint), _min_pixels())
			rig.fly_to(centre, needed)
			for i in 60:
				rig._process(1.0 / 60.0)
			assert_false(rig.flying(), "the flight ended")
			var where := "seed %d socket %s" % [map_seed, anchor]
			var points := _measured(rig, centre) * _points_per_pixel()
			assert_gte(points, TapZoom.MIN_POINTS - 1e-3, where)
			var screen := rig.camera().unproject_position(centre)
			var size := Vector2(PHONE_CANVAS)
			assert_true(
				Rect2(size * 0.25, size * 0.5).has_point(screen),
				"%s is in the middle of the screen: %s" % [where, screen]
			)
			tried += 1
	assert_gt(tried, 40, "the valley's sockets were tried")
