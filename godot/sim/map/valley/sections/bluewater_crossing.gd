## Section C, Bluewater Crossing (#386): a river flows down the strip and the road crosses it head
## on, once, on a bridge (the chokepoint; its guard post is #323). A second walkable bridge, far
## from the road, is for the hero only. Sockets sit on both banks.
class_name BluewaterCrossing
extends ValleySection

const VALLEY := preload("res://content/valley/valley_rules.gd")
const RIVER := preload("res://content/valley/bluewater_rules.gd")


func socket_range() -> Vector2i:
	return Vector2i(RIVER.SOCKET_MIN, RIVER.SOCKET_MAX)


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var rect := slot.rect
	var high := rect.end.x - 1 - RIVER.RIVER_RIGHT_OFFSET
	var low := rect.position.x + RIVER.RIVER_LEFT_OFFSET
	if rect.size.x <= RIVER.NARROW_STRIP:
		low += RIVER.NARROW_LEFT_EXTRA
	low = mini(low, high)
	var column := low + rng.next_int(high - low + 1)
	var bridge_row := _bridge_row(slot, rng)
	# The river may step sideways once, on a row clear of the road bridge.
	var jog_row := -1
	var shifted := column
	var clear: int = RIVER.RIVER_JOG_CLEARANCE
	if high > low and rng.next_int(100) < RIVER.RIVER_JOG_PERCENT:
		var row := rect.position.y + clear + rng.next_int(rect.size.y - 2 * clear)
		if absi(row - bridge_row) > clear:
			jog_row = row
			var step := 1 if column == low else (-1 if column == high else 1 - 2 * rng.next_int(2))
			shifted = column + step
	for y in range(rect.position.y, rect.end.y):
		if y == jog_row:
			result.river.append(Vector2i(column, y))
			result.river.append(Vector2i(shifted, y))
		else:
			result.river.append(Vector2i(_river_column(y, jog_row, column, shifted), y))
	var bridge_column := _river_column(bridge_row, jog_row, column, shifted)
	var hero := _hero_cell(rect, rng, bridge_row, jog_row, column, shifted)
	_draw_road(result, slot, rng, bridge_column, bridge_row)
	var bridge := GameMap.Bridge.new()
	bridge.cell = Vector2i(bridge_column, bridge_row)
	result.bridges.append(bridge)
	result.hero_bridges.append(hero)
	for cell in result.river:
		result.set_walkable(cell, cell == bridge.cell or cell == hero)
	var blocked := reserved(slot)
	for cell in result.river:
		blocked.append(Rect2i(cell, Vector2i.ONE))
	for dx in range(-RIVER.HERO_APPROACH_KEEP, RIVER.HERO_APPROACH_KEEP + 1):
		blocked.append(Rect2i(hero + Vector2i(dx, 0), Vector2i.ONE))
	SectionSockets.place(result, socket_range(), rng, blocked)
	_tag_banks(result)
	_shape_ground(result)
	return result


