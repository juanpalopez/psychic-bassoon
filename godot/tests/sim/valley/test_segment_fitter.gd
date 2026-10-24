extends GutTest

const SEGMENTS := preload("res://content/valley/segments.gd")
const ROUTES := preload("res://content/valley/route_rules.gd")
const REGION := Rect2i(0, 0, 10, 9)
const ENTRY := Vector2(0.5, 2.5)
const EXIT := Vector2(4.5, 8.5)


func _fit(
	id: StringName, entry: Vector2, entry_dir: Vector2, exit: Vector2, exit_dir: Vector2
) -> SegmentFitter.Fitted:
	return SegmentFitter.fit(
		RoadSegment.get_segment(id), entry, entry_dir, exit, exit_dir, REGION, 1.0
	)


func test_a_sweep_runs_from_the_entry_gate_to_the_exit_gate() -> void:
	var fitted := _fit(SEGMENTS.SWEEP, ENTRY, Vector2.RIGHT, EXIT, Vector2.DOWN)
	assert_true(fitted.ok(), fitted.reason)
	assert_eq(fitted.points[0], ENTRY)
	assert_eq(fitted.points[fitted.points.size() - 1], EXIT)
	var first := (fitted.points[1] - fitted.points[0]).normalized()
	var count := fitted.points.size()
	var last := (fitted.points[count - 1] - fitted.points[count - 2]).normalized()
	assert_gt(first.dot(Vector2.RIGHT), ROUTES.HEADING_COS)
	assert_gt(last.dot(Vector2.DOWN), ROUTES.HEADING_COS)
	for cell in RoadSpline.build(fitted.points).cells:
		assert_true(REGION.has_point(cell))


func test_all_eight_symmetries_find_their_gates() -> void:
	var cases: Array[Array] = [
		[Vector2(0.5, 2.5), Vector2.RIGHT, Vector2(4.5, 8.5), Vector2.DOWN],
		[Vector2(0.5, 8.5), Vector2.RIGHT, Vector2(4.5, 2.5), Vector2.UP],
		[Vector2(8.5, 2.5), Vector2.LEFT, Vector2(4.5, 8.5), Vector2.DOWN],
		[Vector2(8.5, 8.5), Vector2.LEFT, Vector2(4.5, 2.5), Vector2.UP],
		[Vector2(4.5, 0.5), Vector2.DOWN, Vector2(8.5, 6.5), Vector2.RIGHT],
		[Vector2(4.5, 0.5), Vector2.DOWN, Vector2(0.5, 6.5), Vector2.LEFT],
		[Vector2(4.5, 8.5), Vector2.UP, Vector2(8.5, 2.5), Vector2.RIGHT],
		[Vector2(4.5, 8.5), Vector2.UP, Vector2(0.5, 2.5), Vector2.LEFT],
	]
	for gates in cases:
		var fitted := _fit(SEGMENTS.SWEEP, gates[0], gates[1], gates[2], gates[3])
		assert_true(fitted.ok(), "%s: %s" % [gates, fitted.reason])


func test_ports_that_do_not_meet_are_rejected_with_a_reason() -> void:
	var s_bend := _fit(SEGMENTS.S_BEND, ENTRY, Vector2.RIGHT, Vector2(9.5, 2.5), Vector2.RIGHT)
	assert_false(s_bend.ok())
	assert_ne(s_bend.reason, "")
	var back := _fit(SEGMENTS.SWEEP, ENTRY, Vector2.RIGHT, EXIT, Vector2.UP)
	assert_false(back.ok())


func test_a_bridge_needs_east_west_ports_on_one_line() -> void:
	var level := _fit(SEGMENTS.BRIDGE, ENTRY, Vector2.RIGHT, Vector2(7.5, 2.5), Vector2.RIGHT)
	assert_true(level.ok(), level.reason)
	for point in level.points:
		assert_eq(point.y, ENTRY.y)
	var north := _fit(SEGMENTS.BRIDGE, ENTRY, Vector2.RIGHT, Vector2(7.5, 0.5), Vector2.UP)
	assert_false(north.ok(), "a sharp north exit is not a bridge")
	var off_row := _fit(SEGMENTS.BRIDGE, ENTRY, Vector2.RIGHT, Vector2(7.5, 4.5), Vector2.RIGHT)
	assert_false(off_row.ok(), "a bridge cannot step sideways")


