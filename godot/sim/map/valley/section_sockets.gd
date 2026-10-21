## Socket sites for a valley section (#381): the cells where a 2x2 block fits beside the section's
## road, with the same reach rules as `SocketPlacer`, and a placer that covers the road's bends
## first. Real sections may use it, or place their own sockets.
class_name SectionSockets
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")


## The road's bends: the cells where it turns. With `min_run` above 1 only a turn between two
## straight runs of at least that many steps counts, so the staircase of a diagonal stretch of a
## spline road is no row of bends.
static func bends(road: Array[Vector2i], min_run: int = 1) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for index in range(1, road.size() - 1):
		if (
			road[index] - road[index - 1] != road[index + 1] - road[index]
			and _run(road, index, -1) >= min_run
			and _run(road, index, 1) >= min_run
		):
			found.append(road[index])
	return found


## The steps in a straight line from `index` going `way` (1 or -1) along the road.
static func _run(road: Array[Vector2i], index: int, way: int) -> int:
	var step := (road[index + way] - road[index]) * way
	var count := 0
	var at := index
	while at + way >= 0 and at + way < road.size() and road[at + way] - road[at] == step * way:
		count += 1
		at += way
	return count


## Anchors of blocks that fit in the strip (one empty column kept at its right edge), off the
## road and off `blocked`, touching the road with enough of it in reach of the block's centre.
static func candidates(result: SectionResult, blocked: Array[Rect2i]) -> Array[Vector2i]:
	var size: int = RULES.GAME_SOCKET_FOOTPRINT
	var out: Array[Vector2i] = []
	var last_x := result.rect.end.x - size - result.margin.x
	for y in range(result.rect.position.y, result.rect.end.y - size - result.margin.y + 1):
		for x in range(result.rect.position.x, last_x + 1):
			var block := Rect2i(x, y, size, size)
			if _free(block, result.road, blocked) and reaches_road(block, result.road):
				out.append(Vector2i(x, y))
	return out


## Fills the result's sockets with `blocks.x` to `blocks.y` blocks: one beside each bend first, then
## the rest from the shuffled sites, each keeping `SOCKET_BLOCK_GAP` empty cells from the others.
static func place(
	result: SectionResult, blocks: Vector2i, rng: Rng, blocked: Array[Rect2i]
) -> void:
	var sites := candidates(result, blocked)
	for i in range(sites.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := sites[i]
		sites[i] = sites[j]
		sites[j] = held
	var target: int = blocks.x + rng.next_int(blocks.y - blocks.x + 1)
	for bend in bends(result.road, result.bend_run):
		var best := _nearest(sites, bend, result.sockets)
		if best != Vector2i(-1, -1) and centre_gap(best, bend) <= VALLEY.BEND_COVER_REACH:
			result.add_socket(best, 0, SectionResult.Tag.BEND)
	for site in sites:
		if result.sockets.size() >= target:
			break
		if keeps_distance(site, result.sockets):
			result.add_socket(site, 0, SectionResult.Tag.LOW)


static func _free(block: Rect2i, road: Array[Vector2i], blocked: Array[Rect2i]) -> bool:
	for cell in road:
		if block.has_point(cell):
			return false
	for rect in blocked:
		if block.intersects(rect):
			return false
	return true


static func reaches_road(block: Rect2i, road: Array[Vector2i]) -> bool:
	var touch := false
	var near := 0
	var touch_reach: float = RULES.SOCKET_BLOCK_TOUCH_DISTANCE
	var cover_reach: float = RULES.SOCKET_COVERAGE_REACH
	for cell in road:
		var gap := centre_gap(block.position, cell)
		touch = touch or gap <= touch_reach
		if gap <= cover_reach:
			near += 1
	return touch and near >= RULES.SOCKET_MIN_ROAD_COVERAGE


## How far a block's centre (a 2x2 block's centre is on a cell corner) is from a cell's centre.
static func centre_gap(anchor: Vector2i, cell: Vector2i) -> float:
	var half := float(RULES.GAME_SOCKET_FOOTPRINT) / 2.0
	var dx := float(anchor.x) + half - (float(cell.x) + RULES.CELL_CENTRE)
	var dy := float(anchor.y) + half - (float(cell.y) + RULES.CELL_CENTRE)
	return sqrt(dx * dx + dy * dy)


static func _nearest(sites: Array[Vector2i], bend: Vector2i, chosen: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_gap := 1.0e30
	for site in sites:
		var gap := centre_gap(site, bend)
		if gap < best_gap and keeps_distance(site, chosen):
			best = site
			best_gap = gap
	return best


static func keeps_distance(site: Vector2i, chosen: Array[Vector2i]) -> bool:
	for other in chosen:
		if not blocks_apart(site, other):
			return false
	return true


## True when two blocks, by anchor, leave `SOCKET_BLOCK_GAP` empty cells between them.
static func blocks_apart(a: Vector2i, b: Vector2i) -> bool:
	var apart: int = RULES.GAME_SOCKET_FOOTPRINT + RULES.SOCKET_BLOCK_GAP
	return absi(a.x - b.x) >= apart or absi(a.y - b.y) >= apart
