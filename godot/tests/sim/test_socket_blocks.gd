## A socket as a 2x2 block of cells (GDD): the sim anchors it on its top-left
## cell and owns the four cells. Blocks never overlap each other, the road or the
## Heartstone's footprint, always leave a cell of gap between them, and stay
## within reach of the road. A tower's reach is measured from the block's centre.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const COLS := 22
const ROWS := 16

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 80:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _blocks(map_seed: int) -> GameMap:
	return MapGen.generate(map_seed, COLS, ROWS, false, 2)


func _cells_of(map: GameMap, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in map.footprint:
		for dx in map.footprint:
			cells.append(anchor + Vector2i(dx, dy))
	return cells


func test_the_content_names_the_footprints() -> void:
	assert_eq(RULES.SOCKET_FOOTPRINT_LEGACY, 1)
	assert_eq(RULES.SOCKET_FOOTPRINT, 2)
	assert_eq(RULES.SOCKET_BLOCK_GAP, 1)


func test_a_map_knows_its_footprint() -> void:
	assert_eq(_blocks(1).footprint, 2)
	assert_eq(MapGen.generate(1, 9, 13, true, 1).footprint, 1)
	assert_eq(MapGen.generate(1).footprint, RULES.GAME_SOCKET_FOOTPRINT)


func test_every_landscape_map_has_12_to_22_blocks() -> void:
	for map_seed in _seeds:
		assert_between(_blocks(map_seed).sockets.size(), 12, 22, "seed %d" % map_seed)


func test_every_block_is_whole_on_the_board_and_off_the_road() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		for anchor in map.sockets:
			for cell in _cells_of(map, anchor):
				assert_true(cell.x >= 0 and cell.x < COLS, "col, seed %d" % map_seed)
				assert_true(cell.y >= 0 and cell.y < ROWS, "row, seed %d" % map_seed)
				assert_ne(
					map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "on the road, seed %d" % map_seed
				)


func test_blocks_never_overlap_and_leave_a_cell_of_gap() -> void:
	for map_seed in _seeds:
		var sockets := _blocks(map_seed).sockets
		for i in sockets.size():
			for j in range(i + 1, sockets.size()):
				var apart := sockets[i] - sockets[j]
				# anchors at least footprint + gap apart on one axis
				assert_gte(
					maxi(absi(apart.x), absi(apart.y)),
					3,
					"seed %d: %s and %s" % [map_seed, sockets[i], sockets[j]]
				)


func test_every_block_has_a_cell_within_reach_of_the_road() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		for anchor in map.sockets:
			var best := 1000
			for cell in _cells_of(map, anchor):
				for road_cell in map.path:
					best = mini(best, maxi(absi(road_cell.x - cell.x), absi(road_cell.y - cell.y)))
			assert_lte(best, RULES.SOCKET_REACH, "seed %d at %s" % [map_seed, anchor])


func test_the_heartstone_has_a_footprint_that_holds_the_end_of_the_road() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		var last := map.path[map.path.size() - 1]
		assert_eq(map.heartstone.size, Vector2i(2, 2))
		assert_true(map.heartstone.has_point(last), "holds the road's end, seed %d" % map_seed)
		assert_true(map.heartstone.position.x >= 0 and map.heartstone.end.x <= COLS)
		assert_true(map.heartstone.position.y >= 0 and map.heartstone.end.y <= ROWS)


func test_no_block_overlaps_the_heartstone() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		for anchor in map.sockets:
			for cell in _cells_of(map, anchor):
				assert_false(
					map.heartstone.has_point(cell), "overlaps the Heartstone, seed %d" % map_seed
				)


func test_on_the_legacy_board_the_heartstone_is_just_the_end_cell() -> void:
	var map := MapGen.generate(1, 9, 13, true, 1)
	assert_eq(map.heartstone.size, Vector2i(1, 1))
	assert_eq(map.heartstone.position, map.path[map.path.size() - 1])


func test_only_the_anchor_is_a_socket_but_every_cell_of_the_block_finds_it() -> void:
	var map := _blocks(1)
	for anchor in map.sockets:
		assert_true(map.is_socket(anchor))
		for cell in _cells_of(map, anchor):
			assert_eq(map.socket_anchor_at(cell), anchor)
			if cell != anchor:
				assert_false(map.is_socket(cell), "%s is in the block of %s" % [cell, anchor])
	assert_eq(map.socket_anchor_at(map.path[0]), GameMap.NO_SOCKET)
	assert_eq(map.socket_anchor_at(Vector2i(-1, 3)), GameMap.NO_SOCKET)
	assert_eq(map.socket_anchor_at(Vector2i(COLS, 3)), GameMap.NO_SOCKET)


func test_a_block_has_one_elevation_over_all_four_cells() -> void:
	var counts := [0, 0, 0]
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		for anchor in map.sockets:
			var level := map.elevation_at(anchor)
			counts[level] += 1
			for cell in _cells_of(map, anchor):
				assert_eq(map.elevation_at(cell), level, "seed %d at %s" % [map_seed, cell])
	assert_gt(counts[1], 0)
	assert_gt(counts[2], 0)
	assert_gt(counts[0], counts[1])


func test_ground_and_road_stay_level_0() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		for row in ROWS:
			for col in COLS:
				var cell := Vector2i(col, row)
				if map.socket_anchor_at(cell) == GameMap.NO_SOCKET:
					assert_eq(map.elevation_at(cell), 0)


func test_the_centre_of_a_block_is_one_cell_in_and_of_a_single_cell_socket_half_a_cell() -> void:
	var map := _blocks(1)
	var anchor := map.sockets[0]
	assert_eq(map.socket_centre(anchor), Vector2(float(anchor.x) + 1.0, float(anchor.y) + 1.0))
	var legacy := MapGen.generate(1, 9, 13, true, 1)
	var cell := legacy.sockets[0]
	assert_eq(legacy.socket_centre(cell), Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5))


