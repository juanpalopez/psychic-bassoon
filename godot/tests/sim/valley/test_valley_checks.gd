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


class Picky:
	extends StraightSection

	func extra_problems(_slot: ValleyPlan.Slot, _result: SectionResult) -> Array[String]:
		return ["no meadow"]


func test_a_section_can_add_its_own_checks() -> void:
	var problems := ValleyChecks.section_problems(_slot(), _good(), Picky.new())
	assert_eq(problems.size(), 1)
	assert_eq(problems[0].text, "no meadow")
	assert_eq(problems[0].section, 2)


func test_a_feeder_must_end_beside_a_road_cell_it_joins() -> void:
	var result := _good()
	result.feeder = [Vector2i(result.road[2].x, 0)] as Array[Vector2i]
	result.feeder_join = result.road[2]
	var texts := _problems(result).map(func(p: ValleyChecks.Problem) -> String: return p.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("feeder")), str(texts))
	result.feeder_join = Vector2i(0, 0)
	texts = _problems(result).map(func(p: ValleyChecks.Problem) -> String: return p.text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("off the road")), str(texts))


func test_a_bridge_off_the_road_fails() -> void:
	var result := _good()
	var bridge := GameMap.Bridge.new()
	bridge.cell = Vector2i(-5, -5)
	result.bridges.append(bridge)
	assert_gt(_problems(result).size(), 0)


func test_sockets_with_missing_levels_are_a_problem_not_a_crash() -> void:
	var result := _good()
	result.socket_levels.clear()
	assert_gt(_problems(result).size(), 0)


func test_a_bend_on_a_section_join_needs_a_block_from_either_side() -> void:
	var results: Array[SectionResult] = []
	for id in 6:
		results.append(_good(id))
	var left := results[2]
	var right := results[3]
	# turn the road at the join: the left section ends going up, the right one starts going right
	var exit := left.road[left.road.size() - 1]
	left.road[left.road.size() - 2] = exit + Vector2i(0, 1)
	for result in [left, right]:
		result.sockets.clear()
		result.socket_levels.clear()
		result.socket_tags.clear()
	var texts := ValleyChecks.valley_problems(results).map(
		func(p: ValleyChecks.Problem) -> String: return p.text
	)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("join bend")), str(texts))


func _road_result(cells: Array[Vector2i], id: int) -> SectionResult:
	var result := SectionResult.new()
	result.id = id
	result.road = cells
	return result


func _hairpin() -> Array[Vector2i]:
	# 14 cells out along row 0, a turn, and 14 back along row 2: two lanes 2 cells apart
	var cells: Array[Vector2i] = []
	for x in 14:
		cells.append(Vector2i(x, 0))
	cells.append(Vector2i(14, 1))
	for x in range(14, -1, -1):
		cells.append(Vector2i(x, 2))
	return cells


func test_a_hairpin_breaks_the_lane_rule_and_a_wide_bend_does_not() -> void:
	var plan := ValleyPlan.new()
	plan.lane_gap = 5
	plan.lane_run = 12
	var results: Array[SectionResult] = [_road_result(_hairpin(), 0)]
	var found := ValleyChecks._lane_problems(results, plan.lane_gap, plan.lane_run)
	assert_eq(found.size(), 1)
	assert_eq(found[0].section, 0)
	var wide: Array[Vector2i] = []
	for x in 14:
		wide.append(Vector2i(x, 0))
	for y in range(1, 8):
		wide.append(Vector2i(13, y))
	for x in range(12, -1, -1):
		wide.append(Vector2i(x, 7))
	var ok: Array[SectionResult] = [_road_result(wide, 0)]
	assert_eq(ValleyChecks._lane_problems(ok, plan.lane_gap, plan.lane_run).size(), 0)


func test_the_lane_rule_is_blamed_on_the_later_section() -> void:
	var first := _road_result(_hairpin().slice(0, 15), 0)
	var second := _road_result(_hairpin().slice(15), 1)
	var results: Array[SectionResult] = [first, second]
	var found := ValleyChecks._lane_problems(results, 5, 12)
	assert_eq(found.size(), 1)
	assert_eq(found[0].section, 1)


func test_stretches_closer_than_the_run_are_one_bend_not_two_lanes() -> void:
	var results: Array[SectionResult] = [_road_result(_hairpin(), 0)]
	assert_eq(ValleyChecks._lane_problems(results, 5, 40).size(), 0)
