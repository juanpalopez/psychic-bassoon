extends GutTest

const FOLD := preload("res://content/valley/ancient_fold_region_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
## The layout and its stitch take a moment a seed, so the sweeps cover 1..300 in steps.
const STEP := 3
const LAST_SEED := 300
const ATTEMPTS := 20

var _layouts := {}


func _layout(seed: int) -> ValleyLayout:
	if not _layouts.has(seed):
		_layouts[seed] = ValleyLayout.generate(seed, 40, 24)
	return _layouts[seed]


## The first attempt (as the stitcher counts them) of the section that passes its own checks.
func _draw(seed: int) -> SectionResult:
	var layout := _layout(seed)
	var slot := layout.slots[ValleyLayout.Region.ANCIENT_FOLD]
	for attempt in ATTEMPTS:
		var result := AncientFoldRegion.new().generate(slot, layout.rng_for(slot.id, attempt))
		if ValleyChecks.section_problems(slot, result, AncientFoldRegion.new()).is_empty():
			return result
	return null


func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func test_the_layout_places_the_region_top_right_and_the_stitch_passes() -> void:
	# a stitch is returned only when `ValleyChecks.all_problems` is empty
	for seed in range(1, LAST_SEED + 1, STEP):
		var layout := _layout(seed)
		assert_not_null(layout, "seed %d" % seed)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout, true)
		assert_not_null(map, "seed %d" % seed)


func test_some_attempt_passes_every_check_for_every_seed() -> void:
	for seed in range(1, LAST_SEED + 1, STEP):
		assert_not_null(_draw(seed), "seed %d" % seed)


func test_the_feeder_enters_at_the_top_right_and_runs_diagonally() -> void:
	for seed in range(1, LAST_SEED + 1, STEP):
		var result := _draw(seed)
		var start := result.feeder[0]
		var end := result.feeder[result.feeder.size() - 1]
		var right := result.rect.end.x - 1
		assert_eq(start.y, 0, "seed %d starts at %s" % [seed, start])
		assert_true(_gap(start, Vector2i(right, 0)) <= FOLD.START_REACH, "seed %d" % seed)
		assert_gte(absi(start.x - end.x), FOLD.FEEDER_MIN_SPAN, "seed %d" % seed)
		assert_gte(absi(start.y - end.y), FOLD.FEEDER_MIN_SPAN, "seed %d" % seed)
		assert_gte(result.feeder.size(), RULES.FEEDER_MIN_CELLS)
		assert_eq(result.feeder_curve.cells, result.feeder, "seed %d" % seed)


func test_the_second_roads_foes_enter_at_the_board_edge() -> void:
	# #462: a feeder that started on the east edge below the top row spawned its foes above the
	# board and walked them down into it, entering 2 to 3 cells inside (seeds 7920 and 47515)
	var seeds: Array[int] = [7920, 47515]
	for seed in range(1, LAST_SEED + 1):
		seeds.append(seed)
	for seed in seeds:
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), _layout(seed), true)
		var start: Vector2i = map.routes[1][0]
		assert_eq(start.y, 0, "seed %d starts on the top edge at %s" % [seed, start])
		var second := Route.build_from_curve(map.routes[1], map.route_curves[1])
		assert_lt(second.ys[0], 0.0, "seed %d spawns off the board" % seed)
		assert_lte(
			second.cumulative[1], RULES.CELL_CENTRE + RULES.SPAWN_OFFSET + 1e-9, "seed %d" % seed
		)


func test_the_feeder_joins_inside_the_region_and_keeps_clear_of_the_road() -> void:
	for seed in range(1, LAST_SEED + 1, STEP):
		var result := _draw(seed)
		var end := result.feeder[result.feeder.size() - 1]
		assert_eq(_gap(end, result.feeder_join), 1, "seed %d" % seed)
		assert_true(result.road.has(result.feeder_join))
		assert_lt(result.road.find(result.feeder_join), result.road.size() - 1)
		for cell in result.feeder:
			assert_true(result.rect.has_point(cell))
			assert_false(result.road.has(cell))
			for road_cell in result.road:
				var near := _gap(cell, road_cell) < RULES.FEEDER_CLEARANCE
				assert_false(near and road_cell != result.feeder_join, "seed %d" % seed)


func test_at_least_three_tight_sockets_cover_the_join() -> void:
	for seed in range(1, LAST_SEED + 1, STEP):
		var result := _draw(seed)
		var near := 0
		# a block stands the band's room further off the road, and the rule widens by the same
		# (`SectionSockets.reach_extra`, 0.5 on the 2.0 band, #446)
		var reach := FOLD.MERGE_COVER_REACH + SectionSockets.reach_extra(result)
		for index in result.sockets.size():
			var gap := SectionSockets.centre_gap(result.sockets[index], result.feeder_join)
			if gap <= reach:
				near += 1
		assert_gte(near, FOLD.MERGE_COVER_MIN, "seed %d" % seed)
		assert_gte(result.socket_tags.count(SectionResult.Tag.MERGE), FOLD.MERGE_COVER_MIN)
		assert_gte(result.sockets.size(), FOLD.SOCKET_MIN)
		assert_lte(result.sockets.size(), FOLD.SOCKET_MAX)


