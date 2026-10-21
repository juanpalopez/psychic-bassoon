## Region 3, Broken Ridge: the high ground, top middle (#410). The strip ridge's plateau (one
## high block stepped down towards the road, cliffs on its far side, a ramp from the road) on
## the layout's spline road, with the river's cells closed to the hero and to socket blocks.
class_name BrokenRidgeRegion
extends BrokenRidge

const REGION := preload("res://content/valley/broken_ridge_region_rules.gd")


## The low blocks are placed first (so the plateau does not take their room), then each site is
## tried for the one high block; a few placements of the low blocks are tried before the last try
## is returned for the stitcher to draw again.
func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var road := _road(slot, rng)
	var result: SectionResult = null
	for _try in REGION.LOW_TRIES:
		result = _try_lows(slot, road, rng)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	_close_river(slot, result)
	result.road_curve = RoadSpline.build(slot.spine)
	return result


## One placement of the low blocks and the first high site that passes the checks (else the last).
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


## The road is the spline through the layout's spine, not the strip's two-column run.
func _road(slot: ValleyPlan.Slot, _rng: Rng) -> Array[Vector2i]:
	return RoadSpline.build(slot.spine).cells


## The low blocks of `base` plus the high block at `ridge`, with the plateau, its cliffs, the
## river's cells and the dirt beside the road.
func _finish(slot: ValleyPlan.Slot, base: SectionResult, ridge: Vector2i) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = base.road
	result.add_socket(ridge, RIDGE.RIDGE_LEVEL, SectionResult.Tag.HIGH)
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
	# the hero climbs the ramp, not the block's face
	for dy in block.size.y:
		for dx in block.size.x:
			result.set_walkable(block.position + Vector2i(dx, dy), false)
	for cell in result.road:
		for side in SIDES:
			var next: Vector2i = cell + side
			if result.has_cell(next) and not result.road.has(next) and not _in_block(result, next):
				result.set_region(next, GameMap.Region.DIRT)
	_close_river(slot, result)
	return result


## The river's cells, closed to the hero (once).
func _close_river(slot: ValleyPlan.Slot, result: SectionResult) -> void:
	if not result.river.is_empty():
		return
	for cell in slot.river:
		result.river.append(cell)
		result.set_walkable(cell, false)


## The plateau: terraces rise with the distance from the road inside the ring around the high
## block, and fall towards any other block, so a cliff stands only on the far rim.
func _shape(result: SectionResult, cell: Vector2i, block: Rect2i) -> void:
	if result.road.has(cell) or _in_block(result, cell):
		return
	var level := 0
	if _ring(cell, block) <= REGION.PLATEAU_RING:
		level = RIDGE.RIDGE_LEVEL
		for road_cell in result.road:
			level = mini(level, maxi(absi(road_cell.x - cell.x), absi(road_cell.y - cell.y)))
		for anchor in result.sockets:
			if anchor != block.position:
				level = mini(level, _ring(cell, _block(anchor)))
	result.set_height(cell, level)
