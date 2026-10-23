## Region 4, Ancient Fold, top right (#411): ruins, and the secondary entrance that opens in later
## waves: a feeder that enters at the board's top right corner and runs diagonally, as a smooth
## spline, down-left to join the main road before the way out to the Heartkeep Approach.
class_name AncientFoldRegion
extends RegionStraightSection

const FOLD := preload("res://content/valley/ancient_fold_region_rules.gd")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const HALF := Vector2(0.5, 0.5)


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	# the road is the layout's composed spine (#434); only the feeder and the blocks are drawn
	var curve := RoadSpline.build(slot.spine)
	for _try in FOLD.FEEDERS_TRIED:
		var result := SectionResult.create(slot)
		result.road = curve.cells
		result.road_curve = curve
		if not _add_feeder(slot, rng, result):
			continue
		_place_sockets(slot, rng, result)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			_lay_ruins(rng, result)
			return result
	# no draw worked: the stand-in goes out and `extra_problems` asks for another draw
	return super(slot, rng)


func socket_range() -> Vector2i:
	return Vector2i(FOLD.SOCKET_MIN, FOLD.SOCKET_MAX)


func extra_problems(slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	var found := _feeder_problems(slot.rect, result.road, result.feeder, result.feeder_join)
	var near := _near_join(result)
	if found.is_empty() and near < FOLD.MERGE_COVER_MIN:
		found.append("%d socket blocks cover the merge, want %d" % [near, FOLD.MERGE_COVER_MIN])
	return found


## Draws a feeder from the top right corner to a neighbour of a road cell and keeps it when it
## meets every rule; fills the result's feeder, join and curve.
func _add_feeder(slot: ValleyPlan.Slot, rng: Rng, result: SectionResult) -> bool:
	var road := result.road
	var inner := road.size() * FOLD.JOIN_SHARE / 100 - FOLD.JOIN_ENDS
	if inner < 1:
		return false
	var join := road[FOLD.JOIN_ENDS + rng.next_int(inner)]
	# the start is on the top row (the board's top edge), up to `START_REACH` steps west of the
	# corner: foes of the second source spawn above the board, so a start lower down the east
	# edge would have them walk down into the board before the road begins (#462)
	var along := rng.next_int(FOLD.START_REACH + 1)
	var start := Vector2i(slot.rect.end.x - 1 - along, slot.rect.position.y)
	# the join's neighbours that face the corner the feeder comes from
	var facing: Array[Vector2i] = []
	for step in DIRECTIONS:
		if _gap(join + step, start) < _gap(join, start) and not road.has(join + step):
			facing.append(join + step)
	if facing.is_empty():
		return false
	var end := facing[rng.next_int(facing.size())]
	var from := Vector2(start) + HALF
	var to := Vector2(end) + HALF
	var chord := to - from
	var length := sqrt(chord.x * chord.x + chord.y * chord.y)
	if length < 1.0:
		return false
	var side := float(rng.next_int(2) * 2 - 1)
	var bow := float(FOLD.BOW_MIN + rng.next_int(FOLD.BOW_SPAN)) * 0.5 * side
	var middle := (from + to) * 0.5 + Vector2(-chord.y, chord.x) * (bow / length)
	var waypoints: Array[Vector2] = [from, middle, to]
	var curve := RoadSpline.build(waypoints)
	if not _feeder_problems(slot.rect, road, curve.cells, join).is_empty():
		return false
	result.feeder.assign(curve.cells)
	result.feeder_join = join
	result.feeder_curve = curve
	return true


## Why a feeder does not work (none when it does): it runs from the top row near the top right
## corner on unit steps to a road cell's neighbour, inside the region, a diagonal, long enough
## and clear of the road except at the join.
func _feeder_problems(
	rect: Rect2i, road: Array[Vector2i], feeder: Array[Vector2i], join: Vector2i
) -> Array[String]:
	var found: Array[String] = []
	if feeder.is_empty() or not road.has(join):
		found.append("no feeder joins the road")
		return found
	if feeder.size() < RULES.FEEDER_MIN_CELLS:
		found.append("the feeder is %d cells, want %d" % [feeder.size(), RULES.FEEDER_MIN_CELLS])
	var first := feeder[0]
	var last := feeder[feeder.size() - 1]
	if _gap(last, join) != 1:
		found.append("the feeder does not end next to the join")
	if first.y != rect.position.y:
		found.append("the feeder does not start on the top row")
	if _gap(first, Vector2i(rect.end.x - 1, rect.position.y)) > FOLD.START_REACH:
		found.append("the feeder does not start at the top right corner")
	var span := Vector2i(absi(first.x - last.x), absi(first.y - last.y))
	if span.x < FOLD.FEEDER_MIN_SPAN or span.y < FOLD.FEEDER_MIN_SPAN:
		found.append("the feeder is no diagonal")
	for n in feeder.size():
		if not rect.has_point(feeder[n]):
			found.append("feeder cell %s is outside the region" % feeder[n])
		if feeder.find(feeder[n]) != n:
			found.append("the feeder crosses itself at %s" % feeder[n])
		for cell in road:
			if cell != join and _gap(feeder[n], cell) < RULES.FEEDER_CLEARANCE:
				found.append("feeder cell %s is too near the road cell %s" % [feeder[n], cell])
	return found


## The merge blocks first, then one beside each bend they leave bare, then the rest.
func _place_sockets(slot: ValleyPlan.Slot, rng: Rng, result: SectionResult) -> void:
	var blocked := reserved(slot)
	for cell in result.feeder:
		blocked.append(Rect2i(cell, Vector2i.ONE))
	var near: Array[Vector2i] = []
	for site in SectionSockets.candidates(result, blocked):
		if SectionSockets.centre_gap(site, result.feeder_join) <= _merge_reach(result):
			near.append(site)
	var merge: Array[Vector2i] = []
	_pack(near, 0, merge)
	for anchor in merge:
		result.add_socket(anchor, 0, SectionResult.Tag.MERGE)
	SectionSockets.place(result, socket_range(), rng, blocked)


## Picks `MERGE_COVER_MIN` sites that keep their gaps, or none.
func _pack(sites: Array[Vector2i], from: int, chosen: Array[Vector2i]) -> bool:
	if chosen.size() >= FOLD.MERGE_COVER_MIN:
		return true
	for index in range(from, sites.size()):
		if SectionSockets.keeps_distance(sites[index], chosen):
			chosen.append(sites[index])
			if _pack(sites, index + 1, chosen):
				return true
			chosen.pop_back()
	return false


## How far from the join a block's centre may be to cover the merge: wider by the band's room.
func _merge_reach(result: SectionResult) -> float:
	return FOLD.MERGE_COVER_REACH + SectionSockets.reach_extra(result)


func _near_join(result: SectionResult) -> int:
	var near := 0
	for anchor in result.sockets:
		if SectionSockets.centre_gap(anchor, result.feeder_join) <= _merge_reach(result):
			near += 1
	return near


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


func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
