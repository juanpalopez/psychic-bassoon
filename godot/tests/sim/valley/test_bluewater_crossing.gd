extends GutTest

const RIVER_RULES := preload("res://content/valley/bluewater_rules.gd")
const VALLEY_RULES := preload("res://content/valley/valley_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]

var _section := BluewaterCrossing.new()


func _slot(seed: int) -> ValleyPlan.Slot:
	return ValleyPlan.create(seed, 32, 20).slots[ValleyPlan.Id.BLUEWATER_CROSSING]


func _draw(seed: int, attempt: int = 0) -> SectionResult:
	var slot := _slot(seed)
	var rng := ValleyPlan.section_rng(seed, slot.id, attempt)
	return _section.generate(slot, rng)


func test_the_river_runs_unbroken_from_the_top_edge_to_the_bottom_edge() -> void:
	for seed in range(1, 61):
		var result := _draw(seed)
		var river := result.river
		assert_eq(river[0].y, 0, "seed %d top" % seed)
		assert_eq(river[river.size() - 1].y, 19, "seed %d bottom" % seed)
		for index in river.size() - 1:
			var step := river[index + 1] - river[index]
			assert_true(step == Vector2i.DOWN or step == Vector2i.LEFT or step == Vector2i.RIGHT)
		for cell in river:
			assert_eq(result.height_at(cell), 0)
			assert_eq(result.region_at(cell), GameMap.Region.MEADOW)
			var inner := cell.x >= result.rect.position.x + RIVER_RULES.RIVER_LEFT_OFFSET
			assert_true(inner and cell.x < result.rect.end.x - RIVER_RULES.RIVER_RIGHT_OFFSET)


func test_the_road_crosses_once_head_on_and_the_hero_has_a_second_bridge() -> void:
	for seed in range(1, 61):
		var result := _draw(seed)
		assert_eq(result.bridges.size(), 1, "seed %d" % seed)
		var bridge := result.bridges[0]
		assert_true(bridge.horizontal)
		assert_true(result.is_walkable(bridge.cell))
		var at := result.road.find(bridge.cell)
		assert_gt(at, 0)
		assert_eq(result.road[at - 1], bridge.cell + Vector2i.LEFT)
		assert_eq(result.road[at + 1], bridge.cell + Vector2i.RIGHT)
		var crossings := 0
		for cell in result.road:
			if result.river.has(cell):
				crossings += 1
		assert_eq(crossings, 1, "seed %d road touches the river once" % seed)
		assert_eq(result.hero_bridges.size(), 1)
		var hero := result.hero_bridges[0]
		assert_true(result.river.has(hero))
		assert_true(result.is_walkable(hero))
		assert_false(result.road.has(hero))
		assert_gte(absi(hero.y - bridge.cell.y), RIVER_RULES.HERO_BRIDGE_MIN_ROW_GAP)
		for cell in result.river:
			if cell != hero and cell != bridge.cell:
				assert_false(result.is_walkable(cell), "seed %d water %s" % [seed, cell])


func test_sockets_keep_off_the_river_and_the_hero_bridge_approach() -> void:
	for seed in range(1, 61):
		var result := _draw(seed)
		var hero := result.hero_bridges[0]
		var range := _section.socket_range()
		assert_eq(range, Vector2i(4, 5))
		for anchor in result.sockets:
			var block := Rect2i(anchor, Vector2i(2, 2))
			for cell in result.river:
				assert_false(block.has_point(cell), "seed %d socket on river" % seed)
			for dx in range(-2, 3):
				assert_false(block.has_point(hero + Vector2i(dx, 0)), "seed %d walls hero" % seed)


func test_the_section_passes_its_checks_within_the_attempts_and_mostly_at_the_first() -> void:
	var first_pass := 0
	for seed in range(1, 61):
		var passed_at := -1
		for attempt in VALLEY_RULES.MAX_SECTION_ATTEMPTS:
			var tried := _draw(seed, attempt)
			if ValleyChecks.section_problems(_slot(seed), tried, _section).is_empty():
				passed_at = attempt
				break
		assert_gte(passed_at, 0, "seed %d never passes" % seed)
		if passed_at == 0:
			first_pass += 1
	assert_gte(first_pass, 30)


func test_the_stitched_valley_has_the_bridge_on_the_road_and_the_hero_bridge() -> void:
	for seed in range(1, 61):
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		var slot := _slot(seed)
		var bridges: Array[GameMap.Bridge] = []
		for bridge in map.bridges:
			if slot.rect.has_point(bridge.cell):
				bridges.append(bridge)
		assert_eq(bridges.size(), 1)
		assert_eq(map.path[bridges[0].path_index], bridges[0].cell)
		var heroes := 0
		for cell in map.hero_bridges:
			if slot.rect.has_point(cell):
				heroes += 1
				assert_true(map.is_walkable(cell))
				assert_false(map.path.has(cell))
		assert_eq(heroes, 1)
		assert_gt(Route.build_curved(map.path).cell_distance(map.path.size() - 1), 1.0)


func test_a_seed_gives_the_same_section_twice() -> void:
	for seed in SEEDS:
		assert_eq(_draw(seed).road, _draw(seed).road)
		assert_eq(_draw(seed).river, _draw(seed).river)


func test_every_seed_stitches_and_foes_cross_the_river_on_the_bridge_only() -> void:
	# The stitcher assembles a map only when `ValleyChecks.all_problems` (the section checks and
	# `valley_problems`) finds none, so a non-null map means the stitched results pass them.
	for seed in range(1, 301):
		var map := MapGen.generate_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		if map == null:
			continue
		var slot := _slot(seed)
		var bridge := map.bridges[0]
		for bridge_found in map.bridges:
			if slot.rect.has_point(bridge_found.cell):
				bridge = bridge_found
		var hero := Vector2i(-1, -1)
		for cell in map.hero_bridges:
			if slot.rect.has_point(cell):
				hero = cell
		for route in map.routes:
			for cell in route:
				assert_false(cell == hero, "seed %d hero bridge on a route" % seed)
				if slot.rect.has_point(cell) and not map.is_walkable(cell):
					fail_test("seed %d route on water %s" % [seed, cell])
		assert_true(map.path.has(bridge.cell))