func extra_problems(_slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var found: Array[String] = []
	if result.bridges.size() != 1 or result.hero_bridges.size() != 1:
		return ["needs exactly one road bridge and one hero bridge"]
	var bridge := result.bridges[0]
	var hero := result.hero_bridges[0]
	var at := result.road.find(bridge.cell)
	if at < 1 or at >= result.road.size() - 1 or not result.river.has(bridge.cell):
		found.append("the road bridge is not on the road over the river")
	elif (
		result.road[at - 1] != bridge.cell + Vector2i.LEFT
		or result.road[at + 1] != bridge.cell + Vector2i.RIGHT
	):
		found.append("the bridge approaches are not straight")
	var crossings := 0
	for cell in result.road:
		if result.river.has(cell):
			crossings += 1
	if crossings != 1:
		found.append("the road meets the river %d times" % crossings)
	if not result.river.has(hero) or result.road.has(hero) or not result.is_walkable(hero):
		found.append("the hero bridge is not a walkable river cell off the road")
	elif absi(hero.y - bridge.cell.y) < RIVER.HERO_BRIDGE_MIN_ROW_GAP:
		found.append("the hero bridge is too near the road bridge")
	if not _river_unbroken(result):
		found.append("the river is broken")
	for anchor in result.sockets:
		for cell in result.river:
			if Rect2i(anchor, Vector2i(2, 2)).has_point(cell):
				found.append("a socket sits on the river")
				return found
	return found


## A row for the road's bridge that leaves long runs of road on both banks, for socket blocks.
func _bridge_row(slot: ValleyPlan.Slot, rng: Rng) -> int:
	var first := slot.rect.position.y + VALLEY.GATE_MARGIN
	var last := slot.rect.end.y - 1 - VALLEY.GATE_MARGIN
	var best := 0
	for y in range(first, last + 1):
		best = maxi(best, absi(y - slot.entry.y) + absi(y - slot.exit.y))
	var rows: Array[int] = []
	for y in range(first, last + 1):
		if absi(y - slot.entry.y) + absi(y - slot.exit.y) >= best - RIVER.BRIDGE_ROW_SLACK:
			rows.append(y)
	return rows[rng.next_int(rows.size())]


static func _river_column(y: int, jog_row: int, column: int, shifted: int) -> int:
	return column if jog_row < 0 or y < jog_row else shifted


static func _river_unbroken(result: SectionResult) -> bool:
	var river := result.river
	if river.is_empty() or river[0].y != result.rect.position.y:
		return false
	if river[river.size() - 1].y != result.rect.end.y - 1:
		return false
	for index in river.size() - 1:
		var step := river[index + 1] - river[index]
		if step != Vector2i.DOWN and step != Vector2i.LEFT and step != Vector2i.RIGHT:
			return false
	return true


## The hero's bridge: a river cell on a row far from the road bridge, away from the sideways step.
func _hero_cell(
	rect: Rect2i, rng: Rng, bridge_row: int, jog_row: int, column: int, shifted: int
) -> Vector2i:
	var rows: Array[int] = []
	for y in range(rect.position.y + 1, rect.end.y - 1):
		if absi(y - bridge_row) >= RIVER.HERO_BRIDGE_MIN_ROW_GAP and y != jog_row:
			rows.append(y)
	var row: int = rows[rng.next_int(rows.size())]
	return Vector2i(_river_column(row, jog_row, column, shifted), row)


## The road: along its entry row, up or down a column on the near bank, straight over the bridge,
## then down a column on the far bank and out along its exit row. It never touches the river
## elsewhere: both vertical runs keep clear of the river's columns.
func _draw_road(
	result: SectionResult, slot: ValleyPlan.Slot, rng: Rng, bridge_column: int, bridge_row: int
) -> void:
	var left := slot.rect.position.x
	var right := slot.rect.end.x - 1
	# Each run keeps room for a two-column block beside it, when the bank is wide enough.
	var near := left + rng.next_int(maxi(bridge_column - 3 - left, 0) + 1)
	var far_least := mini(bridge_column + 3, right)
	var far := far_least + rng.next_int(right - far_least + 1)
	if bridge_column + 3 > right:
		far = right
	result.road.append(slot.entry)
	for waypoint in [
		Vector2i(near, slot.entry.y),
		Vector2i(near, bridge_row),
		Vector2i(far, bridge_row),
		Vector2i(far, slot.exit.y),
		slot.exit,
	]:
		while result.road[result.road.size() - 1] != waypoint:
			var last := result.road[result.road.size() - 1]
			var delta: Vector2i = waypoint - last
			var step := Vector2i(signi(delta.x), 0) if delta.x != 0 else Vector2i(0, signi(delta.y))
			result.road.append(last + step)


func _tag_banks(result: SectionResult) -> void:
	for index in result.sockets.size():
		var reach := Rect2i(result.sockets[index], Vector2i(2, 2)).grow(RIVER.BANK_REACH)
		for cell in result.river:
			if reach.has_point(cell) and result.socket_tags[index] == SectionResult.Tag.LOW:
				result.socket_tags[index] = SectionResult.Tag.BANK


## The valley floor along the road and the river, one terrace higher beyond (forest there), and
## dirt beside the road. Socket blocks stay on the floor.
func _shape_ground(result: SectionResult) -> void:
	for y in range(result.rect.position.y, result.rect.end.y):
		for x in range(result.rect.position.x, result.rect.end.x):
			var cell := Vector2i(x, y)
			var road_gap := _gap(cell, result.road)
			var river_gap := _gap(cell, result.river)
			if road_gap == 1 and river_gap > 0:
				result.set_region(cell, GameMap.Region.DIRT)
			elif road_gap >= RIVER.SLOPE_ROAD_GAP and river_gap >= RIVER.SLOPE_RIVER_GAP:
				if not _in_socket(cell, result):
					result.set_height(cell, 1)
					result.set_region(cell, GameMap.Region.FOREST)


static func _in_socket(cell: Vector2i, result: SectionResult) -> bool:
	for anchor in result.sockets:
		if Rect2i(anchor, Vector2i(2, 2)).grow(1).has_point(cell):
			return true
	return false


## The Chebyshev distance to the nearest of `cells`.
static func _gap(cell: Vector2i, cells: Array[Vector2i]) -> int:
	var best := 1000
	for other in cells:
		best = mini(best, maxi(absi(cell.x - other.x), absi(cell.y - other.y)))
	return best
