extends GutTest


func _layout(seed: int) -> ValleyLayout:
	return ValleyLayout.generate(seed, 40, 24)


func _spine_cells(layout: ValleyLayout) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for slot in layout.slots:
		cells.append_array(RoadSpline.build(slot.spine).cells)
	return cells


func test_the_layout_turns_the_lane_rule_on() -> void:
	var layout := _layout(42)
	assert_eq(layout.lane_gap, 5)
	assert_eq(layout.lane_run, 12)


func test_a_crossing_without_room_for_straight_approaches_fails_the_layout() -> void:
	var layout := _layout(42)
	var crossing := layout.slots[ValleyLayout.Region.BLUEWATER_CROSSING]
	crossing.river.append(Vector2i(crossing.entry.x + 1, crossing.entry.y))
	assert_gt(layout.problems().size(), 0)


func test_the_ridge_keeps_a_wide_plateau_of_dry_ground() -> void:
	for seed in range(1, 101):
		var ridge := _layout(seed).slots[ValleyLayout.Region.BROKEN_RIDGE]
		var dry := ridge.rect.size.x * ridge.rect.size.y - ridge.river.size()
		assert_gte(dry, 60, "seed %d" % seed)


func test_a_straight_leg_spine_fails_the_layout() -> void:
	var layout := _layout(42)
	var march := layout.slots[ValleyLayout.Region.OUTER_MARCH]
	var from := Vector2(march.entry) + Vector2(0.5, 0.5)
	march.spine = [from, from + Vector2(float(ValleyLayout.LAYOUT.MAX_STRAIGHT) + 2.0, 0.0)]
	assert_true(layout.problems().any(func(text: String) -> bool: return "straight" in text))


func test_the_roads_sweep_on_diagonals_in_every_layout() -> void:
	var total := 0.0
	for seed in range(1, 301):
		var share := _layout(seed).diagonal_share()
		assert_gte(share, 0.2, "seed %d" % seed)
		total += share
	assert_gte(total / 300.0, 0.25)


func test_a_hairpin_spine_fails_the_layout() -> void:
	var layout := _layout(42)
	var march := layout.slots[ValleyLayout.Region.OUTER_MARCH]
	var from := Vector2(march.entry) + Vector2(0.5, 0.5)
	march.spine = [
		from, from + Vector2(5.0, 0.0), from + Vector2(5.0, 2.0), from + Vector2(0.0, 2.0)
	]
	assert_gt(layout.problems().size(), 0)


func test_accepted_spines_keep_the_lanes_apart_and_never_revisit_a_cell() -> void:
	for seed in range(1, 301):
		var cells := _spine_cells(_layout(seed))
		var seen := {}
		for cell in cells:
			assert_false(seen.has(cell), "seed %d visits %s twice" % [seed, cell])
			seen[cell] = true
		for later in range(12, cells.size()):
			for earlier in later - 11:
				var gap := (cells[later] - cells[earlier]).length_squared()
				assert_gte(gap, 25, "seed %d lane" % seed)
