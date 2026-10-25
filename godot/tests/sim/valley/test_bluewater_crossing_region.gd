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
		_layouts[seed] = ValleyLayout.generate(seed, 40, 24)
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
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		assert_not_null(map, "seed %d" % seed)


func test_the_road_crosses_the_river_once_on_a_road_bridge_with_straight_approaches() -> void:
	for seed in range(1, LAST_SEED + 1):
		var result := _good(_layout(seed))
		var wet: Array[Vector2i] = []
		for cell in result.road:
			if result.river.has(cell):
				wet.append(cell)
		assert_gte(wet.size(), 1, "seed %d" % seed)
		var on_road := result.bridges.filter(
			func(b: GameMap.Bridge) -> bool: return not b.on_branch
		)
		assert_eq(on_road.size(), wet.size(), "seed %d: a bridge per wet cell" % seed)
		var first := result.road.find(wet[0])
		var last := result.road.find(wet[wet.size() - 1])
		assert_eq(last - first, wet.size() - 1, "seed %d: one wet stretch" % seed)
		for bridge in on_road:
			assert_true(bridge.horizontal, "seed %d" % seed)
			assert_true(wet.has(bridge.cell))
		for step in range(1, RULES.APPROACH_STRAIGHT + 1):
			assert_eq(result.road[first - step], wet[0] + Vector2i.LEFT * step, "seed %d" % seed)
			assert_eq(result.road[last + step], wet[-1] + Vector2i.RIGHT * step, "seed %d" % seed)


func test_a_forked_crossing_has_two_road_bridges_and_no_hero_bridge() -> void:
	for seed in range(1, LAST_SEED + 1):
		var layout := _layout(seed)
		var result := _good(layout)
		assert_true(layout.slots[REGION].has_branch(), "seed %d is forked" % seed)
		assert_true(result.hero_bridges.is_empty(), "seed %d: no hero-only bridge" % seed)
		var upper := result.bridges.filter(func(b: GameMap.Bridge) -> bool: return not b.on_branch)
		var lower := result.bridges.filter(func(b: GameMap.Bridge) -> bool: return b.on_branch)
		assert_false(upper.is_empty(), "seed %d: the upper lane's bridge" % seed)
		assert_false(lower.is_empty(), "seed %d: the lower lane's bridge" % seed)
		assert_eq(upper.size() + lower.size(), result.bridges.size())
		for bridge in upper:
			assert_true(result.road.has(bridge.cell), "seed %d" % seed)
		for bridge in lower:
			assert_true(result.branch.has(bridge.cell), "seed %d" % seed)
			assert_true(result.is_walkable(bridge.cell))
		assert_gte(
			absi(lower[0].cell.y - upper[0].cell.y), RULES.HERO_BRIDGE_MIN_ROW_GAP, "seed %d" % seed
		)


func test_the_stitched_forked_valley_has_bridges_on_route_0_and_2_and_no_hero_bridge() -> void:
	for seed in range(1, LAST_SEED + 1, STITCH_STEP):
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), _layout(seed))
		assert_not_null(map, "seed %d" % seed)
		assert_true(map.hero_bridges.is_empty(), "seed %d" % seed)
		var routes := {}
		for bridge in map.bridges:
			routes[bridge.route] = true
		assert_eq(routes.keys(), [0, 2], "seed %d: the bridge routes" % seed)


func test_an_unforked_crossing_keeps_its_hero_bridge() -> void:
	for seed in SEEDS:
		var layout := ValleyLayout.generate(seed, 40, 24, false)
		assert_not_null(layout, "seed %d" % seed)
		var slot := layout.slots[REGION]
		assert_false(slot.has_branch())
		var result := BluewaterCrossingRegion.new().generate(slot, layout.rng_for(REGION, 0))
		assert_gte(result.hero_bridges.size(), 2, "seed %d: two cells wide" % seed)
		for cell in result.hero_bridges:
			assert_true(result.river.has(cell))
			assert_false(result.road.has(cell))
			assert_true(result.is_walkable(cell))
			assert_gte(absi(cell.y - slot.entry.y), RULES.HERO_BRIDGE_MIN_ROW_GAP, "seed %d" % seed)
		assert_true(BluewaterCrossingRegion.new().extra_problems(slot, result).is_empty())


func test_the_checks_require_the_hero_bridge_only_on_an_unforked_crossing() -> void:
	var forked := _layout(1)
	var result := _good(forked)
	var region := BluewaterCrossingRegion.new()
	assert_true(region.extra_problems(forked.slots[REGION], result).is_empty())
	# a hero bridge that would pass every other check: walkable river cells on a row clear of
	# both lanes
	var rows: Array[int] = []
	for bridge in result.bridges:
		rows.append(bridge.cell.y)
	for cell in result.river:
		if rows.all(
			func(row: int) -> bool: return absi(cell.y - row) >= RULES.HERO_BRIDGE_MIN_ROW_GAP
		):
			result.hero_bridges.append(cell)
			result.set_walkable(cell, true)
	assert_false(result.hero_bridges.is_empty(), "the river has a row clear of both bridges")
	assert_false(
		region.extra_problems(forked.slots[REGION], result).is_empty(),
		"a forked crossing with a hero bridge fails"
	)
	var plain := ValleyLayout.generate(1, 40, 24, false)
	var drawn := BluewaterCrossingRegion.new().generate(
		plain.slots[REGION], plain.rng_for(REGION, 0)
	)
	drawn.hero_bridges.clear()
	assert_false(
		region.extra_problems(plain.slots[REGION], drawn).is_empty(),
		"an unforked crossing without a hero bridge fails"
	)


func test_no_block_stands_on_either_bridge_and_blocks_stand_beside_both() -> void:
	for seed in range(1, LAST_SEED + 1):
		var result := _good(_layout(seed))
		for lane in [false, true]:
			var span := SectionSockets.bridge_cells(result, lane)
			assert_false(span.is_empty(), "seed %d lane %s" % [seed, lane])
			for anchor in result.sockets:
				var block := Rect2i(anchor, Vector2i.ONE * 2)
				for cell in span:
					assert_false(block.has_point(cell), "seed %d: block on a bridge" % seed)
			assert_true(
				SectionSockets.reaches_cells(result, span, result.sockets),
				"seed %d: a block beside the %s bridge" % [seed, "lower" if lane else "upper"]
			)


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
		assert_between(result.sockets.size(), 5, 6, "seed %d" % seed)
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
