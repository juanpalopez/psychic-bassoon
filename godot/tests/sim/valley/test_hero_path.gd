extends GutTest

## The hero's path on a finished board (#449).

const SEEDS: Array[int] = [1, 42, 2026]


func _on_river(map: GameMap, cell: Vector2i) -> bool:
	return map.river.has(cell)


func _is_bridge(map: GameMap, cell: Vector2i) -> bool:
	return (
		map.hero_bridges.has(cell)
		or map.bridges.any(func(bridge: GameMap.Bridge) -> bool: return bridge.cell == cell)
	)


## The first cell from `cell` in `step` direction that is off the river.
func _bank(map: GameMap, cell: Vector2i, step: Vector2i) -> Vector2i:
	var here := cell
	while _on_river(map, here):
		here += step
	return here


func test_the_graph_of_a_valley_opens_its_walkable_cells_and_both_bridges() -> void:
	var map := MapGen.game_map(42)
	var graph := HeroGraph.from_map(map)
	assert_eq(graph.cols, map.cols)
	assert_eq(graph.rows, map.rows)
	for y in map.rows:
		for x in map.cols:
			var cell := Vector2i(x, y)
			var open := map.is_walkable(cell) or _is_bridge(map, cell)
			assert_eq(graph.steps(cell, cell) == 0, open, "%s" % cell)


func test_a_board_without_a_walkable_layer_is_open_everywhere() -> void:
	var map := MapGen.generate(1, 16, 11)
	assert_true(map.walkable.is_empty())
	var graph := HeroGraph.from_map(map)
	assert_eq(graph.steps(Vector2i(0, 0), Vector2i(15, 10)), 25)


func test_a_path_to_the_same_cell_is_that_cell() -> void:
	var graph := HeroGraph.from_map(MapGen.generate(1, 16, 11))
	assert_eq(graph.path(Vector2i(3, 4), Vector2i(3, 4)), [Vector2i(3, 4)] as Array[Vector2i])


func test_equally_short_paths_are_broken_by_the_neighbour_order() -> void:
	# at every cell the walk takes the first step in NEIGHBOURS (left, right, up, down) that
	# gets closer, so on open ground it runs along the row before the column
	var graph := HeroGraph.from_map(MapGen.generate(1, 16, 11))
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)
	]
	assert_eq(graph.path(Vector2i(0, 0), Vector2i(2, 2)), expected)


func test_a_path_is_a_shortest_walk_of_open_neighbouring_cells() -> void:
	for seed in SEEDS:
		var map := MapGen.game_map(seed)
		var graph := HeroGraph.from_map(map)
		var from: Vector2i = map.path[0]
		var to: Vector2i = map.path[map.path.size() - 1]
		var cells := graph.path(from, to)
		assert_eq(cells.size(), graph.steps(from, to) + 1, "seed %d" % seed)
		assert_eq(cells[0], from)
		assert_eq(cells[cells.size() - 1], to)
		for index in range(1, cells.size()):
			var gap := cells[index] - cells[index - 1]
			assert_eq(absi(gap.x) + absi(gap.y), 1, "seed %d step %d" % [seed, index])
			assert_eq(graph.steps(cells[index], cells[index]), 0, "seed %d open" % seed)


func test_a_path_crosses_the_river_only_on_a_bridge() -> void:
	for seed in SEEDS:
		var map := MapGen.game_map(seed)
		var cells := HeroGraph.from_map(map).path(map.path[0], map.path[map.path.size() - 1])
		for cell in cells:
			if _on_river(map, cell):
				assert_true(_is_bridge(map, cell), "seed %d at %s" % [seed, cell])


func test_the_hero_bridge_gives_a_straight_crossing_on_its_row() -> void:
	for seed in SEEDS:
		var map := MapGen.game_map(seed)
		assert_false(map.hero_bridges.is_empty(), "seed %d" % seed)
		var bridge: Vector2i = map.hero_bridges[0]
		var west := _bank(map, bridge, Vector2i.LEFT)
		var east := _bank(map, bridge, Vector2i.RIGHT)
		var cells := HeroGraph.from_map(map).path(west, east)
		assert_eq(cells.size() - 1, east.x - west.x, "seed %d" % seed)
		assert_true(cells.has(bridge), "seed %d" % seed)


func test_a_closed_or_cut_off_end_gives_an_empty_path() -> void:
	var map := MapGen.game_map(42)
	var graph := HeroGraph.from_map(map)
	var wet := Vector2i(-1, -1)
	for cell in map.river:
		if not _is_bridge(map, cell):
			wet = cell
			break
	assert_ne(wet, Vector2i(-1, -1))
	assert_true(graph.path(map.path[0], wet).is_empty())
	assert_true(graph.path(wet, map.path[0]).is_empty())
	assert_true(graph.path(map.path[0], Vector2i(-1, 0)).is_empty())


func test_the_same_ends_always_give_the_same_path() -> void:
	var map := MapGen.game_map(2026)
	var from: Vector2i = map.path[0]
	var to: Vector2i = map.path[map.path.size() - 1]
	assert_eq(HeroGraph.from_map(map).path(from, to), HeroGraph.from_map(map).path(from, to))
