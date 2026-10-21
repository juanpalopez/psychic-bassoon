## Region 1, Sunken Meadow: the open meadow, bottom left (#410). One large walkable area the
## spline road wanders through in wide bends, a few boulder clusters that never cut the walkable
## ground, low rises (terrace 1) and four or five socket blocks around the road.
class_name SunkenMeadowRegion
extends ValleySection

const MEADOW := preload("res://content/valley/sunken_meadow_region_rules.gd")


## Draws the sockets, boulders and rises a few times from the one stream and keeps the first set
## that passes the section's checks (else the last, which the stitcher draws again).
func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result: SectionResult = null
	for _try in MEADOW.TRIES:
		result = _draw(slot, rng)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	return result


func socket_range() -> Vector2i:
	return Vector2i(MEADOW.SOCKETS_LEAST, MEADOW.SOCKETS_MOST)


## The walkable ground joined to the entry is large and holds every walkable cell of the region.
func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var walkable := 0
	for y in range(slot.rect.position.y, slot.rect.end.y):
		for x in range(slot.rect.position.x, slot.rect.end.x):
			walkable += 1 if result.is_walkable(Vector2i(x, y)) else 0
	var seen := {slot.entry: true}
	var queue: Array[Vector2i] = [slot.entry]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if slot.rect.has_point(next) and not seen.has(next) and result.is_walkable(next):
				seen[next] = true
				queue.append(next)
	if seen.size() < MEADOW.MIN_OPEN_AREA or seen.size() != walkable:
		return ["the open area is %d of %d walkable cells" % [seen.size(), walkable]]
	return []


func _draw(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var curve := RoadSpline.build(slot.spine)
	result.road = curve.cells
	result.road_curve = curve
	var taken := {}
	for cell in curve.cells:
		result.set_region(cell, GameMap.Region.DIRT)
		taken[cell] = true
	var blocked := reserved(slot)
	for cell in slot.river:
		result.river.append(cell)
		result.set_walkable(cell, false)
		blocked.append(Rect2i(cell, Vector2i.ONE))
		taken[cell] = true
	SectionSockets.place(result, socket_range(), rng, blocked)
	for anchor in result.sockets:
		for dy in 2:
			for dx in 2:
				taken[anchor + Vector2i(dx, dy)] = true
	_boulders(slot, result, rng, taken)
	_rises(slot, result, rng, taken)
	return result


## Rock clusters in the open, each ringed by free cells.
func _boulders(slot: ValleyPlan.Slot, result: SectionResult, rng: Rng, taken: Dictionary) -> void:
	var want: int = (
		MEADOW.BOULDER_CLUSTERS.x
		+ rng.next_int(MEADOW.BOULDER_CLUSTERS.y - MEADOW.BOULDER_CLUSTERS.x + 1)
	)
	for _cluster in want:
		for _try in MEADOW.BOULDER_TRIES:
			var cells := _patch(slot, rng, rng.next_int(MEADOW.BOULDER_SIDE) + 1, 1, taken)
			if cells.is_empty():
				continue
			for cell in cells:
				taken[cell] = true
				result.set_region(cell, GameMap.Region.ROCKS)
				result.set_walkable(cell, false)
			break


## Low rises of one terrace, away from the road and the blocks.
func _rises(slot: ValleyPlan.Slot, result: SectionResult, rng: Rng, taken: Dictionary) -> void:
	var want: int = MEADOW.RISES.x + rng.next_int(MEADOW.RISES.y - MEADOW.RISES.x + 1)
	for _rise in want:
		for _try in MEADOW.RISE_TRIES:
			var cells := _patch(slot, rng, MEADOW.RISE_SIDE, 0, taken)
			for cell in cells:
				result.set_height(cell, MEADOW.RISE_LEVEL)
				taken[cell] = true
			if not cells.is_empty():
				break


## A random `side` by `side`-ish patch (the second side drawn too) clear of `taken` by
## one cell and `edge` cells from the region's edge, or no cells.
func _patch(
	slot: ValleyPlan.Slot, rng: Rng, side: int, edge: int, taken: Dictionary
) -> Array[Vector2i]:
	var width := side
	var height := 1 + rng.next_int(side)
	var rect := slot.rect
	var x := rect.position.x + edge + rng.next_int(rect.size.x - width - 2 * edge + 1)
	var y := rect.position.y + edge + rng.next_int(rect.size.y - height - 2 * edge + 1)
	var cells: Array[Vector2i] = []
	for dy in height:
		for dx in width:
			var cell := Vector2i(x + dx, y + dy)
			for ny in range(-1, 2):
				for nx in range(-1, 2):
					if taken.has(cell + Vector2i(nx, ny)):
						return []
			cells.append(cell)
	return cells
