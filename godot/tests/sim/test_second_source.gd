## The second spawn source: a feeder road from another edge that joins the main road, used by
## half of each wave from wave 11 on.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const WAVES := preload("res://content/waves.gd")

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 60:
		_seeds.append(i * 7919 + 1)


func _map(map_seed: int, second: bool = true) -> GameMap:
	return MapGen.generate(
		map_seed, RULES.GRID_COLS, RULES.GRID_ROWS, false, RULES.GAME_SOCKET_FOOTPRINT, second
	)


func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func test_most_maps_get_a_second_route() -> void:
	var with_second := 0
	for map_seed in _seeds:
		if _map(map_seed).routes.size() == 2:
			with_second += 1
	assert_gte(with_second, 40, "at least 2 maps in 3 have room for the feeder")


func test_the_main_road_is_the_same_with_or_without_the_second_source() -> void:
	for map_seed in _seeds:
		assert_eq(_map(map_seed).path, _map(map_seed, false).path, "seed %d" % map_seed)


func test_the_feeder_starts_on_the_top_or_bottom_edge_and_runs_to_the_main_road() -> void:
	for map_seed in _seeds:
		var map := _map(map_seed)
		if map.routes.size() < 2:
			continue
		var feeder: Array = map.routes[1]
		var main: Array = map.routes[0]
		var start: Vector2i = feeder[0]
		assert_true(start.y == 0 or start.y == map.rows - 1, "edge, seed %d" % map_seed)
		assert_gte(map.feeder_length, RULES.FEEDER_MIN_CELLS, "seed %d" % map_seed)
		# the second route is the feeder, then the main road from the join cell on
		var join: int = map.join_index
		assert_eq(feeder.slice(map.feeder_length), main.slice(join), "tail, seed %d" % map_seed)
		assert_lte(_gap(feeder[map.feeder_length - 1], main[join]), 1, "touches the join")
		for i in range(1, feeder.size()):
			assert_eq(_gap(feeder[i - 1], feeder[i]), 1, "contiguous, seed %d" % map_seed)
		for cell in feeder:
			assert_true(cell.x >= 0 and cell.x < map.cols and cell.y >= 0 and cell.y < map.rows)


func test_the_feeder_only_touches_the_main_road_at_the_join() -> void:
	for map_seed in _seeds:
		var map := _map(map_seed)
		if map.routes.size() < 2:
			continue
		var main: Array = map.routes[0]
		var feeder: Array = map.routes[1]
		for i in map.feeder_length:
			for m in main.size():
				var close := _gap(feeder[i], main[m]) < 2
				var is_join := i == map.feeder_length - 1 and m == map.join_index
				assert_false(close and not is_join, "seed %d feeder %d main %d" % [map_seed, i, m])


func test_the_join_is_in_the_first_part_of_the_road() -> void:
	for map_seed in _seeds:
		var map := _map(map_seed)
		if map.routes.size() < 2:
			continue
		assert_lte(
			map.join_index * 100,
			map.path.size() * RULES.FEEDER_JOIN_MAX_PERCENT,
			"seed %d" % map_seed
		)


func test_the_join_is_well_inside_the_road() -> void:
	for map_seed in _seeds:
		var map := _map(map_seed)
		if map.routes.size() < 2:
			continue
		assert_gte(map.join_index, RULES.FEEDER_JOIN_MARGIN)
		assert_lte(map.join_index, map.path.size() - RULES.FEEDER_JOIN_MARGIN)


func test_the_feeder_cells_are_road_and_no_socket_sits_on_them() -> void:
	for map_seed in _seeds:
		var map := _map(map_seed)
		if map.routes.size() < 2:
			continue
		for cell in map.routes[1]:
			assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD)
			assert_eq(map.socket_anchor_at(cell), GameMap.NO_SOCKET)


func test_the_same_seed_gives_the_same_second_route() -> void:
	assert_eq(_map(42).routes, _map(42).routes)


func test_a_game_has_both_routes_and_the_main_foes_pick_the_main_one() -> void:
	var game := _two_route_game()
	assert_eq(game.routes.size(), 2)
	var before := game.route_rng.state
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1)
	assert_eq(foe.route, 0, "a plain spawn uses the main road")
	assert_eq(game.route_rng.state, before, "and draws nothing")


func test_the_second_route_joins_the_main_one_at_a_known_distance() -> void:
	var game := _two_route_game()
	var main := game.routes[0]
	var second := game.routes[1]
	var offset := game.second_offset
	# one cell past the join the foe stands where a main-road foe at that distance stands
	var on_second := second.cumulative[game.map.feeder_length + 1] + 2.0
	var a := second.position_at(on_second)
	var b := main.position_at(on_second - offset)
	assert_almost_eq(a.x, b.x, 1e-9)
	assert_almost_eq(a.y, b.y, 1e-9)


func _two_route_game() -> GameState:
	for map_seed in range(1, 40):
		var game := Game.create(map_seed)
		if game.routes.size() == 2:
			return game
	return null


func test_the_second_roads_foes_enter_at_the_edge_their_road_starts_on() -> void:
	# a road from the bottom edge starts below the board, not above it (it once started above
	# the top edge and crossed the whole board)
	var checked := 0
	for map_seed in _seeds:
		var game := Game.create(map_seed)
		if game.routes.size() < 2:
			continue
		checked += 1
		var first_step: float = game.routes[1].cumulative[1]
		assert_lte(first_step, RULES.CELL_CENTRE + RULES.SPAWN_OFFSET + 1e-9, "seed %d" % map_seed)
		# and the spawn point is off the board, on the edge the road starts on
		var spawn_y: float = game.routes[1].ys[0]
		assert_true(spawn_y < 0.0 or spawn_y > float(RULES.GRID_ROWS), "seed %d" % map_seed)
	assert_gt(checked, 30)


func test_the_feeder_order_comes_from_its_own_stream() -> void:
	# the shuffle is drawn from `Streams.SECOND_SOURCE`: another stream gives another order
	var differing := 0
	for map_seed in _seeds:
		var path := MapGen._try_path(
			Rng.derive(map_seed, Streams.MAP), RULES.GRID_ROWS, RULES.GRID_COLS
		)
		if path.is_empty():
			continue
		var a := MapGen._feeders(path, Rng.derive(map_seed, Streams.SECOND_SOURCE), 11, 16)
		var b := MapGen._feeders(path, Rng.derive(map_seed + 1, Streams.SECOND_SOURCE), 11, 16)
		if a.size() > 3 and a != b:
			differing += 1
	assert_gt(differing, 10, "the order depends on the stream")
