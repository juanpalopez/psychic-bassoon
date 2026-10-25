## The rules a valley must meet (#381). Each returns the problems it finds, each naming the
## section to draw again; none means the section (or the whole valley) passes.
class_name ValleyChecks
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const HERO := preload("res://content/valley/hero_rules.gd")
const LAYOUT := preload("res://content/valley/layout_rules.gd")


## One problem and the section whose attempt should change.
class Problem:
	extends RefCounted
	var section: int = 0
	var text: String = ""

	static func make(section_id: int, message: String) -> Problem:
		var problem := Problem.new()
		problem.section = section_id
		problem.text = message
		return problem


## Every problem of the sections and of the valley they make together.
static func all_problems(
	plan: ValleyPlan, sections: Array[ValleySection], results: Array[SectionResult]
) -> Array[Problem]:
	var found: Array[Problem] = []
	for slot in plan.slots:
		found.append_array(section_problems(slot, results[slot.id], sections[slot.id]))
	found.append_array(valley_problems(results, plan))
	return found


## The road runs from the slot's entry to its exit in unit steps inside the strip, on the valley
## floor; the sockets are in range, fit, reach the road and cover its bends.
static func section_problems(
	slot: ValleyPlan.Slot, result: SectionResult, section: ValleySection
) -> Array[Problem]:
	var found: Array[Problem] = []
	var id := slot.id
	var road := result.road
	if road.is_empty() or road[0] != slot.entry or road[road.size() - 1] != slot.exit:
		return [Problem.make(id, "the road does not run from the entry to the exit")]
	for index in road.size():
		if not slot.rect.has_point(road[index]) or result.height_at(road[index]) != 0:
			found.append(
				Problem.make(id, "road cell %s is outside the strip or off the floor" % road[index])
			)
		if index > 0 and (road[index] - road[index - 1]).length_squared() != 1:
			found.append(Problem.make(id, "the road jumps at %s" % road[index]))
	found.append_array(_branch_problems(slot, result))
	if not found.is_empty():
		return found
	if result.socket_levels.size() != result.sockets.size():
		return [Problem.make(id, "socket levels do not match the sockets")]
	if result.socket_tags.size() != result.sockets.size():
		return [Problem.make(id, "socket tags do not match the sockets")]
	found.append_array(_link_problems(id, result))
	var wanted := section.socket_range()
	if result.sockets.size() < wanted.x or result.sockets.size() > wanted.y:
		found.append(
			Problem.make(
				id, "%d socket blocks, want %d to %d" % [result.sockets.size(), wanted.x, wanted.y]
			)
		)
	var blocked := section.reserved(slot)
	for index in result.sockets.size():
		var block := Rect2i(result.sockets[index], Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT)
		if not _block_fits(slot, result, block, index, blocked):
			found.append(Problem.make(id, "socket block %s does not fit" % result.sockets[index]))
	for bend in SectionSockets.bends(road, slot.bend_run):
		if not _covered(result, bend):
			found.append(Problem.make(id, "no socket block covers the bend at %s" % bend))
	for bend in SectionSockets.bends(result.branch, slot.bend_run):
		if not _covered(result, bend):
			found.append(Problem.make(id, "no socket block covers the branch bend at %s" % bend))
	found.append_array(_lane_reach_problems(id, result))
	for text in section.extra_problems(slot, result):
		found.append(Problem.make(id, text))
	return found


