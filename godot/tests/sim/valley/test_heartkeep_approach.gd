extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 60
const MAX_FIRST_DRAW_FAILURES := 12


func _draw(seed: int) -> Array:
	var slot := ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.HEARTKEEP_APPROACH]
	var section := HeartkeepApproach.new()
	return [slot, section, section.generate(slot, ValleyPlan.section_rng(seed, 5, 0))]


## Cells a hero reaches from `start` over walkable cells inside the strip.
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


func test_the_valley_builds_for_every_seed_and_ends_at_the_heartstone() -> void:
	for seed in range(1, SWEEP + 1):
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		if map != null:
			assert_eq(map.path[map.path.size() - 1].x, 31)
			assert_true(map.heartstone.has_point(map.path[map.path.size() - 1]))


func test_most_seeds_pass_the_checks_on_the_first_draw() -> void:
	var failures := 0
	for seed in range(1, SWEEP + 1):
		var drawn := _draw(seed)
		if not ValleyChecks.section_problems(drawn[0], drawn[2], drawn[1]).is_empty():
			failures += 1
	assert_lte(failures, MAX_FIRST_DRAW_FAILURES)


func test_the_road_ends_on_the_east_edge_with_dense_sockets_on_the_floor() -> void:
	for seed in SEEDS:
		var drawn := _draw(seed)
		var slot: ValleyPlan.Slot = drawn[0]
		var result: SectionResult = drawn[2]
		assert_eq(drawn[1].socket_range(), Vector2i(2, 6))
		assert_eq(result.road[result.road.size() - 1], slot.exit)
		assert_eq(slot.exit.x, 31)
		for step in result.road:
			assert_eq(result.height_at(step), 0)


func test_the_heartstone_block_keeps_clear_of_sockets_and_river() -> void:
	for seed in SEEDS:
		var drawn := _draw(seed)
		var slot: ValleyPlan.Slot = drawn[0]
		var result: SectionResult = drawn[2]
		var block: Rect2i = drawn[1].reserved(slot)[0]
		assert_eq(block, MapGen._heartstone_block(slot.exit, 32, 20, 2))
		assert_true(block.has_point(slot.exit))
		for anchor in result.sockets:
			assert_false(block.intersects(Rect2i(anchor, Vector2i(2, 2))), "seed %d" % seed)
		for cell in result.river:
			assert_false(block.has_point(cell))


func test_ground_rises_around_the_heartstone_and_the_hero_can_walk_to_it() -> void:
	for seed in SEEDS:
		var drawn := _draw(seed)
		var slot: ValleyPlan.Slot = drawn[0]
		var result: SectionResult = drawn[2]
		var top := 0
		for y in result.rect.size.y:
			for x in result.rect.size.x:
				var cell := result.rect.position + Vector2i(x, y)
				top = maxi(top, result.height_at(cell))
				for step in [Vector2i.RIGHT, Vector2i.DOWN]:
					if result.has_cell(cell + step):
						assert_lte(absi(result.height_at(cell) - result.height_at(cell + step)), 1)
		assert_gte(top, 1, "seed %d rises" % seed)
		var reached := _reach(result, slot.entry)
		for step in result.road:
			assert_true(reached.has(step), "seed %d road cell %s" % [seed, step])
		var block: Rect2i = drawn[1].reserved(slot)[0]
		for y in range(block.position.y - 1, block.end.y + 1):
			for x in range(block.position.x - 1, block.end.x + 1):
				var cell := Vector2i(x, y)
				if result.has_cell(cell):
					assert_true(result.is_walkable(cell) and reached.has(cell))


func test_every_seed_has_a_passing_draw_within_the_attempt_budget() -> void:
	for seed in range(1, 301):
		var slot := ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.HEARTKEEP_APPROACH]
		var section := HeartkeepApproach.new()
		var passed := false
		for attempt in 20:
			var result := section.generate(slot, ValleyPlan.section_rng(seed, 5, attempt))
			if ValleyChecks.section_problems(slot, result, section).is_empty():
				passed = true
				break
		assert_true(passed, "seed %d" % seed)
