## Section E, Ancient Fold (#388): ruins, and the secondary entrance that opens after wave 10.
## The feeder is a straight run from the board's top or bottom edge down to the main road; it
## joins before the Heartkeep Approach, and at least four socket blocks cover the join.
class_name AncientFold
extends ValleySection

const FOLD := preload("res://content/valley/ancient_fold_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var fallback := SectionResult.create(slot)
	fallback.road.assign(_road(slot, [slot.exit.x], [slot.exit.y]))
	for _try in FOLD.ROAD_TRIES:
		var road := _random_road(slot, rng)
		if road.is_empty():
			continue
		var feeders := _shuffled(_feeders(slot, road), rng)
		for feeder in feeders.slice(0, FOLD.FEEDERS_TRIED):
			var result := SectionResult.create(slot)
			result.road.assign(road)
			result.feeder.assign(feeder[0])
			result.feeder_join = feeder[1]
			_place_sockets(slot, rng, result)
			if _sockets_ok(result):
				_lay_ruins(rng, result)
				return result
	# no road worked: the plain one goes out as it is and `extra_problems` asks for another draw
	_lay_ruins(rng, fallback)
	return fallback


func socket_range() -> Vector2i:
	return Vector2i(FOLD.SOCKET_MIN, FOLD.SOCKET_MAX)


func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var found := _feeder_problems(slot.rect, result.road, result.feeder, result.feeder_join)
	var near := 0
	for anchor in result.sockets:
		near += 1 if _near_join(anchor, result.feeder_join) else 0
	if found.is_empty() and near < FOLD.MERGE_COVER_MIN:
		found.append("%d socket blocks cover the merge, want %d" % [near, FOLD.MERGE_COVER_MIN])
	return found


## A road that winds: `FOLD.LEGS_MIN` to `LEGS_MAX` extra horizontal legs, each reached by a
## vertical run at a drawn column, so a narrow strip has more road for socket blocks to touch.
## Empty when the road would cross itself.
func _random_road(slot: ValleyPlan.Slot, rng: Rng) -> Array[Vector2i]:
	var columns: Array[int] = []
	var rows: Array[int] = []
	var row := slot.entry.y
	var span := slot.rect.size.y - 2 * FOLD.MID_ROW_MARGIN
	for _leg in FOLD.LEGS_MIN + rng.next_int(FOLD.LEGS_MAX - FOLD.LEGS_MIN + 1):
		columns.append(slot.rect.position.x + rng.next_int(slot.rect.size.x))
		row = FOLD.MID_ROW_MARGIN + rng.next_int(span)
		rows.append(row)
	columns.append(slot.rect.position.x + rng.next_int(slot.rect.size.x))
	rows.append(slot.exit.y)
	var road := _road(slot, columns, rows)
	var seen := {}
	for cell in road:
		if seen.has(cell):
			return []
		seen[cell] = true
	return road


## The road through the turns: from the entry along its row to the first column, along that
## column to the first row, along that row to the next column, and so on to the exit.
func _road(slot: ValleyPlan.Slot, columns: Array[int], rows: Array[int]) -> Array[Vector2i]:
	var road: Array[Vector2i] = [slot.entry]
	var cell := slot.entry
	var turns: Array[Vector2i] = []
	for index in columns.size():
		turns.append(Vector2i(columns[index], cell.y if index == 0 else rows[index - 1]))
		turns.append(Vector2i(columns[index], rows[index]))
	turns.append(slot.exit)
	for turn in turns:
		while cell != turn:
			if cell.x != turn.x:
				cell.x += signi(turn.x - cell.x)
			else:
				cell.y += signi(turn.y - cell.y)
			road.append(cell)
	return road


## Every feeder that fits the road, as [cells, join]: a straight run down a column from the top
## edge or up from the bottom edge to the first road cell.
func _feeders(slot: ValleyPlan.Slot, road: Array[Vector2i]) -> Array:
	var rows := slot.rect.size.y
	var found := []
	var first := slot.rect.position.x + FOLD.FEEDER_SIDE_MARGIN
	var last := slot.rect.end.x - 1 - FOLD.FEEDER_SIDE_MARGIN
	for from_top in [true, false]:
		for x in range(first, last + 1):
			var cells: Array[Vector2i] = []
			var join := Vector2i(-1, -1)
			for step in rows:
				var cell := Vector2i(x, step if from_top else rows - 1 - step)
				if road.has(cell):
					join = cell
					break
				cells.append(cell)
			if join.x >= 0 and _feeder_problems(slot.rect, road, cells, join).is_empty():
				found.append([cells, join])
	return found


func _pack(sites: Array, from: int, chosen: Array[Vector2i]) -> bool:
	if chosen.size() >= FOLD.MERGE_COVER_MIN:
		return true
	for index in range(from, sites.size()):
		if SectionSockets.keeps_distance(sites[index], chosen):
			chosen.append(sites[index])
			if _pack(sites, index + 1, chosen):
				return true
			chosen.pop_back()
	return false


func _blocked(slot: ValleyPlan.Slot, result: SectionResult) -> Array[Rect2i]:
	var blocked := reserved(slot)
	for cell in result.feeder:
		blocked.append(Rect2i(cell, Vector2i.ONE))
	return blocked


func _shuffled(items: Array, rng: Rng) -> Array:
	var out := items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held = out[i]
		out[i] = out[j]
		out[j] = held
	return out


## The merge blocks (found by a search over the sites in a shuffled order, so the seed picks
## which fit), then one beside each bend they leave bare, then the rest.
func _place_sockets(slot: ValleyPlan.Slot, rng: Rng, result: SectionResult) -> void:
	var sites := _shuffled(SectionSockets.candidates(result, _blocked(slot, result)), rng)
	var near: Array = sites.filter(
		func(site: Vector2i) -> bool: return _near_join(site, result.feeder_join)
	)
	var merge: Array[Vector2i] = []
	_pack(near, 0, merge)
	for anchor in merge:
		result.add_socket(anchor, 0, SectionResult.Tag.MERGE)
	for bend in SectionSockets.bends(result.road):
		var best := SectionSockets._nearest(sites, bend, result.sockets)
		if not _covers(result, bend) and best.x >= 0:
			result.add_socket(best, 0, SectionResult.Tag.BEND)
	var target := FOLD.SOCKET_MIN + rng.next_int(FOLD.SOCKET_MAX - FOLD.SOCKET_MIN + 1)
	for site in sites:
		if result.sockets.size() >= target:
			break
		if SectionSockets.keeps_distance(site, result.sockets):
			result.add_socket(site, 0, SectionResult.Tag.LOW)


## True when the sockets are enough, not too many, cover the merge and every bend.
func _sockets_ok(result: SectionResult) -> bool:
	var near := 0
	for anchor in result.sockets:
		near += 1 if _near_join(anchor, result.feeder_join) else 0
	for bend in SectionSockets.bends(result.road):
		if not _covers(result, bend):
			return false
	var count := result.sockets.size()
	return near >= FOLD.MERGE_COVER_MIN and count >= FOLD.SOCKET_MIN and count <= FOLD.SOCKET_MAX


func _covers(result: SectionResult, bend: Vector2i) -> bool:
	for anchor in result.sockets:
		if SectionSockets.centre_gap(anchor, bend) <= VALLEY.BEND_COVER_REACH:
			return true
	return false


## Ruins: solid rock blocks on a low foundation, with dirt around them, away from the roads, the
## join and the sockets. Everything else stays meadow on the floor.
func _lay_ruins(rng: Rng, result: SectionResult) -> void:
	var sites: Array[Rect2i] = []
	for y in range(result.rect.position.y, result.rect.end.y - FOLD.RUIN_SIZE + 1):
		for x in range(result.rect.position.x, result.rect.end.x - FOLD.RUIN_SIZE + 1):
			var block := Rect2i(x, y, FOLD.RUIN_SIZE, FOLD.RUIN_SIZE)
			if _ruin_fits(block, result):
				sites.append(block)
	for _ruin in FOLD.RUIN_COUNT:
		if sites.is_empty():
			break
		var block := sites[rng.next_int(sites.size())]
		sites = sites.filter(
			func(other: Rect2i) -> bool: return not other.grow(1).intersects(block)
		)
		_raise(block, result)


func _ruin_fits(block: Rect2i, result: SectionResult) -> bool:
	var ring := block.grow(FOLD.RUIN_ROAD_GAP - 1)
	for cell in result.road + result.feeder:
		if ring.has_point(cell):
			return false
	for anchor in result.sockets:
		if block.grow(1).intersects(Rect2i(anchor, Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT)):
			return false
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			if _gap(Vector2i(x, y), result.feeder_join) < FOLD.RUIN_JOIN_GAP:
				return false
	return true


func _raise(block: Rect2i, result: SectionResult) -> void:
	for y in range(block.position.y - 1, block.end.y + 1):
		for x in range(block.position.x - 1, block.end.x + 1):
			var cell := Vector2i(x, y)
			if block.has_point(cell):
				result.set_height(cell, FOLD.RUIN_HEIGHT)
				result.set_region(cell, GameMap.Region.ROCKS)
				result.set_walkable(cell, false)
			elif result.has_cell(cell) and result.region_at(cell) == GameMap.Region.MEADOW:
				result.set_region(cell, GameMap.Region.DIRT)


## Why a feeder does not work (none when it does): it runs on unit steps from the board's top
## or bottom edge to a road cell's neighbour, in the strip, straight, long enough and clear
## of the road except at the join.
func _feeder_problems(
	rect: Rect2i, road: Array[Vector2i], feeder: Array[Vector2i], join: Vector2i
) -> Array[String]:
	var found: Array[String] = []
	var index := road.find(join)
	if feeder.is_empty() or index < 0:
		found.append("no feeder joins the road")
		return found
	if feeder.size() < RULES.FEEDER_MIN_CELLS:
		found.append("the feeder is %d cells, want %d" % [feeder.size(), RULES.FEEDER_MIN_CELLS])
	if feeder[0].y != rect.position.y and feeder[0].y != rect.end.y - 1:
		found.append("the feeder does not start on the board's top or bottom row")
	if _gap(feeder[feeder.size() - 1], join) != 1:
		found.append("the feeder does not end next to the join")
	for n in feeder.size():
		if not rect.has_point(feeder[n]):
			found.append("feeder cell %s is outside the strip" % feeder[n])
		if n > 0 and _gap(feeder[n], feeder[n - 1]) != 1:
			found.append("the feeder jumps at %s" % feeder[n])
		for cell in road:
			if cell != join and _gap(feeder[n], cell) < RULES.FEEDER_CLEARANCE:
				found.append("feeder cell %s is too near the road cell %s" % [feeder[n], cell])
	return found


func _near_join(anchor: Vector2i, join: Vector2i) -> bool:
	return SectionSockets.centre_gap(anchor, join) <= FOLD.MERGE_COVER_REACH


func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
