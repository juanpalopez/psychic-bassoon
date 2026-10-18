## The game's board is the 32 by 20 valley (owner, 2026-10-18, #320): the road crosses the long
## side from the left edge to the right, winds with longer straight runs and shorter sideways
## turns than the classic shape, and the board holds more sockets.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const COLS := 32
const ROWS := 20

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 200:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _valley(map_seed: int) -> GameMap:
	return MapGen.generate(map_seed, COLS, ROWS, false, RULES.GAME_SOCKET_FOOTPRINT, false)


func test_the_game_builds_the_valley_by_default() -> void:
	assert_eq([RULES.GRID_COLS, RULES.GRID_ROWS], [COLS, ROWS])
	assert_gte(RULES.GRID_COLS, RULES.VALLEY_MIN_COLS, "the game board uses the valley shape")
	var game := Game.create(1)
	assert_eq([game.map.cols, game.map.rows], [COLS, ROWS])
	assert_eq(game.map.footprint, 2)
	assert_between(game.routes.size(), 1, 2, "the main road, and a feeder when it fits")
	assert_false(game.random_lanes, "foes do not pick a lane at random")


func test_the_road_crosses_the_valley_as_one_valid_path_for_every_seed() -> void:
	for map_seed in _seeds:
		var path := _valley(map_seed).path
		assert_eq(path[0].x, 0, "starts on the left edge, seed %d" % map_seed)
		assert_eq(path[path.size() - 1].x, COLS - 1, "ends on the right edge, seed %d" % map_seed)
		assert_gte(
			path.size(), COLS + RULES.VALLEY_MIN_EXTRA_CELLS, "long enough, seed %d" % map_seed
		)
		var seen := {}
		for i in path.size():
			var cell := path[i]
			assert_true(cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS)
			assert_false(seen.has(cell), "no cell twice, seed %d" % map_seed)
			seen[cell] = true
			if i > 0:
				var step := path[i] - path[i - 1]
				assert_eq(absi(step.x) + absi(step.y), 1, "4-connected, seed %d" % map_seed)


## The straight runs along the road (in board columns) and the sideways turns (in rows), in
## order. The board is drawn turned, so the generator's runs down are runs to the right here.
func _runs(path: Array[Vector2i]) -> Dictionary:
	var along: Array[int] = []
	var across: Array[int] = []
	var i := 1
	while i < path.size():
		var horizontal := path[i].y == path[i - 1].y
		var length := 0
		while i < path.size() and (path[i].y == path[i - 1].y) == horizontal:
			length += 1
			i += 1
		if horizontal:
			along.append(length)
		else:
			across.append(length)
	return {"along": along, "across": across}


func test_the_road_winds_with_long_runs_and_short_turns() -> void:
	for map_seed in _seeds:
		var runs := _runs(_valley(map_seed).path)
		var along: Array[int] = runs.along
		# every run but the last (cut short by the edge) is at least the valley's minimum
		for k in along.size() - 1:
			assert_gte(along[k], RULES.VALLEY_MIN_RUN_DOWN, "run %d, seed %d" % [k, map_seed])
		for turn: int in runs.across:
			assert_between(
				turn,
				RULES.VALLEY_MIN_TURN_COLUMNS,
				RULES.VALLEY_MAX_TURN_COLUMNS,
				"turn, seed %d" % map_seed
			)


func test_every_valley_map_holds_its_sockets_off_the_road() -> void:
	for map_seed in _seeds:
		var map := _valley(map_seed)
		assert_between(
			map.sockets.size(),
			RULES.VALLEY_SOCKET_MIN,
			RULES.VALLEY_SOCKET_MAX,
			"count, seed %d" % map_seed
		)
		for anchor in map.sockets:
			for dy in map.footprint:
				for dx in map.footprint:
					var cell := anchor + Vector2i(dx, dy)
					assert_true(cell.x < COLS and cell.y < ROWS, "inside, seed %d" % map_seed)
					assert_ne(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "seed %d" % map_seed)
					assert_false(map.heartstone.has_point(cell), "seed %d" % map_seed)


func test_the_game_road_length_and_sockets_on_average() -> void:
	# a winding road about 1.6 times the 16 by 11 board's (about 45 cells): about 74
	var length := 0
	var sockets := 0
	for map_seed in range(1, 41):
		var map := Game.create(map_seed).map
		length += map.path.size()
		sockets += map.sockets.size()
	var mean_length := float(length) / 40.0
	var mean_sockets := float(sockets) / 40.0
	assert_between(mean_length, 65.0, 90.0, "mean road length %.1f" % mean_length)
	assert_between(mean_sockets, 24.0, 30.0, "mean sockets %.1f" % mean_sockets)


func test_the_same_seed_gives_the_same_valley() -> void:
	var a := Game.create(42).map
	var b := Game.create(42).map
	assert_eq(a.routes, b.routes)
	assert_eq(a.sockets, b.sockets)
	assert_eq(a.elevation, b.elevation)
	assert_ne(Game.create(43).map.routes, a.routes)


func test_the_classic_boards_keep_the_classic_shape() -> void:
	# the 16 by 11 board still turns across up to its whole height (the valley caps turns)
	var widest := 0
	for map_seed in _seeds:
		var path := MapGen.generate(map_seed, 16, 11, false, 2, false).path
		for turn: int in _runs(path).across:
			widest = maxi(widest, turn)
	assert_gt(widest, RULES.VALLEY_MAX_TURN_COLUMNS, "classic turns are not capped")
