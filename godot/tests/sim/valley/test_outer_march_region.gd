extends GutTest

const RULES := preload("res://content/map_rules.gd")
const LANE_GAP := 4.0
## Two road cells this many steps apart along the road are two stretches, not one bend.
const STRETCH_STEPS := 20
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const LAST_SEED := 300
## The S reaches at least this near the region's right edge.
const FAR_REACH := 5


func _drawn(seed: int) -> Array:
	var layout := ValleyLayout.generate(seed, 32, 20)
	var slot := layout.slots[ValleyLayout.Region.OUTER_MARCH]
	var section := OuterMarchRegion.new()
	return [layout, slot, section, section.generate(slot, layout.rng_for(slot.id, 0))]


func test_the_valley_builds_with_no_problems_for_seeds_1_to_300() -> void:
	for seed in range(1, LAST_SEED + 1):
		var layout := ValleyLayout.generate(seed, 32, 20)
		assert_not_null(layout, "seed %d" % seed)
		var map := ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout, true)
		assert_not_null(map, "seed %d" % seed)


func test_the_region_passes_its_checks_with_four_or_five_low_sockets() -> void:
	for seed in range(1, LAST_SEED + 1):
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[3]
		assert_eq(drawn[2].socket_range(), Vector2i(4, 5))
		assert_true(result.sockets.size() >= 4 and result.sockets.size() <= 5, "seed %d" % seed)
		for level in result.socket_levels:
			assert_true(level >= 0 and level <= 1, "seed %d" % seed)


func test_the_road_enters_on_the_west_edge_and_bends_smoothly_without_lanes() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var result: SectionResult = drawn[3]
		assert_eq(result.road[0].x, 0)
		assert_eq(result.road[0], drawn[1].entry)
		assert_not_null(result.road_curve)
		var road := result.road
		for a in road.size():
			for b in range(a + STRETCH_STEPS, road.size()):
				var gap := Vector2(road[a]).distance_to(Vector2(road[b]))
				assert_gte(gap, LANE_GAP, "seed %d, %s and %s" % [seed, road[a], road[b]])


func test_the_road_runs_far_across_the_region_before_it_turns_back() -> void:
	for seed in SEEDS:
		var drawn := _drawn(seed)
		var slot: ValleyPlan.Slot = drawn[1]
		var far := 0
		for step in drawn[3].road:
			far = maxi(far, step.x)
		assert_gte(far, slot.rect.end.x - FAR_REACH, "seed %d" % seed)


func test_forest_keeps_its_gap_and_the_ground_is_low_and_walkable() -> void:
	for seed in SEEDS:
		var result: SectionResult = _drawn(seed)[3]
		var forest := 0
		for y in result.rect.size.y:
			for x in result.rect.size.x:
				var cell := result.rect.position + Vector2i(x, y)
				if result.river.has(cell):
					continue
				assert_true(result.is_walkable(cell), "seed %d" % seed)
				assert_lte(result.height_at(cell), 1)
				if result.region_at(cell) == GameMap.Region.FOREST:
					forest += 1
					for step in result.road:
						assert_gte(
							maxi(absi(step.x - cell.x), absi(step.y - cell.y)),
							RULES.FOREST_ROAD_GAP
						)
		assert_gt(forest, 0, "seed %d has forest" % seed)


func test_the_same_seed_draws_the_same_region() -> void:
	for seed in SEEDS:
		var a: SectionResult = _drawn(seed)[3]
		var b: SectionResult = _drawn(seed)[3]
		assert_eq(a.road, b.road)
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.heights, b.heights)
