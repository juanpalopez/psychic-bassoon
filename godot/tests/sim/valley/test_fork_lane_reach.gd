extends GutTest
## The sockets reach both lanes of the fork (#516): a block beside the lower lane counts as
## reaching the road, each strip with the lower lane has `BRANCH_MIN_BLOCKS` blocks that reach its
## own stretch, and some block reaches each lane's bridge. A strip without a branch is unchanged.

const LAYOUT := preload("res://content/valley/layout_rules.gd")
const ROAD := preload("res://content/valley/road_rules.gd")
const MEADOW := ValleyLayout.Region.SUNKEN_MEADOW
const CROSSING := ValleyLayout.Region.BLUEWATER_CROSSING
const SEEDS: Array[int] = [1, 7, 42, 99, 2026, 3001]


func _attempt(seed: int, region: int) -> Array:
	var layout := ValleyLayout.generate(seed, 40, 24)
	var slot := layout.slots[region]
	var section := ValleyLayout.sections()[region]
	return [slot, section, section.generate(slot, layout.rng_for(region, 0))]


func _lane_result() -> SectionResult:
	# an upper road along row 4 and a lower lane along row 12, far apart
	var result := SectionResult.new()
	result.road_width = 1.0
	for x in range(0, 20):
		result.road.append(Vector2i(x, 4))
		result.branch.append(Vector2i(x, 12))
	return result


func test_a_block_beside_only_the_lower_lane_reaches_the_road() -> void:
	var result := _lane_result()
	var block := Rect2i(8, 13, 2, 2)
	assert_true(SectionSockets.reaches(result, block), "the lower lane is in reach")
	result.branch = []
	assert_false(SectionSockets.reaches(result, block), "without a lane it is too far")


func test_own_branch_leaves_out_the_cells_the_road_shares() -> void:
	var result := _lane_result()
	result.branch[0] = Vector2i(0, 4)
	assert_false(SectionSockets.own_branch(result).has(Vector2i(0, 4)))
	assert_eq(SectionSockets.own_branch(result).size(), 19)


func test_blocks_reaching_counts_only_blocks_with_the_cells_in_reach() -> void:
	var result := _lane_result()
	result.sockets = [Vector2i(8, 13), Vector2i(8, 5)] as Array[Vector2i]
	assert_eq(SectionSockets.blocks_reaching(result, SectionSockets.own_branch(result)), 1)
	assert_eq(SectionSockets.blocks_reaching(result, result.road), 1)


func test_the_blocks_of_a_stitched_map_reach_the_lower_lane_and_both_bridges() -> void:
	var reach := SectionSockets.coverage_reach(ROAD.ROAD_WIDTH_CELLS)
	for seed in SEEDS:
		var map := MapGen.generate_layout_valley(seed)
		var lane: Array[Vector2i] = []
		lane.assign(map.routes[map.forks[0].route])
		var own: Array[Vector2i] = []
		for cell in lane:
			if not map.path.has(cell):
				own.append(cell)
		var count := 0
		for anchor in map.sockets:
			count += (
				1 if SectionSockets.covers(Rect2i(anchor, Vector2i(2, 2)), own, 0.0, reach) else 0
			)
		assert_gte(count, LAYOUT.BRANCH_MIN_BLOCKS, "seed %d" % seed)
		var lower := 0
		var upper := 0
		for bridge in map.bridges:
			var hit := map.sockets.any(
				func(anchor: Vector2i) -> bool:
					return SectionSockets.centre_gap(anchor, bridge.cell) <= reach
			)
			if hit:
				lower += 1 if bridge.on_branch else 0
				upper += 0 if bridge.on_branch else 1
		assert_gt(lower, 0, "seed %d: a block reaches the lower bridge" % seed)
		assert_gt(upper, 0, "seed %d: a block reaches the upper bridge" % seed)


func _texts(made: Array) -> String:
	var found := ValleyChecks.section_problems(made[0], made[2], made[1])
	return " | ".join(found.map(func(p: ValleyChecks.Problem) -> String: return p.text))


func test_a_strip_whose_blocks_miss_the_lower_lane_fails() -> void:
	var made := _attempt(42, CROSSING)
	var result: SectionResult = made[2]
	assert_eq(_texts(made).count("lower lane"), 0, _texts(made))
	var held := result.sockets.duplicate()
	var own := SectionSockets.own_branch(result)
	# keep only the blocks that do not reach the lane's own stretch
	var kept: Array[Vector2i] = []
	var levels: Array[int] = []
	var tags: Array[int] = []
	for index in held.size():
		var block := Rect2i(held[index], Vector2i(2, 2))
		if not SectionSockets.covers(
			block, own, 0.0, SectionSockets.coverage_reach(result.road_width)
		):
			kept.append(held[index])
			levels.append(result.socket_levels[index])
			tags.append(result.socket_tags[index])
	result.sockets = kept
	result.socket_levels = levels
	result.socket_tags = tags
	assert_string_contains(_texts(made), "reach the lower lane")


