## The rules a valley must meet (#381). Each returns the problems it finds, each naming the
## section to draw again; none means the section (or the whole valley) passes.
class_name ValleyChecks
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")


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
	found.append_array(valley_problems(results))
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
	if not found.is_empty():
		return found
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
	for bend in SectionSockets.bends(road):
		if not _covered(result, bend):
			found.append(Problem.make(id, "no socket block covers the bend at %s" % bend))
	for text in section.extra_problems(slot, result):
		found.append(Problem.make(id, text))
	return found


## Across the whole valley: blocks of neighbouring strips keep their gap, high ground stays
## scarce and each high socket has a low one to fall back on.
static func valley_problems(results: Array[SectionResult]) -> Array[Problem]:
	var found: Array[Problem] = []
	var all: Array[Vector2i] = []
	var owner: Array[int] = []
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
			owner.append(result.id)
			high += 1 if result.socket_tags[index] == SectionResult.Tag.HIGH else 0
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
	return found


static func _block_fits(
	slot: ValleyPlan.Slot, result: SectionResult, block: Rect2i, index: int, blocked: Array[Rect2i]
) -> bool:
	var inside := (
		slot.rect.encloses(block) and block.end.x <= slot.rect.end.x - VALLEY.STRIP_RIGHT_MARGIN
	)
	var level: int = result.socket_levels[index]
	if not inside or level < 0 or level >= RULES.ELEVATION_LEVELS:
		return false
	for cell in result.road:
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
	return SectionSockets.reaches_road(block, result.road)


static func _covered(result: SectionResult, bend: Vector2i) -> bool:
	for anchor in result.sockets:
		if SectionSockets.centre_gap(anchor, bend) <= VALLEY.BEND_COVER_REACH:
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
