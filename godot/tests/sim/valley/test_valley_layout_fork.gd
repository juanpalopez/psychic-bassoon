extends GutTest
## The fork of the layout valley's road into two lanes (#481, layout side): the Meadow's entry
## gate to the Ridge's gate, a lower lane `FORK_ROW_GAP` rows under the road through the Meadow and
## across the river. The stitcher builds the lower lane as a route (`test_valley_stitcher_fork.gd`).

const LAYOUT := preload("res://content/valley/layout_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729]
const SWEEP_LAST := 40
const MEADOW := ValleyLayout.Region.SUNKEN_MEADOW
const CROSSING := ValleyLayout.Region.BLUEWATER_CROSSING


func _forked(seed: int) -> ValleyLayout:
	return ValleyLayout.generate(seed, 40, 24, true)


func test_the_layout_has_no_second_lane_when_the_fork_is_off() -> void:
	assert_true(
		LAYOUT.FORK_LANES, "the layout valley forks by default since the stitcher builds it"
	)
	for seed in SEEDS:
		var layout := ValleyLayout.generate(seed, 40, 24, false)
		for slot in layout.slots:
			assert_false(slot.has_branch(), "seed %d region %d" % [seed, slot.id])
			assert_eq(slot.branch_entry, Vector2i(-1, -1))
		assert_true(layout.lane_segments.is_empty())


func test_the_fork_leaves_at_the_meadows_entry_and_merges_at_the_crossings_exit() -> void:
	for seed in SEEDS:
		var layout := _forked(seed)
		assert_not_null(layout, "seed %d" % seed)
		var meadow := layout.slots[MEADOW]
		var crossing := layout.slots[CROSSING]
		assert_eq(meadow.branch_entry, meadow.entry, "seed %d forks at the gate" % seed)
		assert_eq(crossing.branch_exit, crossing.exit, "seed %d merges at the gate" % seed)
		assert_eq(meadow.branch_exit.x, crossing.branch_entry.x - 1, "seed %d" % seed)
		assert_eq(meadow.branch_exit.y, crossing.branch_entry.y, "seed %d" % seed)
		for slot in [meadow, crossing]:
			var lane := RoadSpline.build(slot.branch_spine).cells
			assert_eq(lane[0], slot.branch_entry, "seed %d starts on its gate" % seed)
			assert_eq(lane[lane.size() - 1], slot.branch_exit, "seed %d ends on its gate" % seed)
		for index in layout.slots.size():
			if index != MEADOW and index != CROSSING:
				assert_false(layout.slots[index].has_branch())


func test_the_lower_bridge_is_the_fork_gap_under_the_upper_one() -> void:
	for seed in range(1, SWEEP_LAST + 1):
		var crossing := _forked(seed).slots[CROSSING]
		var gap := crossing.branch_entry.y - crossing.entry.y
		assert_between(gap, LAYOUT.FORK_ROW_GAP.x, LAYOUT.FORK_ROW_GAP.y, "seed %d" % seed)


func test_both_lanes_wade_the_river_once_on_their_own_row_and_pass_the_checks() -> void:
	var wet := {}
	for seed in range(1, SWEEP_LAST + 1):
		var layout := _forked(seed)
		assert_not_null(layout, "seed %d" % seed)
		assert_true(layout.problems().is_empty(), "seed %d" % seed)
		wet.clear()
		for cell in layout.river_cells:
			wet[cell] = true
		var crossing := layout.slots[CROSSING]
		var lane := RoadSpline.build(crossing.branch_spine).cells
		assert_eq(ValleyLayout._wet_runs(lane, wet), 1, "seed %d" % seed)
		var meadow := RoadSpline.build(layout.slots[MEADOW].branch_spine).cells
		assert_false(meadow.any(func(cell: Vector2i) -> bool: return wet.has(cell)))


func test_the_lanes_keep_apart_but_near_the_fork_and_the_merge() -> void:
	for seed in range(1, SWEEP_LAST + 1):
		var layout := _forked(seed)
		var own: Array[Vector2i] = []
		var upper: Array[Vector2i] = []
		for id in [MEADOW, CROSSING]:
			own.append_array(RoadSpline.build(layout.slots[id].branch_spine).cells)
			upper.append_array(RoadSpline.build(layout.slots[id].spine).cells)
		var least := 1000000
		for index in range(LAYOUT.LANE_JOIN, own.size() - LAYOUT.LANE_JOIN):
			for cell in upper:
				least = mini(least, (own[index] - cell).length_squared())
		assert_gte(least, LAYOUT.LANE_APART * LAYOUT.LANE_APART, "seed %d" % seed)


func test_lanes_closer_than_the_gap_are_a_problem_except_near_the_fork_and_the_merge() -> void:
	var own: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	for x in 30:
		own.append(Vector2i(x, 5))
		near.append(Vector2i(x, 5 + LAYOUT.LANE_APART - 1))
		far.append(Vector2i(x, 5 + LAYOUT.LANE_APART))
	assert_eq(ValleyLayout._apart_problems(own, far).size(), 0)
	assert_eq(ValleyLayout._apart_problems(own, near).size(), 1)
	# The lower lane starts on the upper one and ends on it, and keeps off it in between.
	var lower: Array[Vector2i] = []
	var upper: Array[Vector2i] = []
	for x in 30:
		upper.append(Vector2i(x, 5))
		var away := x >= LAYOUT.LANE_JOIN and x < 30 - LAYOUT.LANE_JOIN
		lower.append(Vector2i(x, 5 + 2 * LAYOUT.LANE_APART if away else 5))
	assert_eq(ValleyLayout._apart_problems(lower, upper).size(), 0, "touching at the ends")


func test_a_lower_lane_off_its_own_row_or_in_the_river_is_a_problem() -> void:
	var layout := _forked(42)
	layout.slots[CROSSING].branch_spine = layout.slots[CROSSING].spine.duplicate()
	assert_gt(layout.problems().size(), 0)
	layout = _forked(42)
	layout.slots[MEADOW].branch_spine = layout.slots[CROSSING].spine.duplicate()
	assert_gt(layout.problems().size(), 0)


func test_the_same_seed_gives_the_same_forked_layout() -> void:
	for seed in SEEDS:
		var first := _forked(seed)
		var second := _forked(seed)
		for index in 6:
			assert_eq(first.slots[index].spine, second.slots[index].spine)
			assert_eq(first.slots[index].branch_spine, second.slots[index].branch_spine)
		assert_eq(first.lane_segments, second.lane_segments)


func test_the_stitcher_builds_the_forked_layouts_as_three_routes() -> void:
	for seed in SEEDS:
		var layout := _forked(seed)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		assert_not_null(map, "seed %d" % seed)
		# [the main road, the feeder, the lower lane]: it was two while the stitcher ignored the lane
		assert_eq(map.routes.size(), 3, "seed %d" % seed)
