extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 60
const ID := ValleyPlan.Id.BROKEN_RIDGE


func _draw(seed: int, attempt: int = 0) -> Array:
	var plan := ValleyPlan.create(seed, 32, 20)
	var slot := plan.slots[ID]
	var section := BrokenRidge.new()
	return [slot, section, section.generate(slot, ValleyPlan.section_rng(seed, ID, attempt))]


func test_the_ridge_passes_its_checks_on_the_first_attempt_for_most_seeds() -> void:
	var failed := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _draw(seed)
		if not ValleyChecks.section_problems(drawn[0], drawn[2], drawn[1]).is_empty():
			failed += 1
	assert_lte(failed, SWEEP / 10, "%d of %d first attempts failed" % [failed, SWEEP])


func test_three_or_four_blocks_and_exactly_one_on_the_ridge() -> void:
	for seed in SEEDS:
		var result: SectionResult = _draw(seed)[2]
		assert_between(result.sockets.size(), 3, 4, "seed %d" % seed)
		assert_lte(result.socket_tags.count(SectionResult.Tag.HIGH), 1)
		for index in result.sockets.size():
			var high: bool = result.socket_tags[index] == SectionResult.Tag.HIGH
			assert_eq(result.socket_levels[index], 2 if high else 0)


func test_the_ridge_block_is_level_two_and_the_road_stays_on_the_floor() -> void:
	for seed in SEEDS:
		var result: SectionResult = _draw(seed)[2]
		for cell in result.road:
			assert_eq(result.height_at(cell), 0)
		var index := result.socket_tags.find(SectionResult.Tag.HIGH)
		assert_gt(index, -1, "seed %d has a ridge block" % seed)
		var anchor := result.sockets[index]
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			assert_eq(result.height_at(anchor + d), 2)


func test_cliffs_are_blocked_rock_that_never_touch_the_road() -> void:
	var seen := 0
	for seed in range(1, SWEEP + 1):
		var result: SectionResult = _draw(seed)[2]
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				if result.region_at(cell) != GameMap.Region.ROCKS:
					continue
				seen += 1
				assert_false(result.is_walkable(cell))
				for road_cell in result.road:
					var gap := maxi(absi(road_cell.x - x), absi(road_cell.y - y))
					assert_gt(gap, 1, "seed %d cliff %s beside the road" % [seed, cell])
	assert_gt(seen, 0, "the ridge has cliffs")


func test_a_ramp_leads_from_the_road_onto_the_ridge() -> void:
	for seed in SEEDS:
		var drawn := _draw(seed)
		var section: BrokenRidge = drawn[1]
		assert_eq(section.extra_problems(drawn[0], drawn[2]), [] as Array[String], "seed %d" % seed)


func test_a_ridge_with_its_ramp_walled_off_is_a_problem() -> void:
	var drawn := _draw(42)
	var result: SectionResult = drawn[2]
	var anchor := result.sockets[result.socket_tags.find(SectionResult.Tag.HIGH)]
	for y in range(anchor.y - 1, anchor.y + 3):
		for x in range(anchor.x - 1, anchor.x + 3):
			var cell := Vector2i(x, y)
			if result.has_cell(cell) and not result.road.has(cell):
				result.set_walkable(cell, false)
	var section: BrokenRidge = drawn[1]
	assert_false(section.extra_problems(drawn[0], result).is_empty())


func test_the_stitched_valley_never_fails_and_ridge_blocks_get_the_range_bonus() -> void:
	for seed in range(1, SWEEP + 1):
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		if map == null:
			continue
		var plan := ValleyPlan.create(seed, 32, 20)
		var strip := plan.slots[ID].rect
		var raised := 0
		for anchor in map.sockets:
			if strip.has_point(anchor) and map.elevation_at(anchor) == 2:
				raised += 1
				assert_eq(map.range_multiplier(anchor), 1.15)
		assert_eq(raised, 1, "seed %d" % seed)
