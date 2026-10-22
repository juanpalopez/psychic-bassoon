extends GutTest

const SEGMENTS := preload("res://content/valley/segments.gd")
const LAYOUT := preload("res://content/valley/layout_rules.gd")
## Each road step is about a cell long when the curve is resampled, and two of them turn by less
## than about 30 degrees (cosine above 0.85).
const MIN_TURN_COS := 0.85
## Radius measured from three resampled points runs a little under the designed one.
const RADIUS_SLACK := 0.95
## Stretches of road more than this many cells apart along it keep their clearance.
const NEAR_STEPS := 6
## The fitter places a template at any offset in a cell, so the cell rules hold for these
## fractions (a coordinate exactly on a cell edge is not a case: entries are cell centres).
const FRACTIONS: Array[float] = [0.1, 0.25, 0.5, 0.75]
const BASE := 10.0
const ORIGIN := Vector2(10.5, 10.5)
## The least span a bridge crosses: its middle cells, from x 2 to 3 (centres of two cells).
const SPAN_LEAST := 1.0
const APPROACH := 2.0
const RUN_ON := 1.0


## The template scaled by `scale` along its axes and turned: local x to `axis`, local y to the
## right of it (or the left, mirrored), at `origin`.
func _placed(
	segment: RoadSegment, origin: Vector2, scale: Vector2, axis: Vector2, mirror: float
) -> RoadCurve:
	var across := Vector2(-axis.y, axis.x) * mirror
	var points: Array[Vector2] = []
	for point in segment.points:
		points.append(origin + axis * (point.x * scale.x) + across * (point.y * scale.y))
	return RoadSpline.build(points)


## Every way the fitter may place a template: scales, the eight symmetries, fractional origins.
func _variants(segment: RoadSegment) -> Array[RoadCurve]:
	var low := segment.scale_range.x
	var high := segment.scale_range.y
	# Both axes by the same factor: the fitter rejects the lopsided mixes that bend too sharply.
	var scales: Array[Vector2] = [Vector2(low, low), Vector2.ONE, Vector2(high, high)]
	var found: Array[RoadCurve] = []
	for scale in scales:
		for axis in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			for mirror in [1.0, -1.0]:
				for fx in FRACTIONS:
					for fy in FRACTIONS:
						var origin := Vector2(BASE + fx, BASE + fy)
						found.append(_placed(segment, origin, scale, axis, mirror))
	return found


## The curve resampled at one cell steps.
func _steps(curve: RoadCurve) -> Array[Vector2]:
	var found: Array[Vector2] = [Vector2(curve.xs[0], curve.ys[0])]
	for index in range(1, curve.xs.size()):
		var point := Vector2(curve.xs[index], curve.ys[index])
		if point.distance_to(found[found.size() - 1]) >= 1.0:
			found.append(point)
	return found


func test_five_templates_with_their_ports() -> void:
	var keys: Array = SEGMENTS.DATA.keys()
	assert_eq(RoadSegment.ids().size(), 5)
	assert_eq(keys.size(), RoadSegment.ids().size())
	for id in keys:
		assert_true(RoadSegment.ids().has(id), "%s is listed" % id)
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
		assert_gt(first.dot(segment.entry_heading), 0.9999, "%s entry" % id)
		assert_gt(last.dot(segment.exit_heading), 0.9999, "%s exit" % id)


func test_cells_step_one_at_a_time_and_never_repeat_wherever_it_is_placed() -> void:
	for id in RoadSegment.ids():
		for curve in _variants(RoadSegment.get_segment(id)):
			var cells := curve.cells
			var seen := {}
			for index in cells.size():
				assert_false(seen.has(cells[index]), "%s repeats %s" % [id, cells[index]])
				seen[cells[index]] = true
				if index > 0:
					var step := cells[index] - cells[index - 1]
					assert_eq(absi(step.x) + absi(step.y), 1, "%s step %d" % [id, index])


