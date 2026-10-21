extends GutTest


func _slot(id: int = 2) -> ValleyPlan.Slot:
	return ValleyPlan.create(42, 32, 20).slots[id]


func _good(id: int = 2) -> SectionResult:
	var section := ValleySections.all()[id]
	return section.generate(_slot(id), ValleyPlan.section_rng(42, id, 0))


func _problems(result: SectionResult, id: int = 2) -> Array[ValleyChecks.Problem]:
	return ValleyChecks.section_problems(_slot(id), result, ValleySections.all()[id])


func test_a_stand_in_section_passes() -> void:
	for id in 6:
		assert_eq(_problems(_good(id), id).size(), 0, "section %d" % id)


func test_a_road_that_jumps_or_misses_its_gates_fails() -> void:
	var jumped := _good()
	jumped.road.remove_at(2)
	assert_gt(_problems(jumped).size(), 0)
	var short := _good()
	short.road.pop_back()
	assert_gt(_problems(short).size(), 0)


func test_a_road_off_the_valley_floor_fails() -> void:
	var raised := _good()
	raised.set_height(raised.road[1], 2)
	assert_gt(_problems(raised).size(), 0)


func test_too_few_sockets_fail() -> void:
	var bare := _good()
	bare.sockets.clear()
	bare.socket_levels.clear()
	bare.socket_tags.clear()
	assert_gt(_problems(bare).size(), 0)


func test_a_block_on_the_road_fails() -> void:
	var bad := _good()
	bad.sockets[0] = bad.road[3]
	assert_gt(_problems(bad).size(), 0)


func test_a_block_whose_level_does_not_match_the_ground_fails() -> void:
	var bad := _good()
	bad.socket_levels[0] = 1
	assert_gt(_problems(bad).size(), 0)


func test_an_uncovered_bend_fails() -> void:
	var id := 0
	while SectionSockets.bends(_good(id).road).is_empty():
		id += 1
	var result := _good(id)
	var bend := SectionSockets.bends(result.road)[0]
	for index in range(result.sockets.size() - 1, -1, -1):
		if SectionSockets.centre_gap(result.sockets[index], bend) <= 3.5:
			result.sockets.remove_at(index)
			result.socket_levels.remove_at(index)
			result.socket_tags.remove_at(index)
	var texts := _problems(result, id).map(func(p: ValleyChecks.Problem) -> String: return p.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("bend")), str(texts))


func test_blocks_of_neighbouring_strips_must_keep_their_gap() -> void:
	var left := _good(1)
	var right := _good(2)
	right.sockets[0] = left.sockets[0] + Vector2i(2, 0)
	var problems := ValleyChecks.valley_problems([left, right] as Array[SectionResult])
	assert_gt(problems.size(), 0)
	assert_eq(problems[0].section, 2)


func test_high_ground_is_capped_and_needs_a_low_socket_nearby() -> void:
	var results: Array[SectionResult] = []
	for id in 6:
		results.append(_good(id))
	assert_eq(ValleyChecks.valley_problems(results).size(), 0)
	results[1].socket_tags[0] = SectionResult.Tag.HIGH
	assert_eq(ValleyChecks.valley_problems(results).size(), 0, "one high socket among many")
	for result in results:
		result.socket_tags.fill(SectionResult.Tag.HIGH)
	var texts := ValleyChecks.valley_problems(results).map(
		func(p: ValleyChecks.Problem) -> String: return p.text
	)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("too many")), str(texts))
	assert_true(texts.any(func(t: String) -> bool: return t.contains("no low socket")), str(texts))
