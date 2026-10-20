extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const RULES_ATTEMPTS := 20
const ID := ValleyPlan.Id.SUNKEN_MEADOW


func _draw(seed: int, attempt: int = 0) -> SectionResult:
	var slot := ValleyPlan.create(seed, 32, 20).slots[ID]
	return SunkenMeadow.new().generate(slot, ValleyPlan.section_rng(seed, ID, attempt))


func _problems(seed: int, attempt: int = 0) -> Array[ValleyChecks.Problem]:
	var slot := ValleyPlan.create(seed, 32, 20).slots[ID]
	return ValleyChecks.section_problems(slot, _draw(seed, attempt), SunkenMeadow.new())


## The first attempt (as the stitcher draws them) that passes the section checks, or -1.
func _first_good(seed: int) -> int:
	for attempt in RULES_ATTEMPTS:
		if _problems(seed, attempt).is_empty():
			return attempt
	return -1


func test_the_meadow_has_four_or_five_sockets_and_is_flat_open_ground() -> void:
	for seed in range(1, 61):
		var result := _draw(seed, _first_good(seed))
		assert_between(result.sockets.size(), 4, 5, "seed %d" % seed)
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				assert_true(result.is_walkable(cell))
				assert_between(result.height_at(cell), 0, 1)
				var region := result.region_at(cell)
				assert_true(region == GameMap.Region.MEADOW or region == GameMap.Region.DIRT)
		assert_eq(result.river.size(), 0)


func test_the_road_wanders_with_bends() -> void:
	for seed in SEEDS:
		assert_gte(SectionSockets.bends(_draw(seed).road).size(), 2, "seed %d" % seed)


func test_every_seed_has_a_passing_attempt_within_the_budget() -> void:
	for seed in range(1, 61):
		assert_ne(_first_good(seed), -1, "seed %d" % seed)


func test_the_meadow_passes_its_checks_for_most_seeds_on_the_first_attempt() -> void:
	var failed := 0
	for seed in range(1, 61):
		failed += 1 if _problems(seed).size() > 0 else 0
	assert_lt(failed, 8, "first-attempt failures out of 60")


func test_a_meadow_with_too_little_open_ground_fails() -> void:
	var slot := ValleyPlan.create(42, 32, 20).slots[ID]
	var result := _draw(42)
	for y in range(slot.rect.position.y, slot.rect.end.y):
		for x in range(slot.rect.position.x, slot.rect.end.x):
			var cell := Vector2i(x, y)
			if not result.road.has(cell) and (x + y) % 2 == 0:
				result.set_walkable(cell, false)
	assert_gt(SunkenMeadow.new().extra_problems(slot, result).size(), 0)


func test_the_valley_builds_for_every_seed() -> void:
	for seed in range(1, 61):
		assert_not_null(MapGen.generate_valley(seed), "seed %d" % seed)
