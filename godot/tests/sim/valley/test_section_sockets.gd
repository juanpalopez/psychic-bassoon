extends GutTest

const SEEDS: Array[int] = [1, 42, 2026, 104729, 4294967295]


func _result(seed: int, id: int) -> SectionResult:
	var slot := ValleyPlan.create(seed, 32, 20).slots[id]
	var section := ValleySections.all()[id]
	return section.generate(slot, ValleyPlan.section_rng(seed, id, 0))


func test_the_stub_road_runs_from_the_entry_to_the_exit_in_unit_steps() -> void:
	for seed in SEEDS:
		for id in 6:
			var slot := ValleyPlan.create(seed, 32, 20).slots[id]
			var road := _result(seed, id).road
			assert_eq(road[0], slot.entry, "seed %d section %d" % [seed, id])
			assert_eq(road[road.size() - 1], slot.exit, "seed %d section %d" % [seed, id])
			for index in road.size() - 1:
				var step := road[index + 1] - road[index]
				assert_eq(absi(step.x) + absi(step.y), 1, "seed %d section %d" % [seed, id])
				assert_true(slot.rect.has_point(road[index]))


func test_bends_are_the_cells_where_the_road_turns() -> void:
	var road: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
	assert_eq(SectionSockets.bends(road), [Vector2i(1, 0), Vector2i(1, 1)] as Array[Vector2i])
	var straight: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_eq(SectionSockets.bends(straight).size(), 0)


func test_blocks_stay_off_the_road_inside_the_strip_and_keep_their_gap() -> void:
	for seed in SEEDS:
		for id in 6:
			var result := _result(seed, id)
			for anchor in result.sockets:
				var block := Rect2i(anchor, Vector2i(2, 2))
				assert_true(result.rect.encloses(block), "seed %d section %d" % [seed, id])
				assert_lt(block.end.x, result.rect.end.x)
				for cell in result.road:
					assert_false(block.has_point(cell), "seed %d section %d" % [seed, id])
				for other in result.sockets:
					if other != anchor:
						var far: bool = (
							absi(anchor.x - other.x) >= 3 or absi(anchor.y - other.y) >= 3
						)
						assert_true(far, "seed %d section %d" % [seed, id])


func test_the_stub_keeps_its_socket_range_and_the_arrays_in_step() -> void:
	for seed in SEEDS:
		for id in 6:
			var result := _result(seed, id)
			var section := ValleySections.all()[id]
			assert_gte(result.sockets.size(), section.socket_range().x, "seed %d %d" % [seed, id])
			assert_lte(result.sockets.size(), section.socket_range().y)
			assert_eq(result.socket_levels.size(), result.sockets.size())
			assert_eq(result.socket_tags.size(), result.sockets.size())


func test_a_bend_gets_a_block_in_reach() -> void:
	for seed in SEEDS:
		for id in 6:
			var result := _result(seed, id)
			for bend in SectionSockets.bends(result.road):
				var covered := false
				for anchor in result.sockets:
					covered = (
						covered
						or (
							Vector2(anchor + Vector2i(1, 1)).distance_to(
								Vector2(bend) + Vector2(0.5, 0.5)
							)
							<= 3.5
						)
					)
				assert_true(covered, "seed %d section %d bend %s" % [seed, id, bend])


func test_the_last_section_keeps_blocks_off_the_heartstone() -> void:
	for seed in SEEDS:
		var slot := ValleyPlan.create(seed, 32, 20).slots[5]
		var section := ValleySections.all()[5]
		var result := section.generate(slot, ValleyPlan.section_rng(seed, 5, 0))
		var heartstone := section.reserved(slot)[0]
		assert_true(heartstone.has_point(slot.exit))
		for anchor in result.sockets:
			assert_false(Rect2i(anchor, Vector2i(2, 2)).intersects(heartstone), "seed %d" % seed)


func test_the_same_stream_gives_the_same_sockets() -> void:
	assert_eq(_result(42, 2).sockets, _result(42, 2).sockets)
