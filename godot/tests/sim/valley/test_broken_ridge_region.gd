extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 300
const STITCH_STEP := 6
const ID := ValleyLayout.Region.BROKEN_RIDGE

var _layouts := {}


func _layout(seed: int) -> ValleyLayout:
	if not _layouts.has(seed):
		_layouts[seed] = ValleyLayout.generate(seed, 40, 24)
	return _layouts[seed]


func _drawn(seed: int) -> Array:
	var layout := _layout(seed)
	var section := BrokenRidgeRegion.new()
	var result := section.generate(layout.slots[ID], layout.rng_for(ID, 0))
	return [layout, section, result]


func test_a_high_block_on_the_plateau_and_the_rest_low() -> void:
	var failed := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		if not ValleyChecks.section_problems(drawn[0].slots[ID], result, drawn[1]).is_empty():
			failed += 1
			continue
		assert_between(result.sockets.size(), 2, 4, "seed %d" % seed)
		assert_eq(result.socket_tags.count(SectionResult.Tag.HIGH), 1, "seed %d" % seed)
		for index in result.sockets.size():
			var high: bool = result.socket_tags[index] == SectionResult.Tag.HIGH
			assert_eq(result.socket_levels[index], 2 if high else 0)
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				assert_eq(result.height_at(result.sockets[index] + d), result.socket_levels[index])
	assert_lte(failed, SWEEP / 10, "%d of %d first attempts failed" % [failed, SWEEP])


func test_the_road_is_the_spline_of_the_spine_on_the_floor() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		var slot: ValleyPlan.Slot = drawn[0].slots[ID]
		assert_eq(result.road, RoadSpline.build(slot.spine).cells, "seed %d" % seed)
		assert_not_null(result.road_curve)
		for cell in result.road:
			assert_eq(result.height_at(cell), 0)


func test_the_high_block_has_a_range_bonus_and_a_low_block_within_reach() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		var best := 1.0
		var high := Vector2i.ZERO
		for anchor in map.sockets:
			if map.range_multiplier(anchor) > best:
				best = map.range_multiplier(anchor)
				high = anchor
		assert_almost_eq(best, 1.15, 0.0001, "seed %d has a level 2 socket" % seed)
		var near := false
		for anchor in map.sockets:
			near = (
				near
				or (
					map.range_multiplier(anchor) == 1.0
					and Vector2(high).distance_to(Vector2(anchor)) <= 6.0
				)
			)
		assert_true(near, "seed %d" % seed)


func test_cliffs_are_blocked_rock_clear_of_the_road_and_the_river_is_shut() -> void:
	var cliffs := 0
	for seed in range(1, SWEEP + 1, 3):
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[2]
		for cell in drawn[0].slots[ID].river:
			assert_false(result.is_walkable(cell))
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				if result.region_at(cell) != GameMap.Region.ROCKS:
					continue
				cliffs += 1
				assert_false(result.is_walkable(cell))
				for road_cell in result.road:
					assert_gt(maxi(absi(road_cell.x - x), absi(road_cell.y - y)), 1)
	assert_gt(cliffs, 0)


func test_a_ramp_climbs_through_heights_zero_one_two() -> void:
	for seed in SEEDS:
		var result: SectionResult = _drawn(seed)[2]
		var seen := {}
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				if result.is_walkable(Vector2i(x, y)):
					seen[result.height_at(Vector2i(x, y))] = true
		for level in 3:
			assert_true(seen.has(level), "seed %d walks on terrace %d" % [seed, level])


func test_every_seed_stitches_a_valley_with_no_problems() -> void:
	for seed in range(1, SWEEP + 1, STITCH_STEP):
		var layout := _layout(seed)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		assert_not_null(map, "seed %d stitches" % seed)


func test_the_same_seed_draws_the_same_ridge() -> void:
	for seed in SEEDS:
		var a: SectionResult = _drawn(seed)[2]
		var b: SectionResult = _drawn(seed)[2]
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.heights, b.heights)
		assert_eq(a.walkable, b.walkable)
		assert_eq(a.road, b.road)