func test_gates_too_close_or_too_far_for_the_scale_are_rejected() -> void:
	var close := _fit(SEGMENTS.SWEEP, ENTRY, Vector2.RIGHT, Vector2(1.5, 3.5), Vector2.DOWN)
	assert_false(close.ok())
	var far := SegmentFitter.fit(
		RoadSegment.get_segment(SEGMENTS.SWEEP),
		ENTRY,
		Vector2.RIGHT,
		Vector2(4.5, 8.5),
		Vector2.DOWN,
		Rect2i(0, 0, 10, 4),
		1.0
	)
	assert_false(far.ok(), "the road would leave a small region")


func test_the_fit_is_the_same_every_time() -> void:
	var first := _fit(SEGMENTS.LANDMARK, ENTRY, Vector2.RIGHT, EXIT, Vector2.DOWN)
	var second := _fit(SEGMENTS.LANDMARK, ENTRY, Vector2.RIGHT, EXIT, Vector2.DOWN)
	assert_eq(first.points, second.points)


func test_a_hook_runs_a_u_turn_inside_a_tall_region() -> void:
	var region := Rect2i(0, 0, 10, 12)
	var entry := Vector2(0.5, 1.5)
	var exit := Vector2(1.5, 10.5)
	var fitted := SegmentFitter.fit(
		RoadSegment.get_segment(SEGMENTS.HOOK),
		entry,
		Vector2.RIGHT,
		exit,
		Vector2.DOWN,
		region,
		1.0
	)
	assert_true(fitted.ok(), fitted.reason)
	assert_eq(fitted.points[fitted.points.size() - 1], exit)
	assert_gt(RoadSpline.build(fitted.points).cells.size(), 20)


func test_a_u_turn_joins_two_gates_on_one_border() -> void:
	var region := Rect2i(0, 0, 12, 10)
	var entry := Vector2(2.5, 0.5)
	var exit := Vector2(8.5, 0.5)
	for bias in [0.0, 0.7, 1.0]:
		var fitted := SegmentFitter.fit(
			RoadSegment.get_segment(SEGMENTS.U_TURN),
			entry,
			Vector2.DOWN,
			exit,
			Vector2.UP,
			region,
			bias
		)
		assert_true(fitted.ok(), "bias %s: %s" % [bias, fitted.reason])
		var cells := RoadSpline.build(fitted.points).cells
		assert_eq(cells[0], Vector2i(2, 0))
		assert_eq(cells[cells.size() - 1], Vector2i(8, 0))
		for cell in cells:
			assert_true(region.has_point(cell))


## A jog across a wide region, from a gate on row 2 (or row 7, mirrored north) to a gate `rows`
## away, both heading east.
func _jog(rows: int, north: bool) -> SegmentFitter.Fitted:
	var wide := Rect2i(0, 0, 16, 10)
	var start_row: float = 7.5 if north else 2.5
	var end_row: float = start_row - rows if north else start_row + rows
	return SegmentFitter.fit(
		RoadSegment.get_segment(SEGMENTS.JOG),
		Vector2(0.5, start_row),
		Vector2.RIGHT,
		Vector2(12.5, end_row),
		Vector2.RIGHT,
		wide,
		1.0
	)


func test_a_jog_fits_a_gate_four_or_five_rows_over_either_way() -> void:
	for rows in [4, 5]:
		for north in [false, true]:
			var fitted := _jog(rows, north)
			assert_true(fitted.ok(), "%d rows north %s: %s" % [rows, north, fitted.reason])
			if not fitted.ok():
				continue
			var count := fitted.points.size()
			var end_row: float = 7.5 - rows if north else 2.5 + rows
			assert_eq(fitted.points[count - 1], Vector2(12.5, end_row))
			var cells := RoadSpline.build(fitted.points).cells
			for cell in cells:
				assert_true(Rect2i(0, 0, 16, 10).has_point(cell))


func test_a_jog_leaves_the_gate_row_and_lands_on_the_new_row() -> void:
	var fitted := _jog(5, false)
	assert_true(fitted.ok(), fitted.reason)
	var cells := RoadSpline.build(fitted.points).cells
	assert_eq(cells[0].y, 2, "starts on the entry row")
	assert_eq(cells[cells.size() - 1].y, 7, "ends five rows down")
	assert_eq(cells[cells.size() - 1].x, 12)


func test_a_jog_fit_is_the_same_every_time() -> void:
	var first := _jog(4, true)
	var second := _jog(4, true)
	assert_eq(first.points, second.points)


func test_seeded_gate_rows_all_fit_as_jogs() -> void:
	var rng := Rng.create(11)
	for draw in 200:
		var rows := 4 + rng.next_int(2)
		var fitted := _jog(rows, draw % 2 == 1)
		assert_true(fitted.ok(), "draw %d, %d rows: %s" % [draw, rows, fitted.reason])
