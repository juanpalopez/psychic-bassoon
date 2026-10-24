extends GutTest

const ROUTES := preload("res://content/valley/route_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729]
## The ticket's guarantee (#433): every seed in 1..300 composes.
const SWEEP_LAST := 300


func _layout(seed: int) -> ValleyLayout:
	return ValleyLayout.generate(seed, 40, 24)


func test_the_composed_route_passes_the_layout_checks_and_the_stitcher() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		assert_not_null(layout, "seed %d" % seed)
		assert_true(layout.problems().is_empty(), "seed %d" % seed)
		assert_not_null(
			ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout), "seed %d" % seed
		)


func test_every_region_runs_gate_to_gate_with_an_allowed_template() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		var index := 0
		for slot in layout.slots:
			var options: Array = ROUTES.ALLOWED[slot.id]
			var allowed := options.any(
				func(option: Array) -> bool: return option[0] == layout.route_segments[index]
			)
			assert_true(allowed, "seed %d region %d" % [seed, slot.id])
			index += 2 if slot.id == ValleyLayout.Region.BLUEWATER_CROSSING else 1
			assert_eq(slot.spine[0], Vector2(slot.entry) + Vector2(0.5, 0.5))
			assert_eq(slot.spine[slot.spine.size() - 1], Vector2(slot.exit) + Vector2(0.5, 0.5))
		assert_eq(index, layout.route_segments.size())


func test_the_bridge_is_level_and_straight_across_the_river() -> void:
	for seed in SEEDS:
		var slot := _layout(seed).slots[ValleyLayout.Region.BLUEWATER_CROSSING]
		var cells := RoadSpline.build(slot.spine).cells
		var wet: Array[int] = []
		for index in cells.size():
			if slot.river.has(cells[index]):
				wet.append(index)
		assert_false(wet.is_empty(), "seed %d" % seed)
		for index in range(0, wet[wet.size() - 1] + 1):
			assert_eq(cells[index].y, slot.entry.y, "seed %d level" % seed)


func test_no_template_runs_three_times_in_a_row_and_the_length_is_bounded() -> void:
	for seed in SEEDS:
		var layout := _layout(seed)
		var ids := layout.route_segments
		for index in range(2, ids.size()):
			assert_false(ids[index] == ids[index - 1] and ids[index] == ids[index - 2])
		var length := 0
		for slot in layout.slots:
			length += RoadSpline.build(slot.spine).cells.size()
		assert_between(length, ROUTES.LENGTH.x, ROUTES.LENGTH.y)


func test_a_seed_always_composes_the_same_route() -> void:
	for seed in SEEDS:
		assert_eq(_layout(seed).route_segments, _layout(seed).route_segments)
		assert_eq(_layout(seed).slots[1].spine, _layout(seed).slots[1].spine)


func test_every_seed_up_to_300_composes() -> void:
	for seed in range(1, SWEEP_LAST + 1):
		assert_not_null(_layout(seed), "seed %d" % seed)
