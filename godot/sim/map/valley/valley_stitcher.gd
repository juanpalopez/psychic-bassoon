## Builds the sectioned valley (#381): draws the six sections from their own streams, checks
## them, draws again only a section that fails, and merges the six into one `GameMap`.
class_name ValleyStitcher
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const ROAD := preload("res://content/valley/road_rules.gd")


## The valley for a seed, or null (with an error, unless `quiet`) when a section keeps failing its
## checks. `layout` replaces the strip plan.
static func build(
	seed: int,
	cols: int,
	rows: int,
	sections: Array[ValleySection] = ValleySections.all(),
	layout: ValleyPlan = null,
	quiet: bool = false
) -> GameMap:
	var plan := layout if layout != null else ValleyPlan.create(seed, cols, rows)
	var attempts: Array[int] = []
	var results: Array[SectionResult] = []
	for slot in plan.slots:
		attempts.append(0)
		results.append(_draw(plan, sections, slot.id, 0))
	while true:
		var problems := ValleyChecks.all_problems(plan, sections, results)
		if problems.is_empty():
			return _assemble(plan, results)
		var again := {}
		for problem in problems:
			again[problem.section] = true
		for id in again:
			attempts[id] += 1
			if attempts[id] >= plan.section_attempts:
				if not quiet:
					push_error(
						"valley seed %d: section %d fails: %s" % [seed, id, problems[0].text]
					)
				return null
			results[id] = _draw(plan, sections, id, attempts[id])
	return null


static func _draw(
	plan: ValleyPlan, sections: Array[ValleySection], id: int, attempt: int
) -> SectionResult:
	var rng := plan.rng_for(id, attempt)
	return sections[id].generate(plan.slots[id], rng)


## One map from the six results: the road end to end, the second road, the sockets in reading
## order, and the per-cell layers.
static func _assemble(plan: ValleyPlan, results: Array[SectionResult]) -> GameMap:
	var map := GameMap.new()
	map.seed = plan.seed
	map.cols = plan.cols
	map.rows = plan.rows
	map.footprint = RULES.GAME_SOCKET_FOOTPRINT
	for result in results:
		map.path.append_array(result.road)
	map.routes = [map.path]
	for result in results:
		if not result.feeder.is_empty():
			var join := map.path.find(result.feeder_join)
			var route: Array[Vector2i] = []
			route.append_array(result.feeder)
			route.append_array(map.path.slice(join))
			map.routes.append(route)
			map.feeder_length = result.feeder.size()
			map.join_index = join
	_add_branch_route(map, results)
	map.route_curves = _route_curves(map, results)
	map.tiles = MapGen._tiles_for(map.routes, plan.cols, plan.rows)
	if plan.road_width > 0.0 and not map.route_curves.is_empty():
		map.road_width = plan.road_width
		_mark_band(map)
	var last := map.path[map.path.size() - 1]
	map.heartstone = MapGen._heartstone_block(last, plan.cols, plan.rows, map.footprint)
	_merge_layers(map, results)
	return map


## Every cell any part of which is within half the band's width of a route's curve is `Tile.ROAD`
## (#430, #469), so nothing treats it as ground to build on and the drawn bed never leaves the
## road cells (a curve running diagonally across a staircase of cells touches cells whose centres
## lie further off). The centre-line cells (`path`) stay as they are.
static func _mark_band(map: GameMap) -> void:
	var half := map.road_width / 2.0
	for curve: RoadCurve in map.route_curves:
		for index in curve.xs.size() - 1:
			var a := Vector2(curve.xs[index], curve.ys[index])
			var b := Vector2(curve.xs[index + 1], curve.ys[index + 1])
			var low := a.min(b) - Vector2(half, half)
			var high := a.max(b) + Vector2(half, half)
			for y in range(maxi(int(floor(low.y)), 0), mini(int(floor(high.y)) + 1, map.rows)):
				for x in range(maxi(int(floor(low.x)), 0), mini(int(floor(high.x)) + 1, map.cols)):
					if curve.segment_rect_gap(index, x, y, 1) < half:
						map.tiles[y][x] = GameMap.Tile.ROAD


