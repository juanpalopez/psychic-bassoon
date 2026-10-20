extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]


func _stub_valley(seed: int) -> Array[SectionResult]:
	var plan := ValleyPlan.create(seed, 32, 20)
	var sections := ValleySections.all()
	var results: Array[SectionResult] = []
	for slot in plan.slots:
		results.append(sections[slot.id].generate(slot, ValleyPlan.section_rng(seed, slot.id, 0)))
	return results


func _wall(result: SectionResult, x: int) -> void:
	for y in range(result.rect.position.y, result.rect.end.y):
		result.set_walkable(Vector2i(x, y), false)


func test_an_open_valley_has_no_hero_problems() -> void:
	for seed in SEEDS:
		assert_eq(HeroGraph.problems(_stub_valley(seed)).size(), 0, "seed %d" % seed)


func test_a_wall_across_a_strip_fails_and_names_the_strip_past_it() -> void:
	var results := _stub_valley(42)
	var strip := results[ValleyPlan.Id.BLUEWATER_CROSSING]
	_wall(strip, strip.rect.position.x + 1)
	var problems := HeroGraph.problems(results)
	assert_gt(problems.size(), 0)
	assert_eq(problems[0].section, ValleyPlan.Id.BLUEWATER_CROSSING)


func test_a_wall_across_the_meadow_fails() -> void:
	var results := _stub_valley(2026)
	var meadow := results[ValleyPlan.Id.SUNKEN_MEADOW]
	_wall(meadow, meadow.rect.position.x + 1)
	assert_gt(HeroGraph.problems(results).size(), 0)


func test_the_valley_checks_run_the_hero_graph() -> void:
	var results := _stub_valley(42)
	var strip := results[ValleyPlan.Id.BROKEN_RIDGE]
	_wall(strip, strip.rect.position.x + 1)
	assert_gt(ValleyChecks.valley_problems(results).size(), 0)


func test_unwalkable_cells_that_do_not_cut_the_graph_pass() -> void:
	var results := _stub_valley(42)
	var meadow := results[ValleyPlan.Id.SUNKEN_MEADOW]
	meadow.set_walkable(meadow.rect.position + Vector2i(1, 1), false)
	assert_eq(HeroGraph.problems(results).size(), 0)


func test_travel_steps_counts_steps_and_reports_cut_off_cells() -> void:
	var results := _stub_valley(42)
	var from := results[0].road[0]
	assert_eq(HeroGraph.travel_steps(results, from, from), 0)
	assert_eq(HeroGraph.travel_steps(results, from, from + Vector2i(3, 0)), 3)
	var strip := results[1]
	_wall(strip, strip.rect.position.x + 1)
	assert_eq(HeroGraph.travel_steps(results, from, results[5].road[0]), -1)


func test_a_bridge_cell_stays_walkable() -> void:
	var results := _stub_valley(42)
	var strip := results[ValleyPlan.Id.BLUEWATER_CROSSING]
	var cell := strip.rect.position + Vector2i(1, 5)
	strip.set_walkable(cell, false)
	var bridge := GameMap.Bridge.new()
	bridge.cell = cell
	strip.bridges.append(bridge)
	assert_ne(HeroGraph.travel_steps(results, cell + Vector2i.LEFT, cell + Vector2i.RIGHT), -1)
