extends GutTest

const RULES := preload("res://content/valley/road_rules.gd")


func _s_bend() -> Array[Vector2]:
	return [Vector2(0.5, 3.5), Vector2(6.5, 3.5), Vector2(8.5, 9.5), Vector2(14.5, 10.5)]


## A road with one stretch drawn from its waypoints, as a section would.
class SplineSection:
	extends StraightSection

	func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
		var result := SectionResult.create(slot)
		var middle := Vector2(float(slot.rect.position.x + slot.rect.size.x / 2) + 0.5, 0.0)
		middle.y = float(slot.entry.y + slot.exit.y) / 2.0 + 0.5
		var points: Array[Vector2] = [
			Vector2(float(slot.entry.x) + 0.5, float(slot.entry.y) + 0.5),
			middle,
			Vector2(float(slot.exit.x) + 0.5, float(slot.exit.y) + 0.5),
		]
		result.road_curve = RoadSpline.build(points)
		result.road = result.road_curve.cells
		SectionSockets.place(result, socket_range(), rng, reserved(slot))
		return result


func test_the_curve_passes_through_every_waypoint() -> void:
	var points := _s_bend()
	var curve := RoadSpline.build(points)
	assert_eq(curve.xs[0], 0.5)
	assert_eq(curve.ys[0], 3.5)
	assert_eq(curve.xs[curve.xs.size() - 1], 14.5)
	assert_eq(curve.ys[curve.ys.size() - 1], 10.5)
	for waypoint in points:
		var near := 1.0e30
		for index in curve.xs.size():
			var dx := curve.xs[index] - waypoint.x
			var dy := curve.ys[index] - waypoint.y
			near = minf(near, sqrt(dx * dx + dy * dy))
		assert_lt(near, 0.01, "waypoint %s" % waypoint)


func test_samples_are_never_more_than_half_a_cell_apart() -> void:
	var curve := RoadSpline.build(_s_bend())
	for index in curve.xs.size() - 1:
		var dx := curve.xs[index + 1] - curve.xs[index]
		var dy := curve.ys[index + 1] - curve.ys[index]
		assert_lt(sqrt(dx * dx + dy * dy), 0.75)


func test_the_cells_step_one_at_a_time_without_repeats() -> void:
	var curve := RoadSpline.build(_s_bend())
	assert_eq(curve.cells[0], Vector2i(0, 3))
	assert_eq(curve.cells[curve.cells.size() - 1], Vector2i(14, 10))
	var seen := {}
	for index in curve.cells.size():
		assert_false(seen.has(curve.cells[index]), "cell %s twice" % curve.cells[index])
		seen[curve.cells[index]] = true
		if index > 0:
			assert_eq((curve.cells[index] - curve.cells[index - 1]).length_squared(), 1)


func test_each_cell_stands_on_its_point_and_the_points_never_go_back() -> void:
	var curve := RoadSpline.build(_s_bend())
	assert_eq(curve.cell_points.size(), curve.cells.size())
	for index in curve.cells.size():
		var point: int = curve.cell_points[index]
		var dx := curve.xs[point] - (float(curve.cells[index].x) + 0.5)
		var dy := curve.ys[point] - (float(curve.cells[index].y) + 0.5)
		assert_lt(sqrt(dx * dx + dy * dy), RULES.MAX_CELL_DEVIATION, "cell %d" % index)
		if index > 0:
			assert_gte(point, curve.cell_points[index - 1])


func test_the_road_turns_gently() -> void:
	var curve := RoadSpline.build(_s_bend())
	for index in range(1, curve.xs.size() - 1):
		var ax := curve.xs[index] - curve.xs[index - 1]
		var ay := curve.ys[index] - curve.ys[index - 1]
		var bx := curve.xs[index + 1] - curve.xs[index]
		var by := curve.ys[index + 1] - curve.ys[index]
		var cosine := (ax * bx + ay * by) / (sqrt(ax * ax + ay * ay) * sqrt(bx * bx + by * by))
		assert_gt(cosine, 0.8, "a sharp turn at sample %d" % index)


