## Region 3, Broken Ridge: the high ground, top middle (#410). A plateau with one high block,
## stepped down towards the layout's spline road, with cliffs on its far side and a ramp.
class_name BrokenRidgeRegion
extends ValleySection

const REGION := preload("res://content/valley/broken_ridge_region_rules.gd")
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Low blocks first (the plateau must not take their room), then each site for the high block.
func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var road := RoadSpline.build(slot.spine).cells
	var result: SectionResult = null
	for _try in REGION.LOW_TRIES:
		result = _try_lows(slot, road, rng)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	_close_river(slot, result)
	result.road_curve = RoadSpline.build(slot.spine)
	return result


func _try_lows(slot: ValleyPlan.Slot, road: Array[Vector2i], rng: Rng) -> SectionResult:
	var base := SectionResult.create(slot)
	base.road = road
	SectionSockets.place(base, REGION.LOW_BLOCKS, rng, reserved(slot))
	var sites := SectionSockets.candidates(base, reserved(slot))
	for i in range(sites.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := sites[i]
		sites[i] = sites[j]
		sites[j] = held
	var result := base
	for site in sites:
		if not SectionSockets.keeps_distance(site, base.sockets):
			continue
		result = _finish(slot, base, site)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	return result


func socket_range() -> Vector2i:
	return Vector2i(REGION.SOCKETS_LEAST, REGION.SOCKETS_MOST)


## Blocks stay off the river as well.
func reserved(slot: ValleyPlan.Slot) -> Array[Rect2i]:
	var blocked := super.reserved(slot)
	for cell in slot.river:
		blocked.append(Rect2i(cell, Vector2i.ONE))
	return blocked


func _finish(slot: ValleyPlan.Slot, base: SectionResult, ridge: Vector2i) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = base.road
	result.add_socket(ridge, REGION.RIDGE_LEVEL, SectionResult.Tag.HIGH)
	for index in base.sockets.size():
		result.add_socket(base.sockets[index], 0, base.socket_tags[index])
	var block := _block(ridge)
	for y in range(slot.rect.position.y, slot.rect.end.y):
		for x in range(slot.rect.position.x, slot.rect.end.x):
			_shape(result, Vector2i(x, y), block)
	for index in result.sockets.size():
		var seat := _block(result.sockets[index])
		for dy in seat.size.y:
			for dx in seat.size.x:
				result.set_height(seat.position + Vector2i(dx, dy), result.socket_levels[index])
	for cell in _cliffs(result):
		result.set_region(cell, GameMap.Region.ROCKS)
		result.set_walkable(cell, false)
	for dy in block.size.y:
		for dx in block.size.x:
			result.set_walkable(block.position + Vector2i(dx, dy), false)
	_close_river(slot, result)
	return result


## The river's cells, closed to the hero (once).
func _close_river(slot: ValleyPlan.Slot, result: SectionResult) -> void:
	if not result.river.is_empty():
		return
	for cell in slot.river:
		result.river.append(cell)
		result.set_walkable(cell, false)


## Terraces rise with the distance from the road inside the ring around the high block and fall
## towards other blocks, so a cliff stands only on the far rim.
func _shape(result: SectionResult, cell: Vector2i, block: Rect2i) -> void:
	if result.road.has(cell) or _in_block(result, cell):
		return
	var level := 0
	if _ring(cell, block) <= REGION.PLATEAU_RING:
		level = REGION.RIDGE_LEVEL
		for road_cell in result.road:
			level = mini(level, maxi(absi(road_cell.x - cell.x), absi(road_cell.y - cell.y)))
		for anchor in result.sockets:
			if anchor != block.position:
				level = mini(level, _ring(cell, _block(anchor)))
	result.set_height(cell, level)


## Checks only this section has: one high block on the ridge level with a ramp up to it.
func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var high := result.socket_tags.find(SectionResult.Tag.HIGH)
	if high < 0 or result.socket_tags.count(SectionResult.Tag.HIGH) != 1:
		return ["want exactly one high block"]
	if result.socket_levels[high] != REGION.RIDGE_LEVEL:
		return ["the high block is not on the ridge level"]
	if not _has_ramp(slot, result, _block(result.sockets[high])):
		return ["no ramp onto the ridge beside %s" % result.sockets[high]]
	return []


## Cells at the top of a drop of two terraces or more (the rim; the foot stays walkable).
func _cliffs(result: SectionResult) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var rect := result.rect
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if result.road.has(cell) or _in_block(result, cell):
				continue
			for side in SIDES:
				var next: Vector2i = cell + side
				if (
					result.has_cell(next)
					and not _in_block(result, next)
					and result.height_at(cell) - result.height_at(next) >= REGION.RIDGE_LEVEL
				):
					found.append(cell)
					break
	return found


## True when a hero can walk from the road to a ridge-top cell beside the block.
func _has_ramp(slot: ValleyPlan.Slot, result: SectionResult, block: Rect2i) -> bool:
	var seen := {result.road[0]: true}
	var open: Array[Vector2i] = [result.road[0]]
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for side in SIDES:
			var next: Vector2i = cell + side
			if (
				not seen.has(next)
				and slot.rect.has_point(next)
				and not block.has_point(next)
				and result.is_walkable(next)
				and absi(result.height_at(next) - result.height_at(cell)) <= 1
			):
				seen[next] = true
				open.append(next)
	for cell in seen:
		if result.height_at(cell) == REGION.RIDGE_LEVEL and _ring(cell, block) == 1:
			return true
	return false


func _block(anchor: Vector2i) -> Rect2i:
	return Rect2i(anchor, Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT)


func _in_block(result: SectionResult, cell: Vector2i) -> bool:
	for anchor in result.sockets:
		if _block(anchor).has_point(cell):
			return true
	return false


## Chebyshev distance from a cell to a block (0 inside it).
func _ring(cell: Vector2i, block: Rect2i) -> int:
	var dx := maxi(maxi(block.position.x - cell.x, cell.x - (block.end.x - 1)), 0)
	var dy := maxi(maxi(block.position.y - cell.y, cell.y - (block.end.y - 1)), 0)
	return maxi(dx, dy)