func test_the_same_seed_gives_the_same_blocks() -> void:
	assert_eq(_blocks(4242).sockets, _blocks(4242).sockets)
	assert_eq(_blocks(4242).elevation, _blocks(4242).elevation)
	assert_eq(_blocks(4242).heartstone, _blocks(4242).heartstone)
	var layouts := {}
	for map_seed in range(1, 40):
		layouts[_blocks(map_seed).sockets] = true
	assert_gt(layouts.size(), 30)


func test_blocks_do_not_change_the_road() -> void:
	for map_seed in [1, 7920, 15839]:
		var plain := MapGen.generate(map_seed, COLS, ROWS, false, 1)
		var blocks := _blocks(map_seed)
		assert_eq(blocks.path, plain.path)
		assert_eq(blocks.tiles, plain.tiles)


func test_a_board_that_comes_up_short_of_blocks_is_drawn_again() -> void:
	# these seeds left only 11 blocks on the first road when a detour was asked for;
	# the generator now tries another road, so the count holds
	for map_seed in [2501, 2996]:
		var map := MapGen.generate(map_seed, COLS, ROWS, true, 2)
		assert_not_null(map, "seed %d" % map_seed)
		assert_between(map.sockets.size(), 12, 22, "seed %d" % map_seed)
		assert_between(map.routes.size(), 1, 2)


func test_a_detour_and_blocks_hold_12_to_22_blocks_over_a_run_of_seeds() -> void:
	for map_seed in range(2480, 3020):
		var map := MapGen.generate(map_seed, COLS, ROWS, true, 2)
		assert_not_null(map, "seed %d" % map_seed)
		assert_between(map.sockets.size(), 12, 22, "seed %d" % map_seed)


func test_a_smaller_board_with_blocks_still_gets_its_blocks_by_trying_again() -> void:
	for map_seed in [308842, 696873, 744387]:
		var map := MapGen.generate(map_seed, 20, 14, false, 2)
		assert_not_null(map, "seed %d" % map_seed)
		assert_gte(map.sockets.size(), 12, "seed %d" % map_seed)
