## The hero's walkable graph over the merged valley (#385, feeds #335 and #329): a 4-neighbour
## flood fill over the sections' walkable cells. Reads `SectionResult`s only.
class_name HeroGraph
extends RefCounted

const HERO := preload("res://content/valley/hero_rules.gd")
const RULES := preload("res://content/map_rules.gd")

const NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Board size in cells and one flag per cell (1: the hero can stand there).
var cols := 0
var rows := 0
var open := PackedByteArray()


## The graph of the merged results. A bridge cell stays open even when the river under it is
## not walkable ground.
static func create(results: Array[SectionResult]) -> HeroGraph:
	var graph := HeroGraph.new()
	for result in results:
		graph.cols = maxi(graph.cols, result.rect.end.x)
		graph.rows = maxi(graph.rows, result.rect.end.y)
	graph.open.resize(graph.cols * graph.rows)
	for result in results:
		for y in range(result.rect.position.y, result.rect.end.y):
			for x in range(result.rect.position.x, result.rect.end.x):
				var cell := Vector2i(x, y)
				graph.open[y * graph.cols + x] = 1 if result.is_walkable(cell) else 0
		for bridge in result.bridges:
			graph.open[bridge.cell.y * graph.cols + bridge.cell.x] = 1
		for cell in result.hero_bridges:
			graph.open[cell.y * graph.cols + cell.x] = 1
	return graph


## The graph of a finished board (#449): its walkable cells and both kinds of bridge. A board with
## no walkable layer (the boards before the sectioned valley) is open everywhere.
static func from_map(map: GameMap) -> HeroGraph:
	var graph := HeroGraph.new()
	graph.cols = map.cols
	graph.rows = map.rows
	graph.open.resize(graph.cols * graph.rows)
	for y in graph.rows:
		for x in graph.cols:
			graph.open[y * graph.cols + x] = 1 if map.is_walkable(Vector2i(x, y)) else 0
	for bridge in map.bridges:
		graph.open[bridge.cell.y * graph.cols + bridge.cell.x] = 1
	for cell in map.hero_bridges:
		graph.open[cell.y * graph.cols + cell.x] = 1
	return graph


## Steps of the shortest walk between two cells, or -1 when either is closed or they are cut off.
static func travel_steps(results: Array[SectionResult], from: Vector2i, to: Vector2i) -> int:
	return create(results).steps(from, to)


## The problems of a whole valley's walkable graph: the Heartstone approach reachable, no walled-off
## pocket beside a socket block, the walk from the meadow within `caps`. Each names the section.
static func problems(
	results: Array[SectionResult], caps: Array[Vector2i] = HERO.CAPS
) -> Array[ValleyChecks.Problem]:
	var found: Array[ValleyChecks.Problem] = []
	if results.size() != ValleyPlan.Id.size():
		return found
	var graph := create(results)
	var spawn := results[0].road[0]
	var distance := graph._distances(spawn)
	var ring := graph._socket_ring(results)
	var seen := {}
	for x in graph.cols:
		for y in graph.rows:
			var cell := Vector2i(x, y)
			if not graph._is_open(cell) or distance[y * graph.cols + x] >= 0 or seen.has(cell):
				continue
			var pocket := graph._component(cell)
			for member in pocket:
				seen[member] = true
			var section := graph._section_at(results, cell)
			if pocket.has(results[results.size() - 1].road.back()):
				found.append(
					ValleyChecks.Problem.make(section, "the hero cannot walk to %s" % cell)
				)
			elif (
				pocket.size() > HERO.ISLAND_MAX_CELLS
				and pocket.any(func(member: Vector2i) -> bool: return ring.has(member))
			):
				found.append(
					ValleyChecks.Problem.make(
						section, "walled-off ground at %s holds a socket" % cell
					)
				)
	if not found.is_empty():
		return found
	var from := graph._anchor(_of_role(results, ValleyPlan.Id.SUNKEN_MEADOW).rect)
	for target in caps:
		var section := _of_role(results, target.x)
		var to := graph._anchor(section.rect)
		var steps := graph.steps(from, to)
		if steps < 0 or steps > target.y:
			found.append(
				ValleyChecks.Problem.make(
					section.id,
					"the hero needs %d steps from the meadow, cap %d" % [steps, target.y]
				)
			)
	return found


## The steps from `from` to `to` on this graph (-1 when cut off).
func steps(from: Vector2i, to: Vector2i) -> int:
	if not _is_open(from) or not _is_open(to):
		return -1
	return _distances(from)[to.y * cols + to.x]


## The shortest walk from `from` to `to`, both ends included, or an empty one when either end is
## closed or they are cut off. Of equally short walks it takes, at every cell, the first step in
## `NEIGHBOURS` order that gets closer, so the same ends always give the same walk.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not _is_open(from) or not _is_open(to):
		return cells
	var distance := _distances(to)
	if distance[from.y * cols + from.x] < 0:
		return cells
	var cell := from
	cells.append(cell)
	while cell != to:
		var closer := distance[cell.y * cols + cell.x] - 1
		for step in NEIGHBOURS:
			var next := cell + step
			if _is_open(next) and distance[next.y * cols + next.x] == closer:
				cell = next
				break
		cells.append(cell)
	return cells


## The result of the section of this kind (`ValleyPlan.Id`).
static func _of_role(results: Array[SectionResult], role: int) -> SectionResult:
	for result in results:
		if result.role == role:
			return result
	return results[role]


func _is_open(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < cols
		and cell.y < rows
		and open[cell.y * cols + cell.x] == 1
	)


## Breadth-first distances from `start`, -1 where not reached.
func _distances(start: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(cols * rows)
	dist.fill(-1)
	if not _is_open(start):
		return dist
	dist[start.y * cols + start.x] = 0
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step in NEIGHBOURS:
			var next := cell + step
			if _is_open(next) and dist[next.y * cols + next.x] < 0:
				dist[next.y * cols + next.x] = dist[cell.y * cols + cell.x] + 1
				queue.append(next)
	return dist


func _component(start: Vector2i) -> Array[Vector2i]:
	var distance := _distances(start)
	var cells: Array[Vector2i] = []
	for index in distance.size():
		if distance[index] >= 0:
			cells.append(Vector2i(index % cols, index / cols))
	return cells


## The open cell of the strip nearest its middle (the middle itself may be water or rock).
func _anchor(rect: Rect2i) -> Vector2i:
	var middle := rect.position + rect.size / 2
	var best := Vector2i(-1, -1)
	var best_gap := 1 << 30
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var gap := absi(x - middle.x) + absi(y - middle.y)
			if _is_open(Vector2i(x, y)) and gap < best_gap:
				best = Vector2i(x, y)
				best_gap = gap
	return best


func _socket_ring(results: Array[SectionResult]) -> Dictionary:
	var ring := {}
	var size: int = RULES.GAME_SOCKET_FOOTPRINT
	for result in results:
		for anchor in result.sockets:
			for y in range(anchor.y - HERO.SOCKET_RING, anchor.y + size + HERO.SOCKET_RING):
				for x in range(anchor.x - HERO.SOCKET_RING, anchor.x + size + HERO.SOCKET_RING):
					ring[Vector2i(x, y)] = true
	return ring


func _section_at(results: Array[SectionResult], cell: Vector2i) -> int:
	for result in results:
		if result.rect.has_point(cell):
			return result.id
	return ValleyPlan.Id.SUNKEN_MEADOW
