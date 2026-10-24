extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]
## A layout is drawn and stitched until one passes (a fraction of a second a seed), so the sweeps
## sample the seeds 1..3000.
const SWEEP_STEP := 10
const STITCH_STEP := 10
const LAST_SEED := 3000


func _layout(seed: int) -> ValleyLayout:
	return ValleyLayout.generate(seed, 40, 24)


func _wet(layout: ValleyLayout) -> Dictionary:
	var wet := {}
	for cell in layout.river_cells:
		wet[cell] = true
	return wet


func test_six_regions_in_road_order_tile_the_board() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		assert_eq(layout.slots.size(), 6)
		var owner_of := {}
		for slot in layout.slots:
			assert_eq(slot.id, layout.slots.find(slot))
			for y in range(slot.rect.position.y, slot.rect.end.y):
				for x in range(slot.rect.position.x, slot.rect.end.x):
					assert_false(owner_of.has(Vector2i(x, y)), "overlap, seed %d" % seed)
					owner_of[Vector2i(x, y)] = slot.id
		assert_eq(owner_of.size(), 40 * 24, "seed %d" % seed)
		assert_eq(layout.slots[ValleyLayout.Region.OUTER_MARCH].rect.position, Vector2i.ZERO)
		assert_eq(layout.slots[ValleyLayout.Region.HEARTKEEP_APPROACH].rect.end, Vector2i(40, 24))


func test_regions_sit_where_the_reference_puts_them() -> void:
	for seed in SEEDS:
		var s := _layout(seed).slots
		assert_eq(s[ValleyLayout.Region.SUNKEN_MEADOW].rect.position.x, 0)
		assert_eq(s[ValleyLayout.Region.SUNKEN_MEADOW].rect.position.y, s[0].rect.end.y)
		assert_eq(s[ValleyLayout.Region.BROKEN_RIDGE].rect.position.y, 0)
		assert_eq(s[ValleyLayout.Region.BLUEWATER_CROSSING].rect.end.y, 24)
		assert_eq(s[ValleyLayout.Region.ANCIENT_FOLD].rect.end.x, 40)
		assert_eq(s[ValleyLayout.Region.ANCIENT_FOLD].rect.position.y, 0)


func test_gates_are_adjacent_and_on_the_borders() -> void:
	for seed in SEEDS:
		var s := _layout(seed).slots
		for index in 5:
			var exit := s[index].exit
			var entry := s[index + 1].entry
			assert_eq((entry - exit).length_squared(), 1, "gate %d, seed %d" % [index, seed])
			assert_true(s[index].rect.has_point(exit))
			assert_true(s[index + 1].rect.has_point(entry))
			assert_false(s[index].rect.has_point(entry))


func test_the_road_starts_on_the_west_edge_and_ends_in_the_last_region() -> void:
	for seed in SEEDS:
		var s := _layout(seed).slots
		assert_eq(s[0].entry.x, 0)
		assert_eq(s[5].exit.x, 39)
		assert_true(s[5].rect.has_point(s[5].exit))
		assert_gte(s[5].exit.y, 19)


func test_spines_stay_inside_their_regions() -> void:
	for seed in SEEDS:
		for slot in _layout(seed).slots:
			for cell in RoadSpline.build(slot.spine).cells:
				assert_true(slot.rect.has_point(cell), "seed %d, region %d" % [seed, slot.id])


func test_the_river_runs_from_the_top_edge_to_the_bottom_edge_in_unit_steps() -> void:
	for seed in SEEDS:
		var cells := _layout(seed).river.cells
		assert_eq(cells[0].y, 0)
		assert_eq(cells[cells.size() - 1].y, 23)
		for index in cells.size() - 1:
			assert_eq((cells[index + 1] - cells[index]).length_squared(), 1)
		for cell in cells:
			assert_true(_layout(seed).river_cells.has(cell))


func test_only_the_crossings_road_touches_the_river() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		var wet := _wet(layout)
		for slot in layout.slots:
			var touches := false
			for cell in RoadSpline.build(slot.spine).cells:
				touches = touches or wet.has(cell)
			assert_eq(
				touches,
				slot.id == ValleyLayout.Region.BLUEWATER_CROSSING,
				"seed %d, region %d" % [seed, slot.id]
			)


