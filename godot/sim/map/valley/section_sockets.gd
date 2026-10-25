## Socket sites for a valley section (#381): the cells where a 2x2 block fits beside the section's
## road, with the same reach rules as `SocketPlacer`, and a placer that covers the road's bends
## first. Real sections may use it, or place their own sockets.
class_name SectionSockets
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const ROAD := preload("res://content/valley/road_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const LAYOUT := preload("res://content/valley/layout_rules.gd")


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
			if _free(block, result, blocked) and off_band(result, block) and reaches(result, block):
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
	if not result.branch.is_empty():
		sites = _main_road_first(result, sites)
	var target: int = blocks.x + rng.next_int(blocks.y - blocks.x + 1)
	for bend in bends(result.road, result.bend_run):
		_cover_bend(result, sites, bend)
	for bend in bends(result.branch, result.bend_run):
		_cover_bend(result, sites, bend)
	if not result.branch.is_empty():
		_reach_lanes(result, sites)
	for site in sites:
		if result.sockets.size() >= target:
			break
		if keeps_distance(site, result.sockets):
			result.add_socket(site, 0, SectionResult.Tag.LOW)


static func _cover_bend(result: SectionResult, sites: Array[Vector2i], bend: Vector2i) -> void:
	var best := _nearest(sites, bend, result.sockets)
	if best != Vector2i(-1, -1) and centre_gap(best, bend) <= bend_reach(result):
		result.add_socket(best, 0, SectionResult.Tag.BEND)


## The cells of the lower lane the upper lane does not share (#516).
static func own_branch(result: SectionResult) -> Array[Vector2i]:
	var own: Array[Vector2i] = []
	for cell in result.branch:
		if not result.road.has(cell):
			own.append(cell)
	return own


## How many blocks of the result have `SOCKET_MIN_ROAD_COVERAGE` of `cells` in reach.
static func blocks_reaching(result: SectionResult, cells: Array[Vector2i]) -> int:
	var count := 0
	var reach := coverage_reach(result.road_width)
	for anchor in result.sockets:
		var block := Rect2i(anchor, Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT)
		count += 1 if covers(block, cells, 0.0, reach) else 0
	return count


## The cells of the bridges on the lower lane (`on_branch`) or on the upper road.
static func bridge_cells(result: SectionResult, on_branch: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for bridge in result.bridges:
		if bridge.on_branch == on_branch:
			cells.append(bridge.cell)
	return cells


## True when a block's centre is in coverage reach of one of the cells (a bridge's span).
static func reaches_cells(
	result: SectionResult, cells: Array[Vector2i], anchors: Array[Vector2i]
) -> bool:
	var reach := coverage_reach(result.road_width)
	for anchor in anchors:
		for cell in cells:
			if centre_gap(anchor, cell) <= reach:
				return true
	return false


## Sockets for the lower lane (#516): `BRANCH_MIN_BLOCKS` blocks that reach its own stretch, then
## a block in reach of each lane's bridge, taken from the sites before the rest are filled, so the
## lanes keep the time under fire the main road had.
static func _reach_lanes(result: SectionResult, sites: Array[Vector2i]) -> void:
	var own := own_branch(result)
	var size := Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT
	var reach := coverage_reach(result.road_width)
	var have := blocks_reaching(result, own)
	# a block between the lanes serves both, so those go first and the main road keeps its cover
	for both in [true, false]:
		for site in sites:
			if have >= LAYOUT.BRANCH_MIN_BLOCKS:
				break
			var block := Rect2i(site, size)
			if not covers(block, own, 0.0, reach) or not keeps_distance(site, result.sockets):
				continue
			if both and not covers(block, result.road, 0.0, reach):
				continue
			result.add_socket(site, 0, SectionResult.Tag.LOW)
			have += 1
	for on_branch in [false, true]:
		var span := bridge_cells(result, on_branch)
		if span.is_empty() or reaches_cells(result, span, result.sockets):
			continue
		for site in sites:
			if (
				reaches_cells(result, span, [site] as Array[Vector2i])
				and keeps_distance(site, result.sockets)
			):
				result.add_socket(site, 0, SectionResult.Tag.LOW)
				break


## The sites in the same order, those that reach the main road first: with the fork's lower lane
## (#481) a block that reaches only the lower lane is taken only once the main road's sites run
## out, so the main road keeps the blocks it had (the checks of the lanes come with their ticket).
static func _main_road_first(result: SectionResult, sites: Array[Vector2i]) -> Array[Vector2i]:
	var first: Array[Vector2i] = []
	var rest: Array[Vector2i] = []
	for site in sites:
		var block := Rect2i(site, Vector2i.ONE * RULES.GAME_SOCKET_FOOTPRINT)
		if covers(block, result.road, 0.0, coverage_reach(result.road_width)):
			first.append(site)
		else:
			rest.append(site)
	first.append_array(rest)
	return first


static func _free(block: Rect2i, result: SectionResult, blocked: Array[Rect2i]) -> bool:
	for cell in result.road:
		if block.has_point(cell):
			return false
	for cell in result.branch:
		if block.has_point(cell):
			return false
	for rect in blocked:
		if block.intersects(rect):
			return false
	return true


static func reaches_road(block: Rect2i, road: Array[Vector2i]) -> bool:
	var touch := false
	for cell in road:
		touch = touch or centre_gap(block.position, cell) <= RULES.SOCKET_BLOCK_TOUCH_DISTANCE
	return touch and covers(block, road, 0.0)


## True when at least `SOCKET_MIN_ROAD_COVERAGE` road cells are within the coverage reach (plus
## `extra`) of the block's centre.
static func covers(
	block: Rect2i, road: Array[Vector2i], extra: float, reach: float = RULES.SOCKET_COVERAGE_REACH
) -> bool:
	var near := 0
	for cell in road:
		if centre_gap(block.position, cell) <= reach + extra:
			near += 1
	return near >= RULES.SOCKET_MIN_ROAD_COVERAGE


## The reach rule of a section: the same for the one-cell road and for a band. A level 1 tower on
## the block covers at least `SOCKET_MIN_ROAD_COVERAGE` road cells (the centre line) within
## `coverage_reach` (of the fork's lower lane, when the strip has one); a block the band keeps too
## far from the road is not placed (#430).
static func reaches(result: SectionResult, block: Rect2i) -> bool:
	if result.road_width <= 0.0:
		return reaches_road(block, result.road)
	var reach := coverage_reach(result.road_width)
	# a block beside the fork's lower lane (#481) covers that lane instead
	return (
		covers(block, result.road, 0.0, reach)
		or (not result.branch.is_empty() and covers(block, result.branch, 0.0, reach))
	)


## How far from a block's centre the centre line still counts towards its coverage on a band of
## `width` cells: a level 1 Spool Guard's range plus the reach margin the band gives a tower
## (`GameMap.reach_margin`, half the width; #446).
static func coverage_reach(width: float) -> float:
	var range_1: float = TOWERS.DEFS["spoolGuard"].range[0]
	return range_1 + width / 2.0


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


## How much further a block stands from the road's cell centres because of its band (#430): the
## band's half width plus the clearance, less the half cell the one-cell road already takes. 0
## without a band.
static func reach_extra(result: SectionResult) -> float:
	if result.road_width <= 0.0:
		return 0.0
	return maxf(0.0, result.road_width / 2.0 + ROAD.ROAD_CLEARANCE_CELLS - RULES.CELL_CENTRE)


## The reach of a block's centre that covers a bend of the road, wider with a band.
static func bend_reach(result: SectionResult) -> float:
	return VALLEY.BEND_COVER_REACH + reach_extra(result)


## The nearest a block's centre may be to the road's curve with a band: the band's half width,
## the clearance and the block's own half width. A block nearer than this is on the band.
static func least_gap(result: SectionResult) -> float:
	var half := float(RULES.GAME_SOCKET_FOOTPRINT) / 2.0
	return result.road_width / 2.0 + ROAD.ROAD_CLEARANCE_CELLS + half


## True when no cell of the block is within the band (`ROAD_CLEARANCE_CELLS` more): the block's
## square, not its centre, keeps off the curve, because a cell the curve reaches is road (#469).
## Always true without a band.
static func off_band(result: SectionResult, block: Rect2i) -> bool:
	if result.road_width <= 0.0:
		return true
	var half := float(RULES.GAME_SOCKET_FOOTPRINT) / 2.0
	var centre := Vector2(block.position) + Vector2(half, half)
	var keep := result.road_width / 2.0 + ROAD.ROAD_CLEARANCE_CELLS
	var gap := _curve_gap(result, centre)
	# the block's centre is at least half a block from its square's edge, at most the diagonal
	if gap < keep + half:
		return false
	if gap >= keep + half * sqrt(2.0):
		return true
	return _square_gap(result, block) >= keep


static func _square_gap(result: SectionResult, block: Rect2i) -> float:
	var gap := _main_curve(result).rect_gap(block.position.x, block.position.y, block.size.x)
	if result.feeder_curve != null:
		gap = minf(
			gap, result.feeder_curve.rect_gap(block.position.x, block.position.y, block.size.x)
		)
	elif not result.feeder.is_empty():
		var feeder := RoadCurve.from_cells(result.feeder)
		gap = minf(gap, feeder.rect_gap(block.position.x, block.position.y, block.size.x))
	var lane := _branch_curve(result)
	if lane != null:
		gap = minf(gap, lane.rect_gap(block.position.x, block.position.y, block.size.x))
	return gap


## The curve of the fork's second lane through the strip, or null without one (#481).
static func _branch_curve(result: SectionResult) -> RoadCurve:
	if result.branch.is_empty():
		return null
	return (
		result.branch_curve if result.branch_curve != null else RoadCurve.from_cells(result.branch)
	)


static func _main_curve(result: SectionResult) -> RoadCurve:
	return result.road_curve if result.road_curve != null else RoadCurve.from_cells(result.road)


## How far a point is from the road's curve (the main road, the feeder and the fork's lane).
static func _curve_gap(result: SectionResult, centre: Vector2) -> float:
	var gap := _main_curve(result).distance_to(centre.x, centre.y)
	if result.feeder_curve != null:
		gap = minf(gap, result.feeder_curve.distance_to(centre.x, centre.y))
	elif not result.feeder.is_empty():
		gap = minf(gap, RoadCurve.from_cells(result.feeder).distance_to(centre.x, centre.y))
	var lane := _branch_curve(result)
	if lane != null:
		gap = minf(gap, lane.distance_to(centre.x, centre.y))
	return gap
