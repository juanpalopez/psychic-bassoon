extends GutTest

const LANE_GAP := 4.0
const STRETCH_STEPS := 20
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const LAST_SEED := 300
const ATTEMPTS := 20
## Most seeds pass on the first draw; the stitcher redraws the rest.
const MAX_FIRST_FAIL_PERCENT := 25


func _drawn(seed: int) -> Array:
	var layout := ValleyLayout.generate(seed, 32, 20)
	var slot := layout.slots[ValleyLayout.Region.HEARTKEEP_APPROACH]
	var section := HeartkeepApproachRegion.new()
	return [layout, slot, section, section.generate(slot, layout.rng_for(slot.id, 0))]


## Cells a hero reaches from `start` over walkable cells inside the region.
func _reach(result: SectionResult, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + step
			if result.has_cell(next) and result.is_walkable(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func test_the_valley_builds_with_no_problems_for_seeds_1_to_300() -> void:
	for seed in range(1, LAST_SEED + 1):
		var layout := ValleyLayout.generate(seed, 32, 20)
		assert_not_null(layout, "seed %d" % seed)
		var map := ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout, true)
		assert_not_null(map, "seed %d" % seed)
		if map != null:
			assert_true(map.heartstone.has_point(map.path[map.path.size() - 1]))


func test_some_attempt_of_the_budget_passes_the_section_checks_with_five_or_six_blocks() -> void:
	var first_failures := 0
	for seed in range(1, LAST_SEED + 1):
		var layout := ValleyLayout.generate(seed, 32, 20)
		var slot := layout.slots[ValleyLayout.Region.HEARTKEEP_APPROACH]
		var section := HeartkeepApproachRegion.new()
		assert_eq(section.socket_range(), Vector2i(5, 6))
		var passed := false
		for attempt in ATTEMPTS:
			var result := section.generate(slot, layout.rng_for(slot.id, attempt))
			var clean := ValleyChecks.section_problems(slot, result, section).is_empty()
			if attempt == 0 and not clean:
				first_failures += 1
			passed = passed or clean
		assert_true(passed, "seed %d has a passing draw" % seed)
	assert_lt(first_failures * 100, LAST_SEED * MAX_FIRST_FAIL_PERCENT)


func test_the_road_ends_on_the_east_edge_on_the_floor_without_lanes() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var slot: ValleyPlan.Slot = drawn[1]
		var result: SectionResult = drawn[3]
		var road := result.road
		assert_eq(road[road.size() - 1], slot.exit)
		assert_eq(slot.exit.x, 31)
		assert_not_null(result.road_curve)
		for step in road:
			assert_eq(result.height_at(step), 0)
		for a in road.size():
			for b in range(a + STRETCH_STEPS, road.size()):
				var gap := Vector2(road[a]).distance_to(Vector2(road[b]))
				assert_gte(gap, LANE_GAP, "seed %d, %s and %s" % [seed, road[a], road[b]])


func test_ground_rises_around_the_heartstone_and_the_hero_can_walk_to_it() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var slot: ValleyPlan.Slot = drawn[1]
		var result: SectionResult = drawn[3]
		var top := 0
		for y in result.rect.size.y:
			for x in result.rect.size.x:
				var cell := result.rect.position + Vector2i(x, y)
				top = maxi(top, result.height_at(cell))
		assert_gte(top, 1, "seed %d rises" % seed)
		var reached := _reach(result, slot.entry)
		for step in result.road:
			assert_true(reached.has(step), "seed %d road cell %s" % [seed, step])
		var block: Rect2i = drawn[2].reserved(slot)[0]
		for y in range(block.position.y - 1, block.end.y + 1):
			for x in range(block.position.x - 1, block.end.x + 1):
				var cell := Vector2i(x, y)
				if result.has_cell(cell):
					assert_true(reached.has(cell), "seed %d cell %s" % [seed, cell])
		for anchor in result.sockets:
			assert_false(block.intersects(Rect2i(anchor, Vector2i(2, 2))), "seed %d" % seed)


func test_the_same_seed_draws_the_same_region() -> void:
	for seed in SEEDS:
		var a: SectionResult = _drawn(seed)[3]
		var b: SectionResult = _drawn(seed)[3]
		assert_eq(a.road, b.road)
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.heights, b.heights)


func test_the_road_is_the_composed_spine() -> void:
	# the section draws no road of its own (#434): it lays the layout's composed road
	for seed in SEEDS:
		var layout := ValleyLayout.generate(seed, 32, 20)
		var slot := layout.slots[ValleyLayout.Region.HEARTKEEP_APPROACH]
		var result := HeartkeepApproachRegion.new().generate(slot, layout.rng_for(slot.id, 0))
		assert_eq(result.road, RoadSpline.build(slot.spine).cells, "seed %d" % seed)
