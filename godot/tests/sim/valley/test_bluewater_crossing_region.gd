extends GutTest

const RULES := preload("res://content/valley/bluewater_region_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const REGION := ValleyLayout.Region.BLUEWATER_CROSSING
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
const LAST_SEED := 300
const STITCH_STEP := 6

## Layouts are drawn once per seed for the whole file (each takes a moment).
static var _layouts := {}


func _layout(seed: int) -> ValleyLayout:
	if not _layouts.has(seed):
		_layouts[seed] = ValleyLayout.generate(seed, 32, 20)
	return _layouts[seed]


func _draw(layout: ValleyLayout, attempt: int = 0) -> SectionResult:
	return BluewaterCrossingRegion.new().generate(
		layout.slots[REGION], layout.rng_for(REGION, attempt)
	)


## The first attempt (as the stitcher draws them) that passes the section checks.
func _good(layout: ValleyLayout) -> SectionResult:
	var result: SectionResult = null
	for attempt in VALLEY.MAX_SECTION_ATTEMPTS:
		result = _draw(layout, attempt)
		if _problems(layout, result).is_empty():
			break
	return result


func _problems(layout: ValleyLayout, result: SectionResult) -> Array[ValleyChecks.Problem]:
	return ValleyChecks.section_problems(
		layout.slots[REGION], result, BluewaterCrossingRegion.new()
	)


func test_every_seed_has_a_passing_attempt_and_most_pass_the_first() -> void:
	var failed := 0
	for seed in range(1, LAST_SEED + 1):
		var layout := _layout(seed)
		assert_not_null(layout, "seed %d" % seed)
		if layout == null:
			continue
		assert_eq(_problems(layout, _good(layout)).size(), 0, "seed %d" % seed)
		failed += 0 if _problems(layout, _draw(layout)).is_empty() else 1
	assert_lt(failed, LAST_SEED / 4, "first-attempt failures")


func test_the_valley_stitches_with_no_problems() -> void:
	for seed in range(1, LAST_SEED + 1, STITCH_STEP):
		var layout := _layout(seed)
		var map := ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout)
		assert_not_null(map, "seed %d" % seed)


func test_the_road_crosses_the_river_once_on_a_road_bridge_with_straight_approaches() -> void:
	for seed in range(1, LAST_SEED + 1):
		var result := _good(_layout(seed))
		var wet: Array[Vector2i] = []
		for cell in result.road:
			if result.river.has(cell):
				wet.append(cell)
		assert_gte(wet.size(), 1, "seed %d" % seed)
		assert_eq(result.bridges.size(), wet.size(), "seed %d: a bridge per wet cell" % seed)
		var first := result.road.find(wet[0])
		var last := result.road.find(wet[wet.size() - 1])
		assert_eq(last - first, wet.size() - 1, "seed %d: one wet stretch" % seed)
		for bridge in result.bridges:
			assert_true(bridge.horizontal, "seed %d" % seed)
			assert_true(wet.has(bridge.cell))
		for step in range(1, RULES.APPROACH_STRAIGHT + 1):
			assert_eq(result.road[first - step], wet[0] + Vector2i.LEFT * step, "seed %d" % seed)
			assert_eq(result.road[last + step], wet[-1] + Vector2i.RIGHT * step, "seed %d" % seed)


func test_the_hero_bridge_is_a_second_walkable_crossing_off_the_road() -> void:
	for seed in range(1, LAST_SEED + 1):
		var result := _good(_layout(seed))
		var bridge_row: int = result.bridges[0].cell.y
		assert_gte(result.hero_bridges.size(), 2, "seed %d: two cells wide" % seed)
		for cell in result.hero_bridges:
			assert_true(result.river.has(cell))
			assert_false(result.road.has(cell))
			assert_true(result.is_walkable(cell))
			assert_gte(absi(cell.y - bridge_row), RULES.HERO_BRIDGE_MIN_ROW_GAP, "seed %d" % seed)


func test_river_cells_are_unwalkable_except_bridges_and_no_socket_touches_them() -> void:
	for seed in SEEDS:
		var result := _good(_layout(seed))
		var open: Array[Vector2i] = result.hero_bridges.duplicate()
		for bridge in result.bridges:
			open.append(bridge.cell)
		for cell in result.river:
			assert_eq(result.is_walkable(cell), open.has(cell), "seed %d at %s" % [seed, cell])
		for anchor in result.sockets:
			for dy in 2:
				for dx in 2:
					assert_false(result.river.has(anchor + Vector2i(dx, dy)), "seed %d" % seed)


func test_sockets_sit_on_both_banks_where_the_west_bank_has_room() -> void:
	var both := 0
	for seed in range(1, 61):
		var result := _good(_layout(seed))
		assert_between(result.sockets.size(), 4, 5, "seed %d" % seed)
		var bridge: Vector2i = result.bridges[0].cell
		var west := result.sockets.any(func(anchor: Vector2i) -> bool: return anchor.x < bridge.x)
		var east := result.sockets.any(func(anchor: Vector2i) -> bool: return anchor.x > bridge.x)
		assert_true(east, "seed %d east bank" % seed)
		both += 1 if west else 0
	assert_gt(both, 48, "seeds with a west-bank block out of 60")


func test_the_same_seed_draws_the_same_crossing() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		var a := _draw(layout, 1)
		var b := _draw(layout, 1)
		assert_eq(a.road, b.road)
		assert_eq(a.sockets, b.sockets)
		assert_eq(a.hero_bridges, b.hero_bridges)
