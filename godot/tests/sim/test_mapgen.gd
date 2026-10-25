## Map generation must reproduce the TypeScript maps exactly.
extends GutTest

const MAPS_FIXTURE := "res://../fixtures/maps.json"
const RULES := preload("res://content/map_rules.gd")

var _fixtures: Array = []


func before_all() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(MAPS_FIXTURE))
	_fixtures = JSON.parse_string(text)


func _cells(raw: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair in raw:
		cells.append(Vector2i(int(pair[0]), int(pair[1])))
	return cells


func _tile_strings(map: GameMap) -> Array:
	var rows := []
	for line in map.tiles:
		var text := ""
		for tile in line:
			text += "#" if tile == GameMap.Tile.ROAD else "."
		rows.append(text)
	return rows


func test_every_fixture_map_matches_exactly() -> void:
	assert_eq(_fixtures.size(), 120)
	for entry in _fixtures:
		var map := MapGen.generate(int(entry.seed), RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		assert_eq(map.path, _cells(entry.path), "path of seed %d" % entry.seed)
		assert_eq(map.routes.size(), entry.routes.size(), "route count of seed %d" % entry.seed)
		for i in entry.routes.size():
			assert_eq(
				map.routes[i], _cells(entry.routes[i]), "route %d of seed %d" % [i, entry.seed]
			)
		assert_eq(_tile_strings(map), entry.tiles, "tiles of seed %d" % entry.seed)


func test_same_seed_gives_the_same_map() -> void:
	var a := MapGen.generate(4242, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
	var b := MapGen.generate(4242, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
	assert_eq(a.path, b.path)
	assert_eq(a.routes, b.routes)
	assert_eq(a.tiles, b.tiles)


func test_different_seeds_give_different_maps() -> void:
	var paths := {}
	for seed in range(1, 40):
		paths[MapGen.generate(seed, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1).path] = true
	assert_gt(paths.size(), 30)


func test_routes_are_valid_for_every_fixture_seed() -> void:
	for entry in _fixtures:
		var map := MapGen.generate(int(entry.seed), RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		assert_eq(map.routes[0], map.path, "main road is routes[0], seed %d" % entry.seed)
		for route in map.routes:
			var first: Vector2i = route[0]
			var last: Vector2i = route[route.size() - 1]
			assert_eq(first, map.path[0], "start, seed %d" % entry.seed)
			assert_eq(last, map.path[map.path.size() - 1], "end, seed %d" % entry.seed)
			assert_eq(first.y, 0)
			assert_eq(last.y, RULES.LEGACY_ROWS - 1)
			var seen := {}
			for i in route.size():
				var cell: Vector2i = route[i]
				assert_true(
					cell.x >= 0 and cell.x < RULES.LEGACY_COLS, "inside, seed %d" % entry.seed
				)
				assert_true(
					cell.y >= 0 and cell.y < RULES.LEGACY_ROWS, "inside, seed %d" % entry.seed
				)
				assert_false(seen.has(cell), "route never revisits a cell, seed %d" % entry.seed)
				seen[cell] = true
				if i > 0:
					var step: Vector2i = cell - route[i - 1]
					assert_eq(
						absi(step.x) + absi(step.y), 1, "one orthogonal step, seed %d" % entry.seed
					)
				# a route never touches itself: no earlier cell but the previous one is adjacent
				for j in range(0, i - 1):
					var apart: Vector2i = cell - route[j]
					assert_ne(
						absi(apart.x) + absi(apart.y), 1, "touches itself, seed %d" % entry.seed
					)


func test_road_tiles_are_exactly_the_route_cells() -> void:
	for seed in range(1, 60):
		var map := MapGen.generate(seed, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		var road := {}
		for route in map.routes:
			for cell in route:
				road[cell] = true
		var count := 0
		for row in RULES.LEGACY_ROWS:
			for col in RULES.LEGACY_COLS:
				var is_road: bool = map.tiles[row][col] == GameMap.Tile.ROAD
				assert_eq(
					is_road, road.has(Vector2i(col, row)), "seed %d cell %d,%d" % [seed, col, row]
				)
				count += 1 if is_road else 0
		assert_eq(count, road.size())


func test_most_maps_get_one_detour_and_never_more() -> void:
	var with_detour := 0
	for seed in range(1, 60):
		var map := MapGen.generate(seed, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		assert_between(map.routes.size(), 1, 2)
		with_detour += 1 if map.routes.size() == 2 else 0
	assert_gt(with_detour, 30)


## The game board and the Board draw the same map: both ask `MapGen.game_map`. Its fallback to
## the route-first map cannot be tested: no seed makes the valley fail, and the stitcher takes
## no injected sections.
## About THE GAME BOARD: follows the default board, whatever `Game.create` plays.
func test_the_game_map_is_the_map_the_game_plays() -> void:
	for map_seed in [1, 2, 3]:
		assert_eq(MapGen.game_map(map_seed).path, Game.create(map_seed).map.path)