func test_lane_gap_holds_wherever_it_is_placed() -> void:
	var gap: int = LAYOUT.LANE_GAP
	for id in RoadSegment.ids():
		for curve in _variants(RoadSegment.get_segment(id)):
			var cells := curve.cells
			for later in range(LAYOUT.LANE_RUN, cells.size()):
				for earlier in later - LAYOUT.LANE_RUN + 1:
					var apart := (cells[later] - cells[earlier]).length_squared()
					assert_gte(apart, gap * gap, "%s %d %d" % [id, earlier, later])


func test_curvature_is_bounded_when_placed_and_scaled() -> void:
	for id in RoadSegment.ids():
		for curve in _variants(RoadSegment.get_segment(id)):
			var steps := _steps(curve)
			for index in range(1, steps.size() - 1):
				var before := (steps[index] - steps[index - 1]).normalized()
				var after := (steps[index + 1] - steps[index]).normalized()
				assert_gt(before.dot(after), MIN_TURN_COS, "%s %d" % [id, index])


func test_the_bend_is_as_broad_as_declared() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var steps := _steps(_placed(segment, ORIGIN, Vector2.ONE, Vector2.RIGHT, 1.0))
		var tightest := 1.0e9
		for index in range(1, steps.size() - 1):
			var before := steps[index] - steps[index - 1]
			var after := steps[index + 1] - steps[index]
			var cross := absf(before.cross(after))
			if cross > 0.0001:
				var chord := (steps[index + 1] - steps[index - 1]).length()
				tightest = minf(tightest, before.length() * after.length() * chord / (2.0 * cross))
		assert_gte(tightest, segment.min_turn_radius * RADIUS_SLACK, "%s radius" % id)
	assert_gte(RoadSegment.get_segment(SEGMENTS.RIDGE_WRAP).min_turn_radius, 4.0)


func test_no_two_stretches_come_within_the_clearance() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var steps := _steps(_placed(segment, ORIGIN, Vector2.ONE, Vector2.RIGHT, 1.0))
		for later in range(NEAR_STEPS, steps.size()):
			for earlier in later - NEAR_STEPS + 1:
				var apart := steps[later].distance_to(steps[earlier])
				assert_gte(apart, segment.clearance, "%s %d %d" % [id, earlier, later])


func test_a_template_is_the_same_every_time() -> void:
	for id in RoadSegment.ids():
		var segment := RoadSegment.get_segment(id)
		var first := segment.build(ORIGIN)
		var second := segment.build(ORIGIN)
		assert_eq(first.cells, second.cells)
		assert_eq(first.xs, second.xs)
		assert_eq(first.ys, second.ys)


func test_the_bridge_is_straight_and_flat_at_every_scale() -> void:
	var segment := RoadSegment.get_segment(SEGMENTS.BRIDGE)
	assert_eq(segment.entry_heading, segment.exit_heading)
	assert_eq(segment.exit.y, 0.0)
	for point in segment.points:
		assert_eq(point.y, 0.0, "the span is flat and straight")
	# Stretched, never shrunk: a span of at least two cells and four cells of approach on each
	# side at the least scale, so at every allowed scale.
	assert_gte(segment.scale_range.x, 1.0)
	assert_gte(segment.exit.x * segment.scale_range.x, APPROACH + SPAN_LEAST + RUN_ON)
	assert_gte(segment.points[1].x, APPROACH, "approach before the span")
	assert_gte(segment.exit.x - segment.points[2].x, RUN_ON, "run on after the span")
	for scale in [segment.scale_range.x, 1.5, segment.scale_range.y]:
		var curve := _placed(segment, ORIGIN, Vector2(scale, 1.0), Vector2.RIGHT, 1.0)
		for index in curve.ys.size():
			assert_almost_eq(curve.ys[index], ORIGIN.y, 0.0001)
		for cell in curve.cells:
			assert_eq(cell.y, int(ORIGIN.y), "level")
