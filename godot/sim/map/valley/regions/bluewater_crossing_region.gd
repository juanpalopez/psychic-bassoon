## Region 2, Bluewater Crossing (#409, epic #404): the middle of the valley, where the winding
## river meets the road. The road runs level into the river on its entry row, crosses it head on
## once on a road bridge (a bridge per wet road cell) and bends away to the exit on the far bank.
## With the fork (#481) the lower lane crosses on a bridge of its own, and foes and the hero use
## both bridges: a forked Crossing has no bridge for the hero only. An unforked one (a layout
## asked for without the fork) keeps its hero bridge on a row far from the road's. Socket blocks
## sit on both banks, off the river and off the hero bridge's approaches.
class_name BluewaterCrossingRegion
extends ValleySection

const BLUEWATER := preload("res://content/valley/bluewater_region_rules.gd")
const HALF := 0.5


func socket_range() -> Vector2i:
	return Vector2i(BLUEWATER.SOCKET_MIN, BLUEWATER.SOCKET_MAX)


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var row := slot.entry.y
	var curve := RoadSpline.build(waypoints(slot, _span(slot.river, row)))
	result.road = curve.cells
	result.road_curve = curve
	if slot.has_branch():
		var lane := RoadSpline.build(slot.branch_spine)
		result.branch = lane.cells
		result.branch_curve = lane
	var hero: Array[Vector2i] = []
	var hero_row := -1
	if not slot.has_branch():
		hero_row = _hero_row(slot, rng, row)
		hero = _row_cells(slot.river, hero_row)
	var blocked := reserved(slot)
	for cell in slot.river:
		result.river.append(cell)
		var wet_road := curve.cells.has(cell)
		var wet_lane := result.branch.has(cell)
		result.set_walkable(cell, wet_road or wet_lane or hero.has(cell))
		blocked.append(Rect2i(cell, Vector2i.ONE))
		if wet_road or wet_lane:
			var bridge := GameMap.Bridge.new()
			bridge.cell = cell
			bridge.on_branch = wet_lane
			result.bridges.append(bridge)
	result.hero_bridges = hero
	if not hero.is_empty():
		var span := _span(hero, hero_row)
		var keep: int = BLUEWATER.HERO_APPROACH_KEEP
		blocked.append(Rect2i(span.x - keep, hero_row, span.y - span.x + 1 + 2 * keep, 1))
	_place_sockets(result, rng, blocked)
	_tag_banks(result)
	return result


func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var found: Array[String] = []
	var wet: Array[int] = []
	for index in result.road.size():
		if result.river.has(result.road[index]):
			wet.append(index)
	if wet.is_empty() or wet[-1] - wet[0] != wet.size() - 1:
		return ["the road must meet the river in exactly one stretch"]
	var spans := result.bridges.filter(
		func(bridge: GameMap.Bridge) -> bool: return not bridge.on_branch
	)
	if spans.size() != wet.size():
		found.append("the road bridge must span every wet road cell")
	var lane_wet := result.branch.filter(
		func(cell: Vector2i) -> bool: return result.river.has(cell)
	)
	if result.bridges.size() != spans.size() + lane_wet.size():
		found.append("the lane's bridge must span every wet lane cell")
	var level := result.road[wet[0]].y
	if slot.has_branch() and not lane_wet.is_empty():
		if absi(lane_wet[0].y - level) < BLUEWATER.HERO_BRIDGE_MIN_ROW_GAP:
			found.append("the two bridges are too near each other")
	var reach: int = BLUEWATER.APPROACH_STRAIGHT
	if wet[0] < reach or wet[-1] + reach >= result.road.size():
		return ["the road has no room for straight approaches"]
	for step in range(1, reach + 1):
		var before := result.road[wet[0] - step]
		var after := result.road[wet[-1] + step]
		if before != result.road[wet[0]] + Vector2i.LEFT * step or after.y != level:
			found.append("the bridge approaches are not straight")
			break
		if after != result.road[wet[-1]] + Vector2i.RIGHT * step:
			found.append("the bridge approaches are not straight")
			break
	# the fork's two bridges are the hero's crossings too, so only an unforked crossing has a
	# bridge of its own (#481)
	if slot.has_branch() and not result.hero_bridges.is_empty():
		found.append("a forked crossing has no hero bridge")
	elif not slot.has_branch() and result.hero_bridges.is_empty():
		found.append("the river has no hero bridge")
	for cell in result.hero_bridges:
		if (
			not result.river.has(cell)
			or result.road.has(cell)
			or result.branch.has(cell)
			or not result.is_walkable(cell)
		):
			found.append("the hero bridge is not a walkable river cell off the road")
			break
		if absi(cell.y - level) < BLUEWATER.HERO_BRIDGE_MIN_ROW_GAP:
			found.append("the hero bridge is too near the road bridge")
			break
	for cell in result.river:
		var open := (
			result.road.has(cell) or result.branch.has(cell) or result.hero_bridges.has(cell)
		)
		if result.is_walkable(cell) != open:
			found.append("river cell %s is walkable off the bridges" % cell)
			break
	for anchor in result.sockets:
		var block := Rect2i(
			anchor, Vector2i(RULES.GAME_SOCKET_FOOTPRINT, RULES.GAME_SOCKET_FOOTPRINT)
		)
		if result.river.any(func(cell: Vector2i) -> bool: return block.has_point(cell)):
			found.append("a socket sits on the river")
			break
	if slot.river.is_empty():
		found.append("the region has no river")
	return found