func test_a_strip_with_no_block_at_a_bridge_fails() -> void:
	var made := _attempt(42, CROSSING)
	var result: SectionResult = made[2]
	assert_eq(_texts(made).count("bridge"), 0, _texts(made))
	var lower := result.bridges.filter(func(b: GameMap.Bridge) -> bool: return b.on_branch)
	assert_false(lower.is_empty())
	var moved: GameMap.Bridge = lower[0]
	var far := Vector2i(1000, 1000)
	var held := moved.cell
	# a bridge far from every block cannot be reached (the check reads the span's cells)
	for bridge in lower:
		bridge.cell = far
	assert_string_contains(_texts(made), "lower bridge")
	moved.cell = held


func test_a_branch_bend_without_a_block_fails() -> void:
	var tried := 0
	for seed in range(1, 41):
		for region in [MEADOW, CROSSING]:
			var made := _attempt(seed, region)
			var result: SectionResult = made[2]
			if SectionSockets.bends(result.branch, made[0].bend_run).is_empty():
				continue
			tried += 1
			if tried > 1:
				return
			assert_eq(_texts(made).count("branch bend"), 0, _texts(made))
			result.sockets.clear()
			result.socket_levels.clear()
			result.socket_tags.clear()
			assert_string_contains(_texts(made), "branch bend")
	assert_gt(tried, 0, "some lane in seeds 1..40 has a bend")


func test_the_placer_covers_a_bend_of_the_lower_lane_and_reaches_both_lanes() -> void:
	for seed in range(1, 9):
		var result := SectionResult.new()
		result.rect = Rect2i(0, 0, 40, 30)
		result.margin = Vector2i(1, 1)
		result.road_width = 1.0
		result.bend_run = 2
		for x in range(0, 30):
			result.road.append(Vector2i(x, 3))
		# the lower lane runs along row 20, climbs three cells at x 28 and ends there
		for x in range(0, 29):
			result.branch.append(Vector2i(x, 20))
		for y in range(19, 15, -1):
			result.branch.append(Vector2i(28, y))
		result.heights.resize(40 * 30)
		result.regions.resize(40 * 30)
		result.walkable.resize(40 * 30)
		SectionSockets.place(result, Vector2i(1, 1), Rng.create(seed), [] as Array[Rect2i])
		var bends := SectionSockets.bends(result.branch, result.bend_run)
		assert_false(bends.is_empty())
		for bend in bends:
			var near := false
			for anchor in result.sockets:
				near = (
					near
					or SectionSockets.centre_gap(anchor, bend) <= SectionSockets.bend_reach(result)
				)
			assert_true(near, "seed %d: the bend at %s is covered" % [seed, bend])
		var own := SectionSockets.own_branch(result)
		assert_gte(SectionSockets.blocks_reaching(result, own), LAYOUT.BRANCH_MIN_BLOCKS)


func _bridged(blocks: Array[Vector2i]) -> SectionResult:
	var result := _lane_result()
	result.sockets = blocks
	for on_branch in [false, true]:
		var bridge := GameMap.Bridge.new()
		bridge.cell = Vector2i(8, 12 if on_branch else 4)
		bridge.on_branch = on_branch
		result.bridges.append(bridge)
	return result


func _lane_text(result: SectionResult) -> String:
	var found := ValleyChecks._lane_reach_problems(0, result)
	return " | ".join(found.map(func(p: ValleyChecks.Problem) -> String: return p.text))


func test_exactly_one_block_on_the_lower_lane_fails_and_two_pass() -> void:
	# (8, 5) is beside the upper bridge, (8, 13) beside the lower one
	var one := _bridged([Vector2i(8, 5), Vector2i(8, 13)] as Array[Vector2i])
	assert_string_contains(_lane_text(one), "1 socket blocks reach the lower lane")
	var two := _bridged([Vector2i(8, 5), Vector2i(8, 13), Vector2i(12, 13)] as Array[Vector2i])
	assert_eq(_lane_text(two), "")


func test_a_block_at_only_one_bridge_fails_for_the_other() -> void:
	var lower_only := _bridged([Vector2i(8, 13), Vector2i(12, 13)] as Array[Vector2i])
	assert_string_contains(_lane_text(lower_only), "upper bridge")
	assert_false(_lane_text(lower_only).contains("lower bridge"))
	# two lane blocks far from the lower bridge, one beside the upper bridge
	var upper_only := _bridged(
		[Vector2i(8, 5), Vector2i(0, 13), Vector2i(16, 13)] as Array[Vector2i]
	)
	assert_string_contains(_lane_text(upper_only), "lower bridge")
	assert_false(_lane_text(upper_only).contains("upper bridge"))
