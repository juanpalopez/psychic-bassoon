## The camera on the 32x20 valley: the overview shows the whole map, the pan is clamped to the
## map plus a scenery margin, a flight eases the camera to a socket, and a run starts on the
## spawn side.
extends GutTest

const PHONE_POINTS := Vector2(844.0, 390.0)
const PHONE_CANVAS := Vector2i(1558, 720)
const SHAPES: Array[Vector2i] = [Vector2i(1558, 720), Vector2i(1280, 720), Vector2i(1024, 768)]


func _rig_in(width: int, height: int) -> CameraRig:
	var port := SubViewport.new()
	port.size = Vector2i(width, height)
	add_child_autofree(port)
	var rig := CameraRig.new()
	rig.canvas_height = float(height)
	port.add_child(rig)
	rig.frame(float(width) / float(height))
	return rig


func _phone_min_pixels() -> float:
	return TapZoom.MIN_POINTS * float(PHONE_CANVAS.y) / PHONE_POINTS.y


func _on_screen(rig: CameraRig, point: Vector3, size: Vector2) -> bool:
	var camera := rig.camera()
	if camera.is_position_behind(point):
		return false
	# a point the fit puts right on the edge of the screen counts as on it
	return Rect2(Vector2.ZERO, size).grow(0.5).has_point(camera.unproject_position(point))


func test_the_overview_shows_the_whole_valley_with_the_towers_on_it() -> void:
	for shape in SHAPES:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(0.0)
		assert_eq(rig.pan_range().size, Vector2.ZERO, "nothing to pan at the overview")
		for corner in BoardSpace.corners():
			for lift in [0.0, CameraRig.top_height()]:
				var point := corner + Vector3(0.0, lift, 0.0)
				assert_true(_on_screen(rig, point, Vector2(shape)), "%s at %s" % [point, shape])


func test_the_pan_keeps_the_middle_of_the_screen_within_the_scenery_margin() -> void:
	var limit := BoardSpace.size() / 2.0 + Vector2.ONE * CameraRig.SCENERY_MARGIN
	for shape in SHAPES:
		var rig := _rig_in(shape.x, shape.y)
		for zoom_level in [0.25, 0.5, 0.75, 1.0]:
			rig.set_zoom(zoom_level)
			var range := rig.pan_range()
			for x in [range.position.x, range.end.x]:
				for y in [range.position.y, range.end.y]:
					rig.pan = Vector2(x, y)
					rig._pan_raw = rig.pan
					rig._place()
					var middle := rig.ground_under(Vector2(shape) / 2.0)
					var where := "%s zoom %s pan %s" % [shape, zoom_level, rig.pan]
					assert_lte(absf(middle.x), limit.x + 1e-3, "x, " + where)
					assert_lte(absf(middle.y), limit.y + 1e-3, "z, " + where)


func test_the_scenery_margin_lets_the_middle_of_the_screen_past_the_map_edge() -> void:
	# so the spawn and the Heartstone, on the map's edge, can come to the middle of the screen
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	rig.set_zoom(1.0)
	var range := rig.pan_range()
	var half := BoardSpace.size() / 2.0
	assert_gt(range.end.x, half.x)
	assert_lt(range.position.x, -half.x)
	assert_gt(range.end.y, half.y)
	assert_lt(range.position.y, -half.y)


func test_a_drag_far_past_the_edge_settles_back_inside_the_margin() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	rig.set_zoom(0.8)
	for drag in [Vector2(-9000.0, 0.0), Vector2(9000.0, 0.0), Vector2(0.0, 9000.0)]:
		rig.pan_by_pixels(drag)
		rig.release_pan()
		for i in 180:
			rig._process(1.0 / 60.0)
		var range := rig.pan_range().grow(1e-3)
		assert_true(range.has_point(rig.pan), "settled after %s: %s in %s" % [drag, rig.pan, range])


func test_a_flight_eases_to_its_target_and_says_it_arrived() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	rig.set_zoom(0.0)
	watch_signals(rig)
	var target := Vector3(-8.0, 0.0, 3.0)
	rig.fly_to(target, 0.8)
	assert_true(rig.flying())
	rig._process(CameraRig.FLY_SECONDS / 2.0)
	assert_between(rig.zoom, 0.05, 0.75, "half way")
	assert_signal_not_emitted(rig, "flight_ended")
	rig._process(CameraRig.FLY_SECONDS)
	assert_false(rig.flying())
	assert_almost_eq(rig.zoom, 0.8, 1e-9)
	assert_signal_emitted_with_parameters(rig, "flight_ended", [true])
	var middle := rig.ground_under(Vector2(PHONE_CANVAS) / 2.0)
	assert_almost_eq(middle.x, target.x, 1e-3)
	assert_almost_eq(middle.y, target.z, 1e-3)
	# and it stays there: the spring has nothing to pull back
	for i in 60:
		rig._process(1.0 / 60.0)
	assert_almost_eq(rig.ground_under(Vector2(PHONE_CANVAS) / 2.0).x, target.x, 1e-3)


