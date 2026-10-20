## Builds the sectioned valley (#381): draws the six sections from their own streams, checks
## them, draws again only a section that fails, and merges the six into one `GameMap`.
class_name ValleyStitcher
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")


## The valley for a seed, or null (with an error) when a section keeps failing its checks.
static func build(
	seed: int, cols: int, rows: int, sections: Array[ValleySection] = ValleySections.all()
) -> GameMap:
	var plan := ValleyPlan.create(seed, cols, rows)
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
			if attempts[id] >= VALLEY.MAX_SECTION_ATTEMPTS:
				push_error("valley seed %d: section %d fails: %s" % [seed, id, problems[0].text])
				return null
			results[id] = _draw(plan, sections, id, attempts[id])
	return null


static func _draw(
	plan: ValleyPlan, sections: Array[ValleySection], id: int, attempt: int
) -> SectionResult:
	var rng := ValleyPlan.section_rng(plan.seed, id, attempt)
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
	map.tiles = MapGen._tiles_for(map.routes, plan.cols, plan.rows)
	var last := map.path[map.path.size() - 1]
	map.heartstone = MapGen._heartstone_block(last, plan.cols, plan.rows, map.footprint)
	_merge_layers(map, results)
	return map


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
			bridge.path_index = map.path.find(bridge.cell)
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
