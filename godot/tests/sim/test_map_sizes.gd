## The road generator takes the board size. At 9 by 13 it is still the ported
## generator (the frozen fixtures check that in test_mapgen). At the GDD's
## landscape 22 by 16 the road crosses the long side from the left edge to the
## right, and by default it is one road with no detour.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const COLS := 16
const ROWS := 11

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 60:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _landscape(map_seed: int, with_detour: bool = false) -> GameMap:
	return MapGen.generate(map_seed, COLS, ROWS, with_detour, 1)


func test_the_content_names_both_board_sizes() -> void:
	assert_eq([RULES.LEGACY_COLS, RULES.LEGACY_ROWS], [9, 13])
	assert_eq([RULES.LANDSCAPE_COLS, RULES.LANDSCAPE_ROWS], [16, 11])


func test_a_map_knows_its_size() -> void:
	var map := _landscape(1)
	assert_eq([map.cols, map.rows], [COLS, ROWS])
	assert_eq(map.tiles.size(), ROWS)
	for line in map.tiles:
		assert_eq(line.size(), COLS)
	assert_eq(map.elevation.size(), ROWS)
	for line in map.elevation:
		assert_eq(line.size(), COLS)
	var legacy := MapGen.generate(1, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
	assert_eq([legacy.cols, legacy.rows], [9, 13])


func test_the_road_runs_from_the_left_edge_to_the_right_edge() -> void:
	for map_seed in _seeds:
		var path := _landscape(map_seed).path
		assert_eq(path[0].x, 0, "starts on the left edge, seed %d" % map_seed)
		assert_eq(path[path.size() - 1].x, COLS - 1, "ends on the right edge, seed %d" % map_seed)
		# it starts and ends away from the top and bottom edges
		assert_between(path[0].y, 1, ROWS - 2, "start row, seed %d" % map_seed)


func test_the_road_is_a_valid_path_for_every_seed() -> void:
	for map_seed in _seeds:
		var path := _landscape(map_seed).path
		assert_gte(path.size(), COLS + RULES.MIN_EXTRA_CELLS, "long enough, seed %d" % map_seed)
		for i in path.size():
			var cell := path[i]
			assert_true(cell.x >= 0 and cell.x < COLS, "inside, seed %d" % map_seed)
			assert_true(cell.y >= 0 and cell.y < ROWS, "inside, seed %d" % map_seed)
			if i > 0:
				var step := cell - path[i - 1]
				assert_eq(absi(step.x) + absi(step.y), 1, "one orthogonal step, seed %d" % map_seed)
			# the road never touches itself: only the previous cell is adjacent
			for j in range(0, i - 1):
				var apart := cell - path[j]
				assert_ne(absi(apart.x) + absi(apart.y), 1, "touches itself, seed %d" % map_seed)
				assert_ne(apart, Vector2i.ZERO, "revisits a cell, seed %d" % map_seed)


func test_by_default_a_landscape_road_has_no_detour() -> void:
	for map_seed in _seeds:
		var map := _landscape(map_seed)
		assert_eq(map.routes.size(), 1, "seed %d" % map_seed)
		assert_eq(map.routes[0], map.path)


func test_a_detour_can_be_asked_for_and_is_valid() -> void:
	var with_detour := 0
	for map_seed in _seeds:
		var map := _landscape(map_seed, true)
		assert_between(map.routes.size(), 1, 2)
		if map.routes.size() < 2:
			continue
		with_detour += 1
		var detour: Array = map.routes[1]
		assert_eq(detour[0], map.path[0], "leaves at the start, seed %d" % map_seed)
		assert_eq(detour[detour.size() - 1], map.path[map.path.size() - 1], "ends at the end")
		var seen := {}
		for cell in detour:
			assert_true(cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS)
			assert_false(seen.has(cell), "never revisits, seed %d" % map_seed)
			seen[cell] = true
	assert_gt(with_detour, 30, "most boards have room for one")


func test_the_tiles_are_exactly_the_road_cells() -> void:
	for map_seed in _seeds:
		var map := _landscape(map_seed, true)
		var road := {}
		for route in map.routes:
			for cell in route:
				road[cell] = true
		var count := 0
		for row in ROWS:
			for col in COLS:
				var is_road: bool = map.tiles[row][col] == GameMap.Tile.ROAD
				assert_eq(
					is_road, road.has(Vector2i(col, row)), "seed %d %d,%d" % [map_seed, col, row]
				)
				count += 1 if is_road else 0
		assert_eq(count, road.size())


func test_the_same_seed_gives_the_same_map_and_seeds_differ() -> void:
	assert_eq(_landscape(4242).path, _landscape(4242).path)
	assert_eq(_landscape(4242).sockets, _landscape(4242).sockets)
	var paths := {}
	for map_seed in range(1, 60):
		paths[_landscape(map_seed).path] = true
	assert_gt(paths.size(), 50)


func test_the_road_uses_the_board_it_is_given() -> void:
	# a long thin board and a small one still work
	for size in [Vector2i(22, 16), Vector2i(30, 12)]:
		for map_seed in range(1, 30):
			var map := MapGen.generate(map_seed, size.x, size.y, false)
			assert_eq(map.path[0].x, 0)
			assert_eq(map.path[map.path.size() - 1].x, size.x - 1)
			for cell in map.path:
				assert_true(cell.x < size.x and cell.y < size.y)


func test_a_landscape_route_starts_off_the_left_edge_and_ends_at_the_heartstone() -> void:
	for map_seed in range(1, 40):
		var map := _landscape(map_seed)
		var route := Route.build(map.path)
		var start := route.position_at(0.0)
		assert_eq(start.x, -RULES.SPAWN_OFFSET)
		assert_eq(start.y, float(map.path[0].y) + RULES.CELL_CENTRE)
		var end := route.position_at(route.total)
		var last := map.path[map.path.size() - 1]
		assert_eq(end.x, float(last.x) + RULES.CELL_CENTRE)
		assert_eq(end.y, float(last.y) + RULES.CELL_CENTRE)
		# the walk to the first cell is the spawn offset plus half a cell
		assert_almost_eq(route.cumulative[1], RULES.SPAWN_OFFSET + RULES.CELL_CENTRE, 1e-12)


func test_a_portrait_route_still_starts_above_the_top_edge() -> void:
	var map := MapGen.generate(1, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
	var route := Route.build(map.path)
	var start := route.position_at(0.0)
	assert_eq(start.y, -RULES.SPAWN_OFFSET)
	assert_eq(start.x, float(map.path[0].x) + RULES.CELL_CENTRE)


func test_every_landscape_map_gets_12_to_22_sockets_off_the_road_within_reach() -> void:
	for map_seed in _seeds:
		var map := _landscape(map_seed)
		assert_between(map.sockets.size(), 12, 22, "count, seed %d" % map_seed)
		for cell in map.sockets:
			assert_true(cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS)
			assert_ne(
				map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "on the road, seed %d" % map_seed
			)
			var best := 1000
			for road_cell in map.path:
				best = mini(best, maxi(absi(road_cell.x - cell.x), absi(road_cell.y - cell.y)))
			assert_lte(best, RULES.SOCKET_REACH, "out of reach, seed %d" % map_seed)
		assert_eq(map.elevation.size(), ROWS)


func test_the_game_builds_the_gdd_board_by_default() -> void:
	var game := Game.create(1)
	assert_eq([game.map.cols, game.map.rows], [COLS, ROWS])
	assert_eq([RULES.GRID_COLS, RULES.GRID_ROWS], [COLS, ROWS])
	assert_eq(game.map.footprint, 2)
	assert_eq(game.routes.size(), 1, "one road, no detour")
	assert_false(RULES.GAME_DETOUR)


func test_the_game_road_is_about_45_cells_and_holds_12_to_15_sockets() -> void:
	# the 16 by 11 board: a road a good third shorter than the 22 by 16 one (about 76)
	var total := 0
	for map_seed in range(1, 21):
		var map := MapGen.generate(map_seed, COLS, ROWS, false, RULES.SOCKET_FOOTPRINT)
		total += map.path.size()
		assert_gte(map.sockets.size(), RULES.SOCKET_MIN, "seed %d" % map_seed)
		assert_lte(map.sockets.size(), RULES.SOCKET_MAX, "seed %d" % map_seed)
	var mean := float(total) / 20.0
	assert_between(mean, 40.0, 50.0, "mean road length %.1f" % mean)
	assert_eq([RULES.SOCKET_MIN, RULES.SOCKET_MAX], [12, 15])