## The road's waypoints, which the layout also gives the slot as its spine (`RouteComposer`): a
## bridge level with the entry row, then a bend to the exit.
static func waypoints(slot: ValleyPlan.Slot, span: Vector2i) -> Array[Vector2]:
	return RouteComposer.crossing_waypoints(slot, span).points


## The first and last column of the river cells in a row, or (0, -1) when the row has none.
static func _span(cells: Array[Vector2i], row: int) -> Vector2i:
	var found := _row_cells(cells, row)
	if found.is_empty():
		return Vector2i(0, -1)
	return Vector2i(found[0].x, found[-1].x)


static func _row_cells(cells: Array[Vector2i], row: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell in cells:
		if cell.y == row:
			found.append(cell)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return found


## A row for the hero's bridge: far from the road's, off the region's edges, with river on it.
func _hero_row(slot: ValleyPlan.Slot, rng: Rng, road_row: int) -> int:
	var rows: Array[int] = []
	var edge: int = BLUEWATER.HERO_BRIDGE_EDGE
	var gap: int = BLUEWATER.HERO_BRIDGE_MIN_ROW_GAP
	for y in range(slot.rect.position.y + edge, slot.rect.end.y - edge):
		if absi(y - road_row) >= gap and _span(slot.river, y).y >= 0:
			rows.append(y)
	if rows.is_empty():
		return -1
	return rows[rng.next_int(rows.size())]


## Places the blocks, drawing again (a new shuffle of the sites) until the count is in range and,
## when the west bank has room for a block, one stands on it.
func _place_sockets(result: SectionResult, rng: Rng, blocked: Array[Rect2i]) -> void:
	var bank_x: int = result.bridges[0].cell.x if not result.bridges.is_empty() else 0
	var west := SectionSockets.candidates(result, blocked).any(
		func(site: Vector2i) -> bool: return site.x < bank_x
	)
	for attempt in BLUEWATER.PLACE_TRIES:
		result.sockets.clear()
		result.socket_levels.clear()
		result.socket_tags.clear()
		SectionSockets.place(result, socket_range(), rng, blocked)
		var on_west := result.sockets.any(func(anchor: Vector2i) -> bool: return anchor.x < bank_x)
		if result.sockets.size() >= BLUEWATER.SOCKET_MIN and (on_west or not west):
			return


func _tag_banks(result: SectionResult) -> void:
	var size: int = RULES.GAME_SOCKET_FOOTPRINT
	for index in result.sockets.size():
		var reach := Rect2i(result.sockets[index], Vector2i(size, size)).grow(BLUEWATER.BANK_REACH)
		if result.socket_tags[index] != SectionResult.Tag.LOW:
			continue
		for cell in result.river:
			if reach.has_point(cell):
				result.socket_tags[index] = SectionResult.Tag.BANK
				break