func test_a_layout_with_a_road_in_the_river_has_problems() -> void:
	var layout := _layout(42)
	assert_eq(layout.problems().size(), 0)
	layout.river_cells.append(layout.slots[0].entry)
	assert_gt(layout.problems().size(), 0)


func test_the_same_seed_gives_the_same_layout() -> void:
	for seed in SEEDS:
		var first := _layout(seed)
		var second := _layout(seed)
		assert_eq(first.river_cells, second.river_cells)
		for index in 6:
			assert_eq(first.slots[index].spine, second.slots[index].spine)
			assert_eq(first.slots[index].rect, second.slots[index].rect)


func test_seeds_give_different_layouts() -> void:
	var seen := {}
	for seed in range(1, 21):
		seen[str(_layout(seed).slots.map(func(slot: ValleyPlan.Slot) -> Rect2i: return slot.rect))] = true
	assert_gte(seen.size(), 3)


func test_every_seed_has_a_layout_that_passes_its_own_checks() -> void:
	for seed in range(1, LAST_SEED + 1, SWEEP_STEP):
		var layout := _layout(seed)
		assert_not_null(layout, "seed %d" % seed)
		if layout == null:
			continue
		assert_eq(layout.problems().size(), 0, "seed %d" % seed)
		var covered := 0
		for index in 6:
			var slot := layout.slots[index]
			covered += slot.rect.size.x * slot.rect.size.y
			if index < 5:
				var next := layout.slots[index + 1]
				assert_eq((next.entry - slot.exit).length_squared(), 1, "gate, seed %d" % seed)
				assert_true(slot.rect.has_point(slot.exit) and next.rect.has_point(next.entry))
				assert_false(slot.rect.has_point(next.entry), "gate off the border, seed %d" % seed)
			for other in range(index + 1, 6):
				assert_false(slot.rect.intersects(layout.slots[other].rect), "overlap")
			for cell in RoadSpline.build(slot.spine).cells:
				assert_true(slot.rect.has_point(cell), "spine, seed %d" % seed)
		assert_eq(covered, 40 * 24, "tiling, seed %d" % seed)


func test_the_crossing_must_wade_the_river_once_from_dry_banks() -> void:
	var dry := _layout(42)
	dry.river_cells.clear()
	assert_gt(dry.problems().size(), 0, "no crossing")
	var wet := _layout(42)
	wet.river_cells.append(wet.slots[ValleyLayout.Region.BLUEWATER_CROSSING].entry)
	assert_gt(wet.problems().size(), 0, "a wet entry")


func _stitch_problems(seed: int) -> void:
	var layout := _layout(seed)
	var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
	assert_not_null(map, "seed %d" % seed)
	if map == null:
		return
	for index in map.path.size() - 1:
		assert_eq((map.path[index + 1] - map.path[index]).length_squared(), 1, "seed %d" % seed)
	assert_eq(map.path[0].x, 0)
	assert_true(map.heartstone.has_point(map.path[map.path.size() - 1]))
	# one curve per route: the main road and, once the Ancient Fold has its feeder, the second
	assert_eq(map.route_curves.size(), map.routes.size())
	assert_eq(
		map.river.size(),
		layout.slots.reduce(
			func(sum: int, slot: ValleyPlan.Slot) -> int: return sum + slot.river.size(), 0
		)
	)


func test_the_stitched_stand_in_valley_passes_the_checks_for_every_seed() -> void:
	for seed in range(1, LAST_SEED + 1, STITCH_STEP):
		_stitch_problems(seed)


## Measured on seeds 1..300 at 40 by 24 (#480): every seed stitches, and the sockets stay between
## 23 and 30 (the six regions' own ranges, which do not grow with the board).
func test_every_seed_to_300_stitches_with_23_to_30_sockets() -> void:
	for seed in range(1, 301):
		var map := MapGen.generate_layout_valley(seed)
		assert_not_null(map, "seed %d" % seed)
		if map != null:
			assert_between(map.sockets.size(), 23, 30, "seed %d" % seed)


func test_seeds_that_once_failed_to_stitch_now_do() -> void:
	for seed in [359, 374, 483, 607, 710]:
		_stitch_problems(seed)
