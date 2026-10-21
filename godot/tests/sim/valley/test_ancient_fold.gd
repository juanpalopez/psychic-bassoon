extends GutTest

const FOLD := preload("res://content/valley/ancient_fold_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const SWEEP := 60


func _draw(seed: int, attempt: int = 0) -> SectionResult:
	var plan := ValleyPlan.create(seed, 32, 20)
	var slot := plan.slots[ValleyPlan.Id.ANCIENT_FOLD]
	var rng := ValleyPlan.section_rng(seed, slot.id, attempt)
	return AncientFold.new().generate(slot, rng)


func _slot(seed: int) -> ValleyPlan.Slot:
	return ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.ANCIENT_FOLD]


func test_most_seeds_pass_every_check_on_the_first_attempt() -> void:
	var passed := 0
	for seed in range(1, SWEEP + 1):
		var slot := _slot(seed)
		var section := AncientFold.new()
		var result := _draw(seed)
		var problems := ValleyChecks.section_problems(slot, result, section)
		passed += 1 if problems.is_empty() else 0
	assert_gte(passed, SWEEP * 3 / 4, "%d of %d first draws pass" % [passed, SWEEP])


func test_some_attempt_passes_every_check_for_every_seed() -> void:
	for seed in range(1, SWEEP + 1):
		var slot := _slot(seed)
		var ok := false
		for attempt in 20:
			var problems := ValleyChecks.section_problems(
				slot, _draw(seed, attempt), AncientFold.new()
			)
			if problems.is_empty():
				ok = true
				break
		assert_true(ok, "seed %d" % seed)


func test_the_feeder_runs_straight_from_the_edge_to_beside_the_join() -> void:
	for seed in range(1, SWEEP + 1):
		var slot := _slot(seed)
		var result := _draw(seed)
		if not ValleyChecks.section_problems(slot, result, AncientFold.new()).is_empty():
			continue
		assert_gte(result.feeder.size(), RULES.FEEDER_MIN_CELLS)
		var edge := result.feeder[0].y
		assert_true(edge == 0 or edge == 19, "seed %d starts on row %d" % [seed, edge])
		var end := result.feeder[result.feeder.size() - 1]
		assert_eq(absi(end.x - result.feeder_join.x) + absi(end.y - result.feeder_join.y), 1)
		assert_true(result.road.has(result.feeder_join))
		for cell in result.feeder:
			assert_true(slot.rect.has_point(cell))
			assert_false(result.road.has(cell))
			for road_cell in result.road:
				var gap := absi(cell.x - road_cell.x) + absi(cell.y - road_cell.y)
				assert_true(road_cell == result.feeder_join or gap >= RULES.FEEDER_CLEARANCE)


func test_enough_socket_blocks_cover_the_join() -> void:
	for seed in range(1, SWEEP + 1):
		var result := _draw(seed)
		if not ValleyChecks.section_problems(_slot(seed), result, AncientFold.new()).is_empty():
			continue
		var near := 0
		for anchor in result.sockets:
			if SectionSockets.centre_gap(anchor, result.feeder_join) <= FOLD.MERGE_COVER_REACH:
				near += 1
		assert_gte(near, FOLD.MERGE_COVER_MIN, "seed %d" % seed)
		assert_gte(result.socket_tags.count(SectionResult.Tag.MERGE), 1)


func test_ruins_are_solid_blocks_away_from_the_roads_and_the_join() -> void:
	var ruins := 0
	for seed in range(1, SWEEP + 1):
		var result := _draw(seed)
		if not ValleyChecks.section_problems(_slot(seed), result, AncientFold.new()).is_empty():
			continue
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				if result.is_walkable(cell):
					continue
				ruins += 1
				assert_eq(result.region_at(cell), GameMap.Region.ROCKS)
				assert_false(result.road.has(cell) or result.feeder.has(cell))
				var gap := absi(x - result.feeder_join.x) + absi(y - result.feeder_join.y)
				assert_gte(gap, FOLD.RUIN_JOIN_GAP)
	assert_gt(ruins, 0, "some seed has ruins")


func test_the_generator_is_reproducible() -> void:
	for seed in SEEDS:
		var a := _draw(seed)
		var b := _draw(seed)
		assert_eq(a.road, b.road)
		assert_eq(a.feeder, b.feeder)
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.walkable, b.walkable)


func test_the_valley_has_a_second_route_that_joins_the_main_road() -> void:
	for seed in range(1, SWEEP + 1):
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		if map == null:
			continue
		assert_eq(map.routes.size(), 2)
		var join := map.path[map.join_index]
		assert_gt(map.feeder_length, 0)
		assert_eq(map.path.find(join), map.join_index)
		var second: Array[Vector2i] = map.routes[1]
		assert_eq(second.size(), map.feeder_length + map.path.size() - map.join_index)
		assert_eq(second[map.feeder_length], join)
		assert_eq(second.slice(map.feeder_length), map.path.slice(map.join_index))
		for index in map.feeder_length:
			var cell := second[index]
			assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD)
			assert_false(map.path.has(cell))
		var edge := second[0].y
		assert_true(edge == 0 or edge == map.rows - 1)
		assert_lt(map.join_index, map.path.size() - 1 - RULES.FEEDER_MIN_CELLS)


func test_game_create_style_routes_agree_at_the_join() -> void:
	for seed in SEEDS:
		var map := MapGen.generate_valley(seed)
		var main := Route.build_curved(map.routes[0])
		var second := Route.build_curved(map.routes[1])
		var offset := Route.join_offset(main, second, map.feeder_length, map.join_index)
		# a foe from the feeder is `offset` further along than the main road's foe at the join
		# (the feeder is shorter than the road before the join, so the offset is negative)
		assert_lt(offset, 0.0, "seed %d" % seed)
		var settle := Route.JOIN_SETTLE_CELLS
		var at_main := main.cell_distance(map.join_index + settle)
		var at_second := second.cell_distance(map.feeder_length + settle)
		assert_almost_eq(at_second - offset, at_main, 0.0001)
		assert_lt(second.total, main.total + absf(offset) + 1.0)


func test_ruin_cells_never_block_the_walk_along_either_route() -> void:
	for seed in range(1, SWEEP + 1):
		var map := MapGen.generate_valley(seed)
		for route in map.routes:
			for cell in route:
				assert_true(map.is_walkable(cell), "seed %d cell %s" % [seed, cell])


func test_every_seed_up_to_300_makes_a_valley() -> void:
	for seed in range(1, 301):
		assert_not_null(MapGen.generate_valley(seed), "seed %d" % seed)