static func _merge_layers(map: GameMap, results: Array[SectionResult]) -> void:
	map.elevation = _grid(map)
	map.heights = _grid(map)
	map.walkable = _grid(map)
	var regions := _grid(map)
	var levels := {}
	for result in results:
		for index in result.sockets.size():
			map.sockets.append(result.sockets[index])
			levels[result.sockets[index]] = result.socket_levels[index]
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				map.heights[y][x] = result.height_at(cell)
				regions[y][x] = result.region_at(cell)
				map.walkable[y][x] = 1 if result.is_walkable(cell) else 0
		map.river.append_array(result.river)
		map.hero_bridges.append_array(result.hero_bridges)
		for bridge in result.bridges:
			var route: Array = map.routes[map.forks[0].route] if bridge.on_branch else map.path
			bridge.route = map.forks[0].route if bridge.on_branch else 0
			bridge.path_index = route.find(bridge.cell)
			map.bridges.append(bridge)
	map.regions = regions
	map.sockets.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	for anchor in map.sockets:
		for dy in map.footprint:
			for dx in map.footprint:
				map.elevation[anchor.y + dy][anchor.x + dx] = levels[anchor]


static func _grid(map: GameMap) -> Array[PackedByteArray]:
	var grid: Array[PackedByteArray] = []
	for row in map.rows:
		var line := PackedByteArray()
		line.resize(map.cols)
		grid.append(line)
	return grid


## The fork's second lane (#481): route B is each section's branch where it has one and its road
## where it does not, appended after the feeder, in the main source with the main road
## (`sources`). Its `Fork` runs from the first branch's first cell, a cell the main road shares, to
## the last branch's last cell. Nothing is added when no section has a branch.
static func _add_branch_route(map: GameMap, results: Array[SectionResult]) -> void:
	var lane: Array[Vector2i] = []
	var first := -1
	var last := -1
	for result in results:
		if result.branch.is_empty():
			lane.append_array(result.road)
			continue
		first = map.path.find(result.branch[0]) if first < 0 else first
		last = map.path.find(result.branch[result.branch.size() - 1])
		lane.append_array(result.branch)
	if first < 0:
		return
	var fork := GameMap.Fork.new()
	fork.route = map.routes.size()
	fork.fork_index = first
	fork.merge_index = last
	fork.branch_length = lane.size() - map.path.size() + (last - first - 1)
	map.forks.append(fork)
	map.sources.append(PackedInt32Array([0, fork.route]))
	if map.routes.size() > 1:
		map.sources.append(PackedInt32Array([1]))
	map.routes.append(lane)


## The curves foes walk, one per route: the sections' spline roads joined end to end (a section
## with no spline contributes its cell centres), and the second route as its own cells and then
## the main curve from the join on, so both are the same line after the join. The second's own
## part is the feeder curve a section gives, else the feeder cells' centres. Empty when no
## section has a spline.
static func _route_curves(map: GameMap, results: Array[SectionResult]) -> Array:
	var any_spline := false
	var main := RoadCurve.new()
	for result in results:
		any_spline = any_spline or result.road_curve != null
		main.append_curve(
			result.road_curve if result.road_curve != null else RoadCurve.from_cells(result.road)
		)
	if not any_spline:
		return []
	var curves: Array = [main]
	if map.routes.size() > 1:
		var second := RoadCurve.new()
		var feeder_curve: RoadCurve = null
		for result in results:
			feeder_curve = result.feeder_curve if result.feeder_curve != null else feeder_curve
		second.append_curve(
			(
				feeder_curve
				if feeder_curve != null
				else RoadCurve.from_cells(map.routes[1].slice(0, map.feeder_length))
			)
		)
		var tail := RoadCurve.new()
		var first_point := main.cell_points[map.join_index]
		for index in range(first_point, main.xs.size()):
			tail.xs.append(main.xs[index])
			tail.ys.append(main.ys[index])
		for index in range(map.join_index, main.cells.size()):
			tail.cells.append(main.cells[index])
			tail.cell_points.append(main.cell_points[index] - first_point)
		second.append_curve(tail)
		curves.append(second)
	if not map.forks.is_empty():
		var lane := RoadCurve.new()
		for result in results:
			lane.append_curve(_lane_curve(result))
		curves.append(lane)
	return curves


## The curve of a section on the branch route: its branch's, else its road's.
static func _lane_curve(result: SectionResult) -> RoadCurve:
	if not result.branch.is_empty():
		return (
			result.branch_curve
			if result.branch_curve != null
			else RoadCurve.from_cells(result.branch)
		)
	return result.road_curve if result.road_curve != null else RoadCurve.from_cells(result.road)
