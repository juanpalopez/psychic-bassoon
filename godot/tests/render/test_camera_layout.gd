## The camera rules on the 40 by 24 layout valley (#480): the overview shows the whole map, the
## pan stays inside the map plus the scenery margin, and a run starts on the spawn side.
extends GutTest

const PHONE_POINTS := Vector2(844.0, 390.0)
const PHONE_CANVAS := Vector2i(1558, 720)
const SHAPES: Array[Vector2i] = [Vector2i(1558, 720), Vector2i(1280, 720), Vector2i(1024, 768)]
const SEEDS: Array[int] = [1, 2, 3]

var _map: GameMap


## The board is static, so a test that names another board gives the game board back.
func after_each() -> void:
	BoardSpace.reset()


func _use_layout(map_seed: int) -> void:
	_map = MapGen.generate_layout_valley(map_seed)
	BoardSpace.use_map(_map.cols, _map.rows)


func _rig_in(width: int, height: int) -> CameraRig:
	var port := SubViewport.new()
	port.size = Vector2i(width, height)
	add_child_autofree(port)
	var rig := CameraRig.new()
	rig.canvas_height = float(height)
	port.add_child(rig)
	rig.frame(float(width) / float(height))
	return rig


func _on_screen(rig: CameraRig, point: Vector3, size: Vector2) -> bool:
	var camera := rig.camera()
	if camera.is_position_behind(point):
		return false
	return Rect2(Vector2.ZERO, size).grow(0.5).has_point(camera.unproject_position(point))


func test_the_overview_shows_the_whole_layout_valley() -> void:
	_use_layout(1)
	assert_eq(BoardSpace.size(), Vector2(40.0, 24.0))
	for shape in SHAPES:
		var rig := _rig_in(shape.x, shape.y)
		rig.set_zoom(0.0)
		assert_eq(rig.pan_range().size, Vector2.ZERO, "nothing to pan at the overview")
		for corner in BoardSpace.corners():
			for lift in [0.0, CameraRig.top_height()]:
				var point := corner + Vector3(0.0, lift, 0.0)
				assert_true(_on_screen(rig, point, Vector2(shape)), "%s at %s" % [point, shape])


func test_the_pan_keeps_the_middle_within_the_scenery_margin_on_the_layout_valley() -> void:
	_use_layout(1)
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


func test_a_run_starts_on_the_spawn_side_at_a_buildable_zoom_on_the_layout_valley() -> void:
	var size := Vector2(PHONE_CANVAS)
	var min_pixels := TapZoom.MIN_POINTS * float(PHONE_CANVAS.y) / PHONE_POINTS.y
	for map_seed in SEEDS:
		_use_layout(map_seed)
		var rig := _rig_in(PHONE_CANVAS.x, PHONE_CANVAS.y)
		var spawn := BoardSpace.cell_to_world(_map.path[0].x, _map.path[0].y)
		rig.start_view(spawn, float(_map.footprint), min_pixels)
		var where := "layout seed %d" % map_seed
		assert_gte(rig.zoom, CameraRig.START_MIN_ZOOM, where)
		var middle := rig.ground_under(size / 2.0)
		var centred := rig.square_pixels(Vector3(middle.x, 0.0, middle.y), float(_map.footprint))
		assert_gte(centred, min_pixels - 1e-3, where)
		assert_true(_on_screen(rig, spawn, size), "spawn on screen, " + where)
		assert_lt(rig.camera().unproject_position(spawn).x, size.x * 0.45, "spawn left, " + where)
		var last: Vector2i = _map.path[_map.path.size() - 1]
		var heart := BoardSpace.cell_to_world(last.x, last.y)
		assert_false(_on_screen(rig, heart, size), "the Heartstone end is off screen, " + where)
