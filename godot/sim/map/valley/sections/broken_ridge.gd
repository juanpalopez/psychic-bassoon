## Section B, Broken Ridge (#387): a plateau beside the road. One socket block stands on the ridge
## (terrace 2, the range bonus), stepped down towards the road, with cliffs on its far side that
## no hero can climb and a ramp from the road onto the top. The other blocks stay on the floor.
class_name BrokenRidge
extends ValleySection

const RIDGE := preload("res://content/valley/broken_ridge_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func socket_range() -> Vector2i:
	return Vector2i(RIDGE.SOCKETS_LEAST, RIDGE.SOCKETS_MOST)


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var road := _road(slot, rng)
	var probe := SectionResult.create(slot)
	probe.road = road
	var sites := SectionSockets.candidates(probe, reserved(slot))
	for i in range(sites.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := sites[i]
		sites[i] = sites[j]
		sites[j] = held
	var result := probe
	for index in mini(sites.size(), RIDGE.RIDGE_TRIES):
		result = _build(slot, road, sites[index], rng)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	return result


## Checks only this section has: the ridge block's terrace, its ramp and its cliffs.
func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	return _problems(slot, result)


func _problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var found: Array[String] = []
	var high := 0
	for index in result.sockets.size():
		if result.socket_tags[index] != SectionResult.Tag.HIGH:
			continue
		high += 1
		if result.socket_levels[index] != RIDGE.RIDGE_LEVEL:
			found.append("high block %s is not on the ridge level" % result.sockets[index])
		if not _has_ramp(slot, result, _block(result.sockets[index])):
			found.append("no ramp onto the ridge beside %s" % result.sockets[index])
	if high < 1 or high > RIDGE.HIGH_SOCKETS:
		found.append("%d high blocks, want 1 to %d" % [high, RIDGE.HIGH_SOCKETS])
	for cell in _cliffs(result):
		if result.is_walkable(cell) or result.region_at(cell) != GameMap.Region.ROCKS:
			found.append("cliff cell %s is not blocked rock" % cell)
		if _near_road(result, cell, 1):
			found.append("cliff cell %s touches the road" % cell)
	return found


## The road leaves the entry along its row, climbs or drops to a far row (the longer the run, the
## more socket sites it has in a strip this narrow), crosses to a second column and on to the exit.
func _road(slot: ValleyPlan.Slot, rng: Rng) -> Array[Vector2i]:
	var road: Array[Vector2i] = []
	var left := slot.rect.position.x
	var right := slot.rect.end.x - 1
	var first := left + rng.next_int(slot.rect.size.x - RIDGE.COLUMN_GAP)
	var second := maxi(first + RIDGE.COLUMN_GAP, right - rng.next_int(RIDGE.EXIT_SLACK + 1))
	var far := _far_row(slot, rng)
	for x in range(slot.entry.x, first + 1):
		road.append(Vector2i(x, slot.entry.y))
	_run(road, Vector2i(first, far))
	for x in range(first + 1, second + 1):
		road.append(Vector2i(x, far))
	_run(road, Vector2i(second, slot.exit.y))
	for x in range(second + 1, slot.exit.x + 1):
		road.append(Vector2i(x, slot.exit.y))
	return road


## Appends the cells of a vertical run from the road's last cell to the target's row.
func _run(road: Array[Vector2i], target: Vector2i) -> void:
	var row := road[road.size() - 1].y
	while row != target.y:
		row += signi(target.y - row)
		road.append(Vector2i(target.x, row))


## A row far from both gates (most distant first, a near tie drawn at random).
func _far_row(slot: ValleyPlan.Slot, rng: Rng) -> int:
	var low := VALLEY.GATE_MARGIN
	var high := slot.rect.end.y - 1 - VALLEY.GATE_MARGIN
	var best := -1
	var rows: Array[int] = []
	for row in range(low, high + 1):
		var gap := mini(absi(row - slot.entry.y), absi(row - slot.exit.y))
		if gap > best:
			best = gap
			rows.clear()
		if gap == best:
			rows.append(row)
	return rows[rng.next_int(rows.size())]


func _build(
	slot: ValleyPlan.Slot, road: Array[Vector2i], ridge: Vector2i, rng: Rng
) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = road
	result.add_socket(ridge, RIDGE.RIDGE_LEVEL, SectionResult.Tag.HIGH)
	SectionSockets.place(result, socket_range(), rng, reserved(slot))
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
	# the hero climbs the ramp, not the block's face
	for dy in block.size.y:
		for dx in block.size.x:
			result.set_walkable(block.position + Vector2i(dx, dy), false)
	for cell in road:
		for side in SIDES:
			var next: Vector2i = cell + side
			if result.has_cell(next) and not road.has(next) and not _in_block(result, next):
				result.set_region(next, GameMap.Region.DIRT)
	return result


## The terrace of one cell: ridge top near the block (a step down beside the road), the foot of
## the ridge a step down again, or the floor when the foot is far from the road (a cliff).
func _shape(result: SectionResult, cell: Vector2i, block: Rect2i) -> void:
	if result.road.has(cell) or _in_block(result, cell):
		return
	var ring := _ring(cell, block)
	var level: int = RIDGE.FLOOR_LEVEL
	if ring <= RIDGE.TOP_RING:
		level = RIDGE.RIDGE_LEVEL
		if _near_road(result, cell, RIDGE.ROAD_CLEARANCE):
			level = RIDGE.STEP_LEVEL
	elif ring <= RIDGE.FOOT_RING:
		level = RIDGE.STEP_LEVEL
		if not _near_road(result, cell, RIDGE.ROAD_CLEARANCE):
			level = RIDGE.FLOOR_LEVEL
	result.set_height(cell, level)


## The cells beside a drop of two terraces or more that are not socket blocks.
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
					and absi(result.height_at(next) - result.height_at(cell)) >= RIDGE.RIDGE_LEVEL
				):
					found.append(cell)
					break
	return found


## True when a hero can walk from the road to a ridge-top cell beside the block, one terrace a step.
func _has_ramp(slot: ValleyPlan.Slot, result: SectionResult, block: Rect2i) -> bool:
	var seen := {result.road[0]: true}
	var open: Array[Vector2i] = [result.road[0]]
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		for side in SIDES:
			var next: Vector2i = cell + side
			if seen.has(next) or not slot.rect.has_point(next) or block.has_point(next):
				continue
			if not result.is_walkable(next):
				continue
			if absi(result.height_at(next) - result.height_at(cell)) > 1:
				continue
			seen[next] = true
			open.append(next)
	for dy in block.size.y:
		for dx in block.size.x:
			for side in SIDES:
				var beside: Vector2i = block.position + Vector2i(dx, dy) + side
				if (
					seen.has(beside)
					and not block.has_point(beside)
					and result.height_at(beside) == RIDGE.RIDGE_LEVEL
				):
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


func _near_road(result: SectionResult, cell: Vector2i, reach: int) -> bool:
	for road_cell in result.road:
		if maxi(absi(road_cell.x - cell.x), absi(road_cell.y - cell.y)) <= reach:
			return true
	return false
