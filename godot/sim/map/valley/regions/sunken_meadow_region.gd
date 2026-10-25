## Region 1, Sunken Meadow: the open meadow, bottom left (#410). One large walkable area the
## spline road wanders through in wide bends, a few boulder clusters that never cut the walkable
## ground and four or five socket blocks around the road.
class_name SunkenMeadowRegion
extends ValleySection

const MEADOW := preload("res://content/valley/sunken_meadow_region_rules.gd")


## Draws the sockets and boulders a few times from the one stream and keeps the first set
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


func _draw(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var curve := RoadSpline.build(slot.spine)
	result.road = curve.cells
	result.road_curve = curve
	var taken := {}
	for cell in curve.cells:
		result.set_region(cell, GameMap.Region.DIRT)
		taken[cell] = true
	if slot.has_branch():
		var lane := RoadSpline.build(slot.branch_spine)
		result.branch = lane.cells
		result.branch_curve = lane
		for cell in lane.cells:
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
	return result


## Rock clusters in the open, each ringed by free cells.
func _boulders(slot: ValleyPlan.Slot, result: SectionResult, rng: Rng, taken: Dictionary) -> void:
	var want: int = (
		MEADOW.BOULDER_CLUSTERS.x
		+ rng.next_int(MEADOW.BOULDER_CLUSTERS.y - MEADOW.BOULDER_CLUSTERS.x + 1)
	)
	for _cluster in want:
		for _try in MEADOW.BOULDER_TRIES:
			var cells := _patch(slot, rng, rng.next_int(MEADOW.BOULDER_SIDE) + 1, taken)
			if cells.is_empty():
				continue
			for cell in cells:
				taken[cell] = true
				result.set_region(cell, GameMap.Region.ROCKS)
				result.set_walkable(cell, false)
			break


## A random `side` by `side`-ish patch (the second side drawn too) clear of `taken` by
## one cell and one cell from the region's edge, or no cells.
func _patch(slot: ValleyPlan.Slot, rng: Rng, side: int, taken: Dictionary) -> Array[Vector2i]:
	var width := side
	var height := 1 + rng.next_int(side)
	var rect := slot.rect
	var x := rect.position.x + 1 + rng.next_int(rect.size.x - width - 1)
	var y := rect.position.y + 1 + rng.next_int(rect.size.y - height - 1)
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
