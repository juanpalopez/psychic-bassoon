## Sockets and elevation: the GDD's pre-etched tower sites, a new map layer on
## top of the ported road generator. They draw from their own random stream, so
## the road fixtures keep matching.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const GOLDEN := "res://tests/goldens/sockets.json"

## The 120 seeds of the road fixtures, plus a few more.
var _seeds: Array[int] = []


func before_all() -> void:
	for i in 120:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _is_road(map: GameMap, cell: Vector2i) -> bool:
	return map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD


func _nearest_road(map: GameMap, cell: Vector2i) -> int:
	var best := 1000
	for row in RULES.GRID_ROWS:
		for col in RULES.GRID_COLS:
			if map.tiles[row][col] == GameMap.Tile.ROAD:
				best = mini(best, maxi(absi(col - cell.x), absi(row - cell.y)))
	return best


func test_every_map_has_the_right_number_of_sockets() -> void:
	for map_seed in _seeds:
		var count := MapGen.generate(map_seed).sockets.size()
		# the GDD says 12 to 22 sockets per map
		assert_between(count, 12, 22, "seed %d" % map_seed)


func test_sockets_are_distinct_cells_on_the_board_in_reading_order() -> void:
	for map_seed in _seeds:
		var sockets := MapGen.generate(map_seed).sockets
		var seen := {}
		var previous := Vector2i(-1, -1)
		for cell in sockets:
			assert_true(cell.x >= 0 and cell.x < RULES.GRID_COLS, "col, seed %d" % map_seed)
			assert_true(cell.y >= 0 and cell.y < RULES.GRID_ROWS, "row, seed %d" % map_seed)
			assert_false(seen.has(cell), "unique, seed %d" % map_seed)
			seen[cell] = true
			# row first, then column
			assert_true(
				cell.y > previous.y or (cell.y == previous.y and cell.x > previous.x),
				"reading order, seed %d" % map_seed
			)
			previous = cell


func test_a_socket_is_never_on_the_road() -> void:
	for map_seed in _seeds:
		var map := MapGen.generate(map_seed)
		for cell in map.sockets:
			assert_false(_is_road(map, cell), "seed %d at %s" % [map_seed, cell])


func test_every_socket_is_within_reach_of_the_road() -> void:
	for map_seed in _seeds:
		var map := MapGen.generate(map_seed)
		for cell in map.sockets:
			assert_lte(
				_nearest_road(map, cell), RULES.SOCKET_REACH, "seed %d at %s" % [map_seed, cell]
			)


func test_sockets_keep_their_distance() -> void:
	for map_seed in _seeds:
		var sockets := MapGen.generate(map_seed).sockets
		for i in sockets.size():
			for j in range(i + 1, sockets.size()):
				var apart := sockets[i] - sockets[j]
				assert_gte(
					absi(apart.x) + absi(apart.y),
					2,
					"seed %d: %s and %s" % [map_seed, sockets[i], sockets[j]]
				)


func test_the_same_seed_gives_the_same_sockets_and_elevation() -> void:
	var a := MapGen.generate(4242)
	var b := MapGen.generate(4242)
	assert_eq(a.sockets, b.sockets)
	assert_eq(a.elevation, b.elevation)


func test_different_seeds_give_different_sockets() -> void:
	var layouts := {}
	for map_seed in range(1, 40):
		layouts[MapGen.generate(map_seed).sockets] = true
	assert_gt(layouts.size(), 30)


func test_sockets_do_not_change_the_road() -> void:
	# the road fixtures are checked in test_mapgen; this pins that placing sockets
	# leaves the road and the tiles alone
	for map_seed in [1, 7920, 15839]:
		var map := MapGen.generate(map_seed)
		var road := {}
		for route in map.routes:
			for cell in route:
				road[cell] = true
		for row in RULES.GRID_ROWS:
			for col in RULES.GRID_COLS:
				var is_road: bool = map.tiles[row][col] == GameMap.Tile.ROAD
				assert_eq(is_road, road.has(Vector2i(col, row)))


func test_elevation_is_a_level_from_0_to_2_and_flat_off_the_sockets() -> void:
	for map_seed in _seeds:
		var map := MapGen.generate(map_seed)
		assert_eq(map.elevation.size(), RULES.GRID_ROWS)
		for row in RULES.GRID_ROWS:
			for col in RULES.GRID_COLS:
				var level := map.elevation_at(Vector2i(col, row))
				assert_between(level, 0, 2)
				if not map.is_socket(Vector2i(col, row)):
					assert_eq(level, 0, "ground and road are level 0, seed %d" % map_seed)


func test_all_three_levels_appear_and_the_flat_one_is_the_most_common() -> void:
	var counts := [0, 0, 0]
	for map_seed in _seeds:
		var map := MapGen.generate(map_seed)
		for cell in map.sockets:
			counts[map.elevation_at(cell)] += 1
	assert_gt(counts[1], 0)
	assert_gt(counts[2], 0)
	assert_gt(counts[0], counts[1])
	assert_gt(counts[1], counts[2])


func test_a_level_2_socket_gives_a_15_percent_range_bonus() -> void:
	var found := {}
	for map_seed in range(1, 60):
		var map := MapGen.generate(map_seed)
		for cell in map.sockets:
			found[map.elevation_at(cell)] = map.range_multiplier(cell)
		# a cell that is not a socket gets no bonus
		assert_eq(map.range_multiplier(map.path[0]), 1.0)
	assert_eq(found[0], 1.0)
	assert_eq(found[1], 1.0)
	assert_eq(found[2], 1.15)


func test_the_socket_stream_id_is_frozen() -> void:
	assert_eq(Streams.SOCKETS, 3)


func test_sockets_match_the_golden_written_by_the_gdscript_sim() -> void:
	# regenerate with: godot --headless --path godot -s tools/write_sockets_golden.gd
	# (only by a reviewed balance change)
	var text := FileAccess.get_file_as_string(GOLDEN)
	var golden: Array = JSON.parse_string(text)
	assert_gt(golden.size(), 5)
	for entry in golden:
		var map := MapGen.generate(int(entry.seed))
		var cells := []
		var levels := []
		for cell in map.sockets:
			cells.append([cell.x, cell.y])
			levels.append(map.elevation_at(cell))
		assert_eq(cells, _ints(entry.sockets), "sockets, seed %d" % entry.seed)
		assert_eq(levels, _ints(entry.levels), "levels, seed %d" % entry.seed)


## JSON gives floats; the golden holds whole numbers.
func _ints(value: Variant) -> Variant:
	if value is Array:
		var out := []
		for item in value:
			out.append(_ints(item))
		return out
	return int(value)
