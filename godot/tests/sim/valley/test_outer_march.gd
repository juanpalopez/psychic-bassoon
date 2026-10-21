extends GutTest

const VALLEY := preload("res://content/valley/valley_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 60
## Most seeds pass on the first draw; the stitcher redraws the rest.
const MAX_FIRST_DRAW_FAILURES := 12


func _draw(seed: int, attempt: int = 0) -> Array:
	var slot := ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.OUTER_MARCH]
	var section := OuterMarch.new()
	return [slot, section, section.generate(slot, ValleyPlan.section_rng(seed, 0, attempt))]


func test_the_valley_builds_for_every_seed() -> void:
	for seed in range(1, SWEEP + 1):
		assert_not_null(MapGen.generate_valley(seed), "seed %d" % seed)


func test_most_seeds_pass_the_checks_on_the_first_draw() -> void:
	var failures := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _draw(seed)
		if not ValleyChecks.section_problems(drawn[0], drawn[2], drawn[1]).is_empty():
			failures += 1
	assert_lte(failures, MAX_FIRST_DRAW_FAILURES)


func test_the_road_starts_on_the_west_edge_and_sockets_are_low_and_in_range() -> void:
	for seed in SEEDS:
		var drawn := _draw(seed)
		var result: SectionResult = drawn[2]
		assert_eq(result.road[0].x, 0, "seed %d" % seed)
		assert_eq(drawn[1].socket_range(), Vector2i(3, 5))
		for level in result.socket_levels:
			assert_true(level >= 0 and level <= 1)


func test_forest_keeps_its_gap_from_the_road_and_the_ground_is_low_and_walkable() -> void:
	for seed in SEEDS:
		var result: SectionResult = _draw(seed)[2]
		var forest := 0
		for y in result.rect.size.y:
			for x in result.rect.size.x:
				var cell := result.rect.position + Vector2i(x, y)
				assert_true(result.is_walkable(cell))
				assert_lte(result.height_at(cell), 1)
				if result.region_at(cell) == GameMap.Region.FOREST:
					forest += 1
					for step in result.road:
						assert_gte(
							maxi(absi(step.x - cell.x), absi(step.y - cell.y)),
							RULES.FOREST_ROAD_GAP
						)
		assert_gt(forest, 0, "seed %d has forest" % seed)


func test_sockets_covering_a_bend_are_tagged_bend() -> void:
	for seed in SEEDS:
		var result: SectionResult = _draw(seed)[2]
		for bend in SectionSockets.bends(result.road):
			var covered := false
			for index in result.sockets.size():
				if (
					SectionSockets.centre_gap(result.sockets[index], bend)
					<= VALLEY.BEND_COVER_REACH
				):
					covered = covered or result.socket_tags[index] == SectionResult.Tag.BEND
			assert_true(covered, "seed %d bend %s" % [seed, bend])


func test_every_seed_has_a_passing_draw_within_the_attempt_budget() -> void:
	for seed in range(1, 301):
		var slot := ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.OUTER_MARCH]
		var section := OuterMarch.new()
		var passed := false
		for attempt in 20:
			var result := section.generate(slot, ValleyPlan.section_rng(seed, 0, attempt))
			if ValleyChecks.section_problems(slot, result, section).is_empty():
				passed = true
				break
		assert_true(passed, "seed %d" % seed)


## An ASCII map of one section for the PR: road #, sockets S, forest f, rise by height digits.
func test_print_the_section_for_seed_42() -> void:
	var drawn := _draw(42)
	var result: SectionResult = drawn[2]
	var lines: Array[String] = []
	for y in result.rect.size.y:
		var line := ""
		for x in result.rect.size.x:
			var cell := result.rect.position + Vector2i(x, y)
			var mark := str(result.height_at(cell))
			if result.region_at(cell) == GameMap.Region.FOREST:
				mark = "f"
			for anchor in result.sockets:
				if Rect2i(anchor, Vector2i(2, 2)).has_point(cell):
					mark = "S"
			line += "#" if result.road.has(cell) else mark
		lines.append(line)
	gut.p("\n".join(lines))
	assert_eq(lines.size(), result.rect.size.y)
