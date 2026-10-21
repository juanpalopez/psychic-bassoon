## Section D, Sunken Meadow: the open meadow the hero crosses. No cliffs and no river; the road
## wanders through it in two long vertical runs, with dirt along its edge.
class_name SunkenMeadow
extends ValleySection

const VALLEY := preload("res://content/valley/valley_rules.gd")
const MEADOW := preload("res://content/valley/sunken_meadow_rules.gd")


## Draws the road a few times from the one stream and keeps the first whose sockets fit: the
## strip is narrow, so some roads leave no room for the blocks.
func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var best: SectionResult = null
	for _try in MEADOW.ROAD_TRIES:
		var result := _draw(slot, rng)
		if _sockets_fit(result):
			return result
		if best == null or result.sockets.size() > best.sockets.size():
			best = result
	return best


func _draw(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var left := slot.rect.position.x
	var width := slot.rect.size.x
	# Two turns columns, c1 < c2, so the legs never cross.
	var first := left + 1 + rng.next_int(width - 2)
	var second := first + 1 + rng.next_int(slot.exit.x - first)
	var far := _far_row(slot, rng)
	_leg(result, Vector2i(left, slot.entry.y), Vector2i(first, slot.entry.y))
	_leg(result, Vector2i(first, slot.entry.y), Vector2i(first, far))
	_leg(result, Vector2i(first, far), Vector2i(second, far))
	_leg(result, Vector2i(second, far), Vector2i(second, slot.exit.y))
	_leg(result, Vector2i(second, slot.exit.y), slot.exit)
	for cell in result.road:
		result.set_region(cell, GameMap.Region.DIRT)
	SectionSockets.place(result, socket_range(), rng, reserved(slot))
	return result


func socket_range() -> Vector2i:
	return Vector2i(MEADOW.SOCKET_LEAST, MEADOW.SOCKET_MOST)


func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var open := 0
	var seen := {}
	var queue: Array[Vector2i] = [slot.entry]
	seen[slot.entry] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		open += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if slot.rect.has_point(next) and not seen.has(next) and result.is_walkable(next):
				seen[next] = true
				queue.append(next)
	if open < MEADOW.MIN_OPEN_AREA:
		return ["the meadow's open area is %d cells, want %d" % [open, MEADOW.MIN_OPEN_AREA]]
	return []


## True when the blocks are enough and cover every bend.
func _sockets_fit(result: SectionResult) -> bool:
	if result.sockets.size() < socket_range().x:
		return false
	for bend in SectionSockets.bends(result.road):
		var covered := false
		for anchor in result.sockets:
			covered = covered or SectionSockets.centre_gap(anchor, bend) <= VALLEY.BEND_COVER_REACH
		if not covered:
			return false
	return true


## The row of the middle leg: away from the gate rows so the road wanders.
static func _far_row(slot: ValleyPlan.Slot, rng: Rng) -> int:
	var rows: Array[int] = []
	for row in range(
		slot.rect.position.y + MEADOW.WANDER_EDGE_MARGIN,
		slot.rect.end.y - MEADOW.WANDER_EDGE_MARGIN
	):
		if (
			absi(row - slot.entry.y) >= MEADOW.WANDER_MIN_ROWS
			and absi(row - slot.exit.y) >= MEADOW.WANDER_MIN_ROWS
		):
			rows.append(row)
	return rows[rng.next_int(rows.size())]


## Appends the straight leg from `from` to `to` (the shared first cell only once).
static func _leg(result: SectionResult, from: Vector2i, to: Vector2i) -> void:
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var cell := from
	if result.road.is_empty():
		result.road.append(cell)
	while cell != to:
		cell += step
		result.road.append(cell)