## Across the whole valley: blocks of neighbouring strips keep their gap, high ground stays
## scarce and each high socket has a low one to fall back on.
static func valley_problems(
	results: Array[SectionResult], plan: ValleyPlan = null
) -> Array[Problem]:
	var found: Array[Problem] = []
	var all: Array[Vector2i] = []
	var high := 0
	for result in results:
		for index in result.sockets.size():
			for other in all.size():
				if not SectionSockets.blocks_apart(result.sockets[index], all[other]):
					found.append(
						Problem.make(
							result.id,
							"socket block %s crowds %s" % [result.sockets[index], all[other]]
						)
					)
			all.append(result.sockets[index])
			high += 1 if result.socket_tags[index] == SectionResult.Tag.HIGH else 0
	found.append_array(_join_bend_problems(results, plan.bend_run if plan != null else 1))
	if high * 100 > all.size() * VALLEY.HIGH_MAX_PERCENT:
		found.append(
			Problem.make(
				_most_high(results), "too many high-ground sockets: %d of %d" % [high, all.size()]
			)
		)
	for result in results:
		for index in result.sockets.size():
			if (
				result.socket_tags[index] == SectionResult.Tag.HIGH
				and not _has_low_nearby(results, result.sockets[index])
			):
				found.append(
					Problem.make(
						result.id, "high socket %s has no low socket nearby" % result.sockets[index]
					)
				)
	if plan != null and plan.lane_gap > 0:
		found.append_array(_lane_problems(results, plan.lane_gap, plan.lane_run))
	found.append_array(HeroGraph.problems(results, plan.hero_caps if plan != null else HERO.CAPS))
	return found


static func _block_fits(
	slot: ValleyPlan.Slot, result: SectionResult, block: Rect2i, index: int, blocked: Array[Rect2i]
) -> bool:
	var inside := (
		slot.rect.encloses(block)
		and block.end.x <= slot.rect.end.x - slot.margin.x
		and block.end.y <= slot.rect.end.y - slot.margin.y
	)
	var level: int = result.socket_levels[index]
	if not inside or level < 0 or level >= RULES.ELEVATION_LEVELS:
		return false
	for cell in result.road:
		if block.has_point(cell):
			return false
	for cell in result.branch:
		if block.has_point(cell):
			return false
	for rect in blocked:
		if block.intersects(rect):
			return false
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			if result.height_at(Vector2i(x, y)) != level:
				return false
	for other in result.sockets.size():
		if (
			other != index
			and not SectionSockets.blocks_apart(result.sockets[index], result.sockets[other])
		):
			return false
	return SectionSockets.off_band(result, block) and SectionSockets.reaches(result, block)


static func _covered(result: SectionResult, bend: Vector2i) -> bool:
	for anchor in result.sockets:
		if SectionSockets.centre_gap(anchor, bend) <= SectionSockets.bend_reach(result):
			return true
	return false


static func _has_low_nearby(results: Array[SectionResult], anchor: Vector2i) -> bool:
	for result in results:
		for index in result.sockets.size():
			var low: bool = result.socket_tags[index] != SectionResult.Tag.HIGH
			var gap := Vector2(anchor).distance_to(Vector2(result.sockets[index]))
			if low and gap <= VALLEY.HIGH_ALTERNATIVE_REACH:
				return true
	return false


static func _most_high(results: Array[SectionResult]) -> int:
	var best := 0
	var best_count := -1
	for result in results:
		var count := result.socket_tags.count(SectionResult.Tag.HIGH)
		if count > best_count:
			best = result.id
			best_count = count
	return best


## The feeder ends beside the road cell it joins, and every bridge stands on the road: the
## stitcher looks both up in the road, so a miss would give a corrupt route.
static func _link_problems(id: int, result: SectionResult) -> Array[Problem]:
	var found: Array[Problem] = []
	if not result.feeder.is_empty():
		var last := result.feeder[result.feeder.size() - 1]
		if not result.road.has(result.feeder_join):
			found.append(Problem.make(id, "the feeder joins %s, off the road" % result.feeder_join))
		elif (result.feeder_join - last).length_squared() != 1:
			found.append(Problem.make(id, "the feeder does not end beside %s" % result.feeder_join))
	for bridge in result.bridges:
		var lane := result.branch if bridge.on_branch else result.road
		if not lane.has(bridge.cell):
			found.append(Problem.make(id, "the bridge at %s is off the road" % bridge.cell))
	return found