func test_a_raised_point_is_flown_to_the_middle_of_the_screen() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	var target := Vector3(4.0, 1.5, -2.0)
	rig.fly_to(target, 0.9)
	rig._process(CameraRig.FLY_SECONDS * 2.0)
	var screen := rig.camera().unproject_position(target)
	assert_almost_eq(screen.x, float(PHONE_CANVAS.x) / 2.0, 0.5)
	assert_almost_eq(screen.y, float(PHONE_CANVAS.y) / 2.0, 0.5)


func test_a_flight_never_ends_outside_the_limits() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	rig.fly_to(Vector3(400.0, 0.0, -400.0), 0.7)
	rig._process(CameraRig.FLY_SECONDS * 2.0)
	assert_true(rig.pan_range().grow(1e-6).has_point(rig.pan))


func test_the_player_takes_the_camera_back_mid_flight() -> void:
	for interrupt in ["pan", "pinch", "wheel", "zoom"]:
		var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
		watch_signals(rig)
		rig.fly_to(Vector3(6.0, 0.0, 2.0), 0.9)
		rig._process(CameraRig.FLY_SECONDS / 3.0)
		match interrupt:
			"pan":
				rig.pan_by_pixels(Vector2(10.0, 0.0))
			"pinch":
				rig.zoom_by(1.1, Vector2(400.0, 300.0))
			"wheel":
				rig.zoom_steps(1.0)
			"zoom":
				rig.set_zoom(0.2)
		assert_false(rig.flying(), interrupt)
		assert_signal_emitted_with_parameters(rig, "flight_ended", [false])
		var held := rig.zoom
		rig._process(CameraRig.FLY_SECONDS)
		assert_almost_eq(rig.zoom, held, 1e-9, "the flight does not resume, " + interrupt)


func test_a_run_starts_on_the_spawn_side_at_a_zoom_a_tap_can_build_at() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	var size := Vector2(PHONE_CANVAS)
	for map_seed in [1, 7, 42, 2026]:
		var map := MapGen.generate(map_seed)
		var spawn := BoardSpace.cell_to_world(map.path[0].x, map.path[0].y)
		rig.start_view(spawn, float(map.footprint), _phone_min_pixels())
		var where := "seed %d" % map_seed
		# sockets in the middle of the screen can be tapped right away
		var middle := rig.ground_under(size / 2.0)
		var centred := rig.square_pixels(Vector3(middle.x, 0.0, middle.y), float(map.footprint))
		assert_gte(centred, _phone_min_pixels() - 1e-3, where)
		# the spawn is on screen, on its left part
		var at := rig.camera().unproject_position(spawn)
		assert_true(_on_screen(rig, spawn, size), "spawn on screen, " + where)
		assert_lt(at.x, size.x * 0.45, "spawn on the left, " + where)
		# not the whole map: the far end of the road is off screen
		var last: Vector2i = map.path[map.path.size() - 1]
		var heart := BoardSpace.cell_to_world(last.x, last.y)
		assert_false(_on_screen(rig, heart, size), "the Heartstone end is off screen, " + where)


func test_the_start_view_is_never_the_overview_even_on_a_big_screen() -> void:
	# a desktop window has more points than a phone: the sockets are tappable sooner, but a run
	# still starts on the spawn side and not on the whole map
	var rig := _rig_in(1280, 720)
	var map := MapGen.generate(1)
	var spawn := BoardSpace.cell_to_world(map.path[0].x, map.path[0].y)
	rig.start_view(spawn, float(map.footprint), TapZoom.MIN_POINTS)
	assert_gte(rig.zoom, CameraRig.START_MIN_ZOOM)
	assert_true(_on_screen(rig, spawn, Vector2(1280, 720)))


func test_the_start_view_needs_no_settling() -> void:
	var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
	var map := MapGen.generate(42)
	var spawn := BoardSpace.cell_to_world(map.path[0].x, map.path[0].y)
	rig.start_view(spawn, float(map.footprint), _phone_min_pixels())
	var before := rig.pan
	for i in 30:
		rig._process(1.0 / 60.0)
	assert_almost_eq(rig.pan.distance_to(before), 0.0, 1e-6)
