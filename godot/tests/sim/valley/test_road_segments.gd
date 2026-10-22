extends GutTest

const SEGMENTS := preload("res://content/valley/segments.gd")
const LAYOUT := preload("res://content/valley/layout_rules.gd")
## Each road step is about a cell long when the curve is resampled, and two of them turn by less
## than about 30 degrees (cosine above 0.85).
const MIN_TURN_COS := 0.85
const SPAN_CELLS := 4
## Radius measured from three resampled points runs a little under the designed one.
const RADIUS_SLACK := 0.95
const ORIGIN := Vector2(10.5, 10.5)


func _curve(segment: RoadSegment) -> RoadCurve:
	return segment.build(ORIGIN)


## The curve resampled at one cell steps, in local coordinates.
func _steps(curve: RoadCurve) -> Array[Vector2]:
	var found: Array[Vector2] = [Vector2(curve.xs[0], curve.ys[0])]
	for index in range(1, curve.xs.size()):
		var point := Vector2(curve.xs[index], curve.ys[index])
		if point.distance_to(found[found.size() - 1]) >= 1.0:
			found.append(point)
	return found


func test_five_templates_with_their_ports() -> void:
	assert_eq(RoadSegment.ids().size(), 5)
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		assert_eq(segment.id, id)
		assert_eq(segment.points[0], Vector2.ZERO, "%s starts at the origin" % id)
		assert_eq(segment.exit, segment.points[segment.points.size() - 1])
		assert_almost_eq(segment.entry_heading.length(), 1.0, 0.0001)
		assert_almost_eq(segment.exit_heading.length(), 1.0, 0.0001)
		assert_gte(segment.clearance, segment.width / 2.0, "%s clearance" % id)


func test_ports_run_along_the_declared_headings() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var count := segment.points.size()
		var first := (segment.points[1] - segment.points[0]).normalized()
		var last := (segment.points[count - 1] - segment.points[count - 2]).normalized()
		assert_gt(first.dot(segment.entry_heading), 0.99, "%s entry" % id)
		assert_gt(last.dot(segment.exit_heading), 0.99, "%s exit" % id)


func test_cells_step_one_at_a_time_and_never_repeat() -> void:
	for id in RoadSegment.ids():
		var cells := _curve(RoadSegment.get_segment(id)).cells
		var seen := {}
		for index in cells.size():
			assert_false(seen.has(cells[index]), "%s repeats %s" % [id, cells[index]])
			seen[cells[index]] = true
			if index > 0:
				var step := cells[index] - cells[index - 1]
				assert_eq(absi(step.x) + absi(step.y), 1, "%s step %d" % [id, index])


func test_curvature_is_bounded_and_the_bend_is_broad() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var steps := _steps(_curve(segment))
		for index in range(1, steps.size() - 1):
			var before := steps[index] - steps[index - 1]
			var after := steps[index + 1] - steps[index]
			assert_gt(
				before.normalized().dot(after.normalized()), MIN_TURN_COS, "%s %d" % [id, index]
			)
			var cross := absf(before.cross(after))
			if cross > 0.0001:
				var radius := (
					before.length()
					* after.length()
					* (steps[index + 1] - steps[index - 1]).length()
					/ (2.0 * cross)
				)
				assert_gte(
					radius, segment.min_turn_radius * RADIUS_SLACK, "%s radius %d" % [id, index]
				)


func test_lane_gap_holds_inside_a_template() -> void:
	for id in RoadSegment.ids():
		var cells := _curve(RoadSegment.get_segment(id)).cells
		for later in range(LAYOUT.LANE_RUN, cells.size()):
			for earlier in later - LAYOUT.LANE_RUN + 1:
				var gap := (cells[later] - cells[earlier]).length_squared()
				assert_gte(
					gap, LAYOUT.LANE_GAP * LAYOUT.LANE_GAP, "%s %d %d" % [id, earlier, later]
				)


func test_a_template_is_the_same_every_time() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var first := _curve(segment)
		var second := segment.build(ORIGIN)
		assert_eq(first.cells, second.cells)
		assert_eq(first.xs, second.xs)
		assert_eq(first.ys, second.ys)


func test_the_wrap_keeps_a_radius_of_four() -> void:
	assert_gte(RoadSegment.get_segment(SEGMENTS.RIDGE_WRAP).min_turn_radius, 4.0)


func test_the_bridge_is_straight_and_flat_with_long_approaches() -> void:
	var segment := RoadSegment.get_segment(SEGMENTS.BRIDGE)
	var curve := _curve(segment)
	for index in curve.ys.size():
		assert_almost_eq(curve.ys[index], ORIGIN.y, 0.0001, "the span is flat and straight")
	var cells := curve.cells
	for index in cells.size():
		assert_eq(cells[index].y, int(ORIGIN.y), "level")
	# A span of a few cells leaves at least four cells of approach on each side.
	assert_gte((cells.size() - SPAN_CELLS) / 2, 4)
	assert_eq(segment.entry_heading, segment.exit_heading)
	assert_eq(segment.exit.y, 0.0)
