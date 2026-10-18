## The pans the rig allows: the middle of the screen stays over the board, the limits do not
## jump as the zoom changes, and a pinch keeps the point under the fingers.
extends GutTest

const SHAPES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(720, 1280), Vector2i(2160, 720)
]
const LANDSCAPE: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1558, 720), Vector2i(1024, 768), Vector2i(2160, 720)
]


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


func _put(rig: CameraRig, at: Vector2) -> void:
	rig.pan = at
	rig._pan_raw = at
	rig._place()


func test_the_middle_of_the_screen_stays_over_the_board_at_every_allowed_pan() -> void:
	var half := BoardSpace.size() / 2.0
	var share := CameraRig.SCREEN_SHARE_OVER_BOARD
	for shape in [Vector2i(1280, 720), Vector2i(2160, 720), Vector2i(1024, 768)]:
		for zoom_level in [0.3, 0.6, 1.0]:
			var rig := _rig_in(shape.x, shape.y)
			rig.set_zoom(zoom_level)
			var range := rig.pan_range()
			var size := Vector2(shape)
			var where := "%s zoom %s" % [shape, zoom_level]
			var foot := CameraRig.footprint(
				rig._distance(),
				CameraRig.pitch_for(zoom_level),
				rig.fov_degrees,
				size.x / size.y,
				CameraRig.YAW_DEGREES,
				share
			)
			# an axis can keep the rule only where the middle of the screen is narrower than the
			# board; where it is wider the rule cannot hold, and the range is a single pan
			var fits_x := foot.size.x < half.x * 2.0
			var fits_z := foot.size.y < half.y * 2.0
			if not fits_x:
				assert_eq(range.size.x, 0.0, "no room in x, " + where)
			if not fits_z:
				assert_eq(range.size.y, 0.0, "no room in z, " + where)
			for x in [range.position.x, range.end.x]:
				for y in [range.position.y, range.end.y]:
					_put(rig, Vector2(x, y))
					for corner in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2.ONE]:
						var pixel: Vector2 = size / 2.0 + (corner * size - size / 2.0) * share
						var ground := rig.ground_under(pixel)
						if fits_x:
							assert_lte(
								absf(ground.x), half.x + 1e-3, "x at %s pan %s" % [where, [x, y]]
							)
						if fits_z:
							assert_lte(
								absf(ground.y), half.y + 1e-3, "z at %s pan %s" % [where, [x, y]]
							)


func test_there_is_room_to_pan_both_ways_when_closest_on_every_shape() -> void:
	for shape in SHAPES:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(1.0)
		var range := rig.pan_range()
		assert_true(range.size.x > 0.0 and range.size.y > 0.0, "room at %s: %s" % [shape, range])


func test_the_pan_limits_do_not_jump_as_the_zoom_changes() -> void:
	# the limits grow with the board, so a step may move them by a share of its width: a
	# 160th (0.1 cells on the 16-wide board, 0.2 on the 32-wide valley); a jump is far more
	var most := BoardSpace.size().x / 160.0
	for shape in SHAPES:
		var rig := _rig_in(shape.x, shape.y)
		var before: Array[Vector2] = []
		var worst := 0.0
		for step in 201:
			rig.set_zoom(float(step) * 0.005)
			var range := rig.pan_range()
			var now: Array[Vector2] = [
				Vector2(1000.0, 1000.0).clamp(range.position, range.end),
				Vector2(-1000.0, -1000.0).clamp(range.position, range.end),
				Vector2.ZERO.clamp(range.position, range.end),
			]
			if not before.is_empty():
				for i in now.size():
					worst = maxf(worst, now[i].distance_to(before[i]))
			before = now
		assert_lte(worst, most, "largest jump in one zoom step at %s" % shape)


## Pinches 1.05 off-centre at (0.8w, 0.25h) from the middle of the allowed pans. Returns whether
## the limits left the pinned point free, and how far it drifted.
func _pinch(shape: Vector2i, zoom_level: float) -> Dictionary:
	var rig := _rig_in(shape.x, shape.y)
	rig.set_zoom(zoom_level)
	var range := rig.pan_range()
	_put(rig, range.position + range.size / 2.0)
	var centre := Vector2(shape) * Vector2(0.8, 0.25)
	var before := rig.ground_under(centre)
	rig.zoom_by(1.05, centre)
	var free := rig.pan.is_equal_approx(rig._pan_raw)
	if not free:
		# the limits bind: the view still ends inside them
		assert_true(rig.pan_range().grow(1e-6).has_point(rig.pan), "inside the limits")
	return {"free": free, "drift": before.distance_to(rig.ground_under(centre))}


func test_a_pinch_keeps_the_point_under_the_fingers_where_it_was() -> void:
	var free := 0
	for shape in [Vector2i(1280, 720), Vector2i(2160, 720), Vector2i(720, 1280)]:
		for zoom_level in [0.5, 0.73, 0.9]:
			var result := _pinch(shape, zoom_level)
			if result.free:
				free += 1
				assert_lt(result.drift, 1e-3, "drift at %s zoom %s" % [shape, zoom_level])
	assert_gte(free, 7, "at least 7 of the 9 pinches are free of the limits")


func test_a_pinch_at_low_zoom_on_a_landscape_screen_keeps_the_point_too() -> void:
	for shape in LANDSCAPE:
		for zoom_level in [0.3, 0.45]:
			var result := _pinch(shape, zoom_level)
			assert_true(result.free, "free at %s zoom %s" % [shape, zoom_level])
			assert_lt(result.drift, 1e-3, "drift at %s zoom %s" % [shape, zoom_level])


func test_the_screen_centre_reaches_within_a_cell_of_every_board_edge_when_closest() -> void:
	var need := BoardSpace.size() / 2.0 - Vector2.ONE
	for shape in [
		Vector2i(1280, 720),
		Vector2i(1558, 720),
		Vector2i(1024, 768),
		Vector2i(720, 1280),
		Vector2i(2160, 720)
	]:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(1.0)
		var range := rig.pan_range()
		var where := "%s: %s" % [shape, range]
		assert_gte(range.end.x, need.x, "right edge, " + where)
		assert_lte(range.position.x, -need.x, "left edge, " + where)
		assert_gte(range.end.y, need.y, "near edge, " + where)
		assert_lte(range.position.y, -need.y, "far edge, " + where)


func test_both_axes_have_room_to_pan_by_zoom_0_4_on_landscape_screens() -> void:
	for shape in LANDSCAPE:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(0.4)
		var range := rig.pan_range()
		assert_true(range.size.x > 0.0 and range.size.y > 0.0, "room at %s: %s" % [shape, range])