func test_the_same_waypoints_give_the_same_curve() -> void:
	var first := RoadSpline.build(_s_bend())
	var second := RoadSpline.build(_s_bend())
	assert_eq(first.xs, second.xs)
	assert_eq(first.ys, second.ys)
	assert_eq(first.cells, second.cells)
	assert_eq(first.cell_points, second.cell_points)


func test_the_route_from_a_curve_follows_it() -> void:
	var curve := RoadSpline.build(_s_bend())
	var route := Route.build_from_curve(curve.cells, curve)
	assert_true(route.curved)
	assert_eq(route.cell_points.size(), curve.cells.size())
	var last := curve.cells.size() - 1
	assert_gt(route.cell_distance(last), 14.0, "longer than the straight run")
	for index in last:
		assert_lte(route.cell_distance(index), route.cell_distance(index + 1))
	var middle := route.position_at(route.cell_distance(10))
	assert_lt(absf(middle.x - (float(curve.cells[10].x) + 0.5)), 1.0)
	assert_lt(absf(middle.y - (float(curve.cells[10].y) + 0.5)), 1.0)


func test_a_valley_with_spline_roads_stitches_and_plays() -> void:
	var sections := ValleySections.all()
	for id in [0, 5]:
		sections[id] = SplineSection.new()
	var map := ValleyStitcher.build(42, 32, 20, sections)
	assert_not_null(map)
	assert_gt(map.route_curves.size(), 0)
	var main: RoadCurve = map.route_curves[0]
	assert_eq(main.cells, map.path)
	assert_eq(main.cell_points.size(), map.path.size())
	assert_eq(map.route_curves.size(), map.routes.size())


func test_a_valley_without_splines_has_no_curves() -> void:
	assert_eq(MapGen.generate_valley(42).route_curves.size(), 0)


func test_the_second_road_follows_the_main_curve_after_the_join() -> void:
	var sections := ValleySections.all()
	sections[0] = SplineSection.new()
	var map := ValleyStitcher.build(42, 32, 20, sections)
	assert_eq(map.routes.size(), 2)
	var main: RoadCurve = map.route_curves[0]
	var second: RoadCurve = map.route_curves[1]
	assert_eq(second.cells, map.routes[1])
	assert_eq(second.cell_points.size(), map.routes[1].size())
	var main_route := Route.build_from_curve(map.routes[0], main)
	var second_route := Route.build_from_curve(map.routes[1], second)
	var offset := Route.join_offset(main_route, second_route, map.feeder_length, map.join_index)
	# the same point of the shared road is the same distance further along the second route
	for index in range(map.join_index + 3, map.path.size(), 7):
		var along_second := second_route.cell_distance(map.feeder_length + index - map.join_index)
		assert_almost_eq(along_second - main_route.cell_distance(index), offset, 0.0001)


func test_unevenly_spaced_waypoints_do_not_loop() -> void:
	# a long run, a short diagonal step, a long run: a uniform Catmull-Rom spline overshoots at the
	# short step (its tangents are as long as the long runs) and doubles back
	var points: Array[Vector2] = [
		Vector2(0.5, 0.5), Vector2(10.5, 0.5), Vector2(11.5, 1.5), Vector2(11.5, 11.5)
	]
	var curve := RoadSpline.build(points)
	var seen := {}
	for cell in curve.cells:
		assert_false(seen.has(cell), "cell %s twice" % cell)
		seen[cell] = true
	for index in range(1, curve.xs.size() - 1):
		var ax := curve.xs[index] - curve.xs[index - 1]
		var ay := curve.ys[index] - curve.ys[index - 1]
		var bx := curve.xs[index + 1] - curve.xs[index]
		var by := curve.ys[index + 1] - curve.ys[index]
		var cosine := (ax * bx + ay * by) / (sqrt(ax * ax + ay * ay) * sqrt(bx * bx + by * by))
		assert_gt(cosine, 0.5, "a hook at sample %d" % index)
