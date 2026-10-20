extends GutTest

const RULES := preload("res://content/valley/valley_rules.gd")
const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]


func _plan(seed: int) -> ValleyPlan:
	return ValleyPlan.create(seed, 32, 20)


func test_six_sections_in_the_fixed_order() -> void:
	for seed in SEEDS:
		var plan := _plan(seed)
		assert_eq(plan.slots.size(), 6)
		for index in plan.slots.size():
			assert_eq(plan.slots[index].id, index, "seed %d" % seed)


func test_strips_tile_the_board() -> void:
	for seed in SEEDS:
		var left := 0
		for slot in _plan(seed).slots:
			assert_eq(slot.rect.position.x, left, "seed %d" % seed)
			assert_gte(slot.rect.size.x, RULES.MIN_WIDTHS[slot.id])
			assert_eq(slot.rect.size.y, 20)
			left += slot.rect.size.x
		assert_eq(left, 32, "seed %d" % seed)


func test_gates_line_up_between_sections() -> void:
	for seed in SEEDS:
		var slots := _plan(seed).slots
		for index in slots.size() - 1:
			var exit := slots[index].exit
			var entry := slots[index + 1].entry
			assert_eq(entry, exit + Vector2i(1, 0), "seed %d gate %d" % [seed, index])


func test_the_road_enters_on_the_left_edge_and_leaves_on_the_right_edge() -> void:
	for seed in SEEDS:
		var slots := _plan(seed).slots
		assert_eq(slots[0].entry.x, 0)
		assert_eq(slots[5].exit.x, 31)


func test_gate_rows_keep_their_margin_and_step_limit() -> void:
	for seed in SEEDS:
		var previous := -1
		for slot in _plan(seed).slots:
			for row in [slot.entry.y, slot.exit.y]:
				assert_gte(row, RULES.GATE_MARGIN)
				assert_lte(row, 19 - RULES.GATE_MARGIN)
			assert_lte(absi(slot.exit.y - slot.entry.y), RULES.GATE_MAX_STEP)
			previous = slot.exit.y
		assert_ne(previous, -1)


func test_the_same_seed_gives_the_same_plan() -> void:
	var first := _plan(2026)
	var second := _plan(2026)
	for index in 6:
		assert_eq(first.slots[index].rect, second.slots[index].rect)
		assert_eq(first.slots[index].entry, second.slots[index].entry)
		assert_eq(first.slots[index].exit, second.slots[index].exit)


func test_seeds_vary_the_plan_but_not_the_order() -> void:
	var seen := {}
	for seed in SEEDS:
		seen[str(_plan(seed).slots[0].entry) + str(_plan(seed).slots[2].rect)] = true
	assert_gt(seen.size(), 1)


func test_a_section_stream_is_its_own_and_an_attempt_changes_only_that_section() -> void:
	var first := ValleyPlan.section_rng(7, 2, 0).next_int(1000000)
	assert_eq(ValleyPlan.section_rng(7, 2, 0).next_int(1000000), first)
	assert_ne(ValleyPlan.section_rng(7, 2, 1).next_int(1000000), first)
	assert_ne(ValleyPlan.section_rng(7, 3, 0).next_int(1000000), first)
	assert_ne(Rng.derive(7, Streams.VALLEY_PLAN).next_int(1000000), first)


func test_section_result_layers_cover_the_strip() -> void:
	var slot := _plan(1).slots[2]
	var result := SectionResult.create(slot)
	var cell := slot.rect.position + Vector2i(1, 4)
	assert_true(result.has_cell(cell))
	assert_false(result.has_cell(Vector2i(0, 0)))
	assert_eq(result.height_at(cell), 0)
	assert_eq(result.region_at(cell), GameMap.Region.MEADOW)
	assert_true(result.is_walkable(cell))
	result.set_height(cell, 3)
	result.set_walkable(cell, false)
	assert_eq(result.height_at(cell), 3)
	assert_false(result.is_walkable(cell))
	assert_true(result.is_walkable(cell + Vector2i(1, 0)))


func test_add_socket_keeps_the_parallel_arrays_in_step() -> void:
	var result := SectionResult.create(_plan(1).slots[0])
	result.add_socket(Vector2i(2, 5), 1, SectionResult.Tag.BEND)
	assert_eq(result.sockets, [Vector2i(2, 5)] as Array[Vector2i])
	assert_eq(result.socket_levels, [1] as Array[int])
	assert_eq(result.socket_tags, [SectionResult.Tag.BEND] as Array[int])