func test_ruins_are_solid_rock_away_from_the_roads_and_the_join() -> void:
	var ruins := 0
	for seed in range(1, LAST_SEED + 1, STEP):
		var result := _draw(seed)
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				if result.is_walkable(cell):
					continue
				ruins += 1
				assert_eq(result.region_at(cell), GameMap.Region.ROCKS)
				assert_false(result.road.has(cell) or result.feeder.has(cell))
				assert_gte(_gap(cell, result.feeder_join), FOLD.RUIN_JOIN_GAP)
	assert_gt(ruins, 0, "some seed has ruins")


func test_the_section_is_reproducible() -> void:
	for seed in SEEDS:
		var slot := _layout(seed).slots[ValleyLayout.Region.ANCIENT_FOLD]
		var a := AncientFoldRegion.new().generate(slot, _layout(seed).rng_for(slot.id, 0))
		var b := AncientFoldRegion.new().generate(slot, _layout(seed).rng_for(slot.id, 0))
		assert_eq(a.road, b.road)
		assert_eq(a.feeder, b.feeder)
		assert_eq(a.feeder_join, b.feeder_join)
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.walkable, b.walkable)


func test_game_create_style_routes_agree_at_the_join() -> void:
	for seed in range(1, LAST_SEED + 1, STEP):
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), _layout(seed), true)
		# [the main road, the feeder, the fork's lower lane]: the join is routes 0 and 1 as before
		assert_eq(map.routes.size(), 3)
		assert_eq(map.route_curves.size(), 3)
		var main := Route.build_from_curve(map.routes[0], map.route_curves[0])
		var second := Route.build_from_curve(map.routes[1], map.route_curves[1])
		var offset := Route.join_offset(main, second, map.feeder_length, map.join_index)
		var settle := Route.JOIN_SETTLE_CELLS
		# both routes are the same line from the join on, so a point of the main road is
		# `offset` further along the second route
		assert_almost_eq(
			second.cell_distance(map.feeder_length + settle) - offset,
			main.cell_distance(map.join_index + settle),
			0.0001
		)
		assert_eq(map.routes[1][map.feeder_length], map.path[map.join_index])
		# the second route walks the feeder's own curve, not the straight lines between cells
		var curve: RoadCurve = map.route_curves[1]
		assert_eq(
			curve.cells, map.routes[1].slice(0, map.feeder_length) + map.path.slice(map.join_index)
		)
		var middle := map.feeder_length / 2
		var walked := second.position_at(second.cell_distance(middle))
		assert_almost_eq(walked.x, curve.xs[curve.cell_points[middle]], 0.0001)
		assert_almost_eq(walked.y, curve.ys[curve.cell_points[middle]], 0.0001)


func test_a_feeder_curve_replaces_the_cell_centres_and_none_keeps_them() -> void:
	var layout := _layout(42)
	var results: Array[SectionResult] = []
	var sections := ValleyLayout.sections()
	for slot in layout.slots:
		results.append(sections[slot.id].generate(slot, layout.rng_for(slot.id, 0)))
	var fold := results[ValleyLayout.Region.ANCIENT_FOLD]
	var map := GameMap.new()
	for result in results:
		map.path.append_array(result.road)
	map.routes = [map.path]
	var route: Array[Vector2i] = []
	route.append_array(fold.feeder)
	route.append_array(map.path.slice(map.path.find(fold.feeder_join)))
	map.routes.append(route)
	map.feeder_length = fold.feeder.size()
	map.join_index = map.path.find(fold.feeder_join)
	var with_curve := ValleyStitcher._route_curves(map, results)
	assert_eq(with_curve[1].xs[0], fold.feeder_curve.xs[0])
	assert_eq(with_curve[1].xs.size() > fold.feeder_curve.xs.size(), true)
	# a section without a feeder curve gives the cell centres, as before
	fold.feeder_curve = null
	var without := ValleyStitcher._route_curves(map, results)
	assert_eq(without[1].xs[0], float(fold.feeder[0].x) + 0.5)
	assert_eq(without[1].ys[0], float(fold.feeder[0].y) + 0.5)
	assert_eq(
		without[1].xs.size(),
		fold.feeder.size() + with_curve[0].xs.size() - with_curve[0].cell_points[map.join_index]
	)


func test_the_road_is_the_composed_spine() -> void:
	# the section draws no road of its own (#434): it lays the layout's composed road
	for seed in SEEDS:
		var layout := ValleyLayout.generate(seed, 40, 24)
		var slot := layout.slots[ValleyLayout.Region.ANCIENT_FOLD]
		var result := AncientFoldRegion.new().generate(slot, layout.rng_for(slot.id, 0))
		assert_eq(result.road, RoadSpline.build(slot.spine).cells, "seed %d" % seed)