## The sockets reach both lanes (#516): in a strip with the lower lane, `BRANCH_MIN_BLOCKS` blocks
## reach its own stretch and some block reaches each lane's bridge.
static func _lane_reach_problems(id: int, result: SectionResult) -> Array[Problem]:
	var found: Array[Problem] = []
	if result.branch.is_empty():
		return found
	var reaching := SectionSockets.blocks_reaching(result, SectionSockets.own_branch(result))
	if reaching < LAYOUT.BRANCH_MIN_BLOCKS:
		found.append(
			Problem.make(
				id,
				(
					"%d socket blocks reach the lower lane, want %d"
					% [reaching, LAYOUT.BRANCH_MIN_BLOCKS]
				)
			)
		)
	for on_branch in [false, true]:
		var span := SectionSockets.bridge_cells(result, on_branch)
		if not span.is_empty() and not SectionSockets.reaches_cells(result, span, result.sockets):
			var lane := "lower" if on_branch else "upper"
			found.append(Problem.make(id, "no socket block reaches the %s bridge" % lane))
	return found


## The fork's lane (#481) runs from the slot's `branch_entry` to its `branch_exit` in unit steps,
## inside the strip and on the valley floor; a strip without a branch in its slot has none.
static func _branch_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[Problem]:
	var found: Array[Problem] = []
	var lane := result.branch
	if not slot.has_branch():
		if not lane.is_empty():
			found.append(Problem.make(slot.id, "the strip has a branch its slot does not plan"))
		return found
	if lane.is_empty() or lane[0] != slot.branch_entry or lane[lane.size() - 1] != slot.branch_exit:
		return [Problem.make(slot.id, "the branch does not run from its entry to its exit")]
	for index in lane.size():
		if not slot.rect.has_point(lane[index]) or result.height_at(lane[index]) != 0:
			found.append(Problem.make(slot.id, "branch cell %s is outside the strip" % lane[index]))
		if index > 0 and (lane[index] - lane[index - 1]).length_squared() != 1:
			found.append(Problem.make(slot.id, "the branch jumps at %s" % lane[index]))
	return found


## A turn on the first or last cell of a section is no bend inside either road, so it is looked
## for on the whole road; a block of any section may cover it.
static func _join_bend_problems(results: Array[SectionResult], run: int) -> Array[Problem]:
	var found: Array[Problem] = []
	var path: Array[Vector2i] = []
	for result in results:
		path.append_array(result.road)
	for bend in SectionSockets.bends(path, run):
		for result in results:
			if result.road[0] != bend and result.road[result.road.size() - 1] != bend:
				continue
			if not _covered_anywhere(results, bend):
				found.append(
					Problem.make(result.id, "no socket block covers the join bend at %s" % bend)
				)
	return found


static func _covered_anywhere(results: Array[SectionResult], bend: Vector2i) -> bool:
	for result in results:
		if _covered(result, bend):
			return true
	return false


## Two stretches of the road that run side by side closer than `gap` cells (a hairpin or a snake
## of lanes): one problem per section whose road comes that near an earlier stretch.
static func _lane_problems(results: Array[SectionResult], gap: int, run: int) -> Array[Problem]:
	var cells: Array[Vector2i] = []
	var owners: Array[int] = []
	for result in results:
		for cell in result.road:
			cells.append(cell)
			owners.append(result.id)
	var found: Array[Problem] = []
	var reported := {}
	for later in range(run, cells.size()):
		if reported.has(owners[later]):
			continue
		for earlier in later - run + 1:
			var step := cells[later] - cells[earlier]
			if step.length_squared() < gap * gap:
				reported[owners[later]] = true
				found.append(
					Problem.make(
						owners[later],
						(
							"the road at %s runs %s from itself at %s"
							% [cells[later], step, cells[earlier]]
						)
					)
				)
				break
	return found
