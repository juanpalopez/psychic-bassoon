extends GutTest

## The hero's any-angle walk (owner feedback, 2026-10-25): the 4-neighbour path pulled straight
## over open ground, so the Knight goes in a line and not in a staircase.

const HERO := preload("res://content/valley/hero_rules.gd")
const BODY := 0.2


## An open board of `cols` by `rows` with `closed` cells shut.
func _graph(cols: int, rows: int, closed: Array[Vector2i] = []) -> HeroGraph:
	var graph := HeroGraph.new()
	graph.cols = cols
	graph.rows = rows
	graph.open.resize(cols * rows)
	graph.open.fill(1)
	for cell in closed:
		graph.open[cell.y * cols + cell.x] = 0
	return graph


func _length(cells: Array[Vector2i]) -> float:
	var total := 0.0
	for i in cells.size() - 1:
		total += Vector2(cells[i]).distance_to(Vector2(cells[i + 1]))
	return total


## Independent check: sample the segment densely and test the body's four extremes.
func _body_clear(graph: HeroGraph, a: Vector2i, b: Vector2i) -> bool:
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var to := Vector2(b) + Vector2(0.5, 0.5)
	for i in 401:
		var at := from.lerp(to, float(i) / 400.0)
		for offset in [
			Vector2.ZERO,
			Vector2(BODY, 0.0),
			Vector2(-BODY, 0.0),
			Vector2(0.0, BODY),
			Vector2(0.0, -BODY)
		]:
			var p: Vector2 = at + offset
			if not graph.is_open(Vector2i(floori(p.x), floori(p.y))):
				return false
	return true


func test_an_open_field_diagonal_is_two_waypoints() -> void:
	var graph := _graph(12, 12)
	var walk := graph.walk(Vector2i(1, 1), Vector2i(9, 6))
	assert_eq(walk, [Vector2i(1, 1), Vector2i(9, 6)] as Array[Vector2i])
	assert_eq(graph.walk(Vector2i(3, 3), Vector2i(3, 3)), [Vector2i(3, 3)] as Array[Vector2i])


func test_a_walk_round_a_closed_block_bends_only_at_its_corners() -> void:
	var block: Array[Vector2i] = []
	for y in range(3, 8):
		for x in range(4, 7):
			block.append(Vector2i(x, y))
	var graph := _graph(12, 12, block)
	var walk := graph.walk(Vector2i(1, 5), Vector2i(10, 5))
	assert_gt(walk.size(), 2)
	for waypoint in walk.slice(1, walk.size() - 1):
		var corner: bool = (
			(waypoint.x == 3 or waypoint.x == 7) and (waypoint.y == 2 or waypoint.y == 8)
		)
		assert_true(corner, "bends at a corner of the block, not %s" % waypoint)
	for i in walk.size() - 1:
		assert_true(_body_clear(graph, walk[i], walk[i + 1]), "leg %d" % i)


func test_a_diagonal_between_two_corner_touching_walls_is_not_cut() -> void:
	var graph := _graph(6, 6, [Vector2i(2, 3), Vector2i(3, 2)] as Array[Vector2i])
	var walk := graph.walk(Vector2i(2, 2), Vector2i(3, 3))
	assert_gt(walk.size(), 2, "no squeezing between the corners of two walls")


func test_a_blocked_or_cut_off_goal_gives_no_walk() -> void:
	var graph := _graph(6, 6, [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2)] as Array[Vector2i])
	assert_eq(graph.walk(Vector2i(0, 0), Vector2i(3, 1)).size(), 0, "a closed goal")
	var wall: Array[Vector2i] = []
	for y in 6:
		wall.append(Vector2i(3, y))
	assert_eq(_graph(6, 6, wall).walk(Vector2i(0, 0), Vector2i(5, 5)).size(), 0, "cut off")


func test_a_walk_never_clips_a_closed_cell_and_is_never_longer_than_the_grid_path() -> void:
	var boards: Array[GameMap] = []
	for map_seed in [1, 2, 7, 42]:
		boards.append(Game.create(map_seed).map)
		boards.append(Game.create_on_strip_valley(map_seed).map)
	var checked := 0
	for map in boards:
		var graph := HeroGraph.from_map(map)
		var cells: Array[Vector2i] = []
		for y in graph.rows:
			for x in graph.cols:
				if graph.is_open(Vector2i(x, y)):
					cells.append(Vector2i(x, y))
		var home := map.path[0]
		var goal := map.heartstone.position
		var pairs: Array[Array] = [[home, goal], [goal, home]]
		for i in range(0, cells.size() - 37, 37):
			pairs.append([cells[i], cells[i + 37]])
		for pair in pairs:
			var from: Vector2i = pair[0]
			var to: Vector2i = pair[1]
			if not graph.is_open(from) or not graph.is_open(to):
				continue
			var grid := graph.path(from, to)
			var walk := graph.walk(from, to)
			assert_eq(walk.is_empty(), grid.is_empty())
			if walk.is_empty():
				continue
			checked += 1
			assert_eq([walk[0], walk.back()], [from, to])
			assert_lte(_length(walk), _length(grid) + 1e-9)
			for k in walk.size() - 1:
				assert_true(
					_body_clear(graph, walk[k], walk[k + 1]),
					"seed %d %s to %s leg %d" % [map.seed, from, to, k]
				)
	assert_gt(checked, 100)


func test_the_walk_crosses_the_bridges_of_the_valley() -> void:
	for map_seed in [1, 2, 3]:
		var map := Game.create(map_seed).map
		var graph := HeroGraph.from_map(map)
		var walk := graph.walk(map.path[0], map.path[map.path.size() - 1])
		assert_false(walk.is_empty(), "seed %d" % map_seed)
		var crossed := 0
		for bridge in map.bridges:
			for k in walk.size() - 1:
				if _passes(walk[k], walk[k + 1], bridge.cell):
					crossed += 1
					break
		assert_gt(crossed, 0, "seed %d: the walk uses a bridge" % map_seed)


func _passes(a: Vector2i, b: Vector2i, cell: Vector2i) -> bool:
	var from := Vector2(a) + Vector2(0.5, 0.5)
	var to := Vector2(b) + Vector2(0.5, 0.5)
	for i in 401:
		var p := from.lerp(to, float(i) / 400.0)
		if Vector2i(floori(p.x), floori(p.y)) == cell:
			return true
	return false


func test_a_hero_at_a_centre_keeps_its_own_cell_first_in_its_walk() -> void:
	var game := Game.create(42, 16, 11)
	Heroes.place(game, "knightOfCardboard")
	var start := game.hero.cell
	Heroes.order(game, Command.move_hero(start.x - 2, start.y + 1))
	assert_eq(game.hero.path[0], start)
	assert_eq(game.hero.path.back(), start + Vector2i(-2, 1))
