## The game board is the sectioned valley (#389, `docs/lessons/2026-10-20-sectioned-valley.md`):
## these tests read `Game.create_on_strip_valley(seed).map` and pin what the strip valley (the game
## board until #458) promises, where the route-first generator's tests (`test_terrain.gd`,
## `test_valley_map.gd`) pin the older generator.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
## The six sections hold 21 to 30 blocks between them (their own ranges add up to it).
const SOCKETS_LEAST := 21
const SOCKETS_MOST := 30
const FIRST_SEED := 1
const SEED_COUNT := 40

var _maps: Array[GameMap] = []


func before_all() -> void:
	for map_seed in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		_maps.append(Game.create_on_strip_valley(map_seed).map)
	_maps.append(Game.create_on_strip_valley(4294967295).map)


func _crossing(map: GameMap) -> Rect2i:
	return (
		ValleyPlan.create(map.seed, map.cols, map.rows).slots[ValleyPlan.Id.BLUEWATER_CROSSING].rect
	)


func _on_road(map: GameMap, cell: Vector2i) -> bool:
	return map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD


func test_the_board_is_the_valley_with_a_main_road_and_a_feeder() -> void:
	for map in _maps:
		assert_eq([map.cols, map.rows], [RULES.GRID_COLS, RULES.GRID_ROWS])
		assert_eq(map.footprint, RULES.GAME_SOCKET_FOOTPRINT)
		assert_eq(map.path[0].x, 0, "enters on the left edge, seed %d" % map.seed)
		assert_eq(map.path[map.path.size() - 1].x, map.cols - 1, "seed %d" % map.seed)
		assert_eq(map.routes.size(), 2, "the later-wave feeder, seed %d" % map.seed)
		var main: Array = map.routes[0]
		var feeder: Array = map.routes[1]
		assert_eq(feeder.slice(map.feeder_length), main.slice(map.join_index), "joins the road")
		assert_eq(feeder[feeder.size() - 1], main[main.size() - 1], "to the Heartstone")


func test_the_socket_count_and_blocks_stay_in_the_valley_ranges() -> void:
	var total := 0
	for map in _maps:
		total += map.sockets.size()
		assert_between(map.sockets.size(), SOCKETS_LEAST, SOCKETS_MOST)
		for anchor in map.sockets:
			for dy in map.footprint:
				for dx in map.footprint:
					var cell := anchor + Vector2i(dx, dy)
					assert_true(map.in_bounds(cell), "inside, seed %d" % map.seed)
					assert_false(_on_road(map, cell), "off the road, seed %d" % map.seed)
					assert_false(map.heartstone.has_point(cell), "seed %d" % map.seed)
					assert_false(map.river.has(cell), "off the river, seed %d" % map.seed)
					assert_eq(map.height_at(cell), map.elevation_at(anchor), "own level")
	assert_gt(float(total) / float(_maps.size()), 22.0, "about 25 blocks on average")


func test_the_road_winds_through_all_six_sections() -> void:
	# the road crosses the whole board, bending inside every strip: well over twice the
	# columns, and it ends on the right edge
	var length := 0
	for map in _maps:
		length += map.path.size()
		assert_gt(map.path.size(), map.cols * 3, "seed %d" % map.seed)
	assert_between(float(length) / float(_maps.size()), 120.0, 180.0, "mean road length")


func test_every_cell_has_a_height_and_a_region_and_the_road_and_river_lie_on_the_floor() -> void:
	for map in _maps:
		for y in map.rows:
			for x in map.cols:
				var cell := Vector2i(x, y)
				assert_between(map.height_at(cell), 0, RULES.TERRAIN_LEVELS - 1)
				assert_between(map.region_at(cell), 0, GameMap.Region.size() - 1)
				if _on_road(map, cell) or map.river.has(cell):
					assert_eq(map.height_at(cell), 0, "floor %s, seed %d" % [cell, map.seed])
					if map.river.has(cell):
						assert_eq(map.region_at(cell), GameMap.Region.MEADOW, "seed %d" % map.seed)


func test_the_valley_has_hills_and_every_region() -> void:
	var high := 0
	var total := 0
	var seen := {}
	for map in _maps:
		for y in map.rows:
			for x in map.cols:
				total += 1
				seen[map.region_at(Vector2i(x, y))] = true
				if map.height_at(Vector2i(x, y)) >= 1:
					high += 1
	assert_gt(float(high) / float(total), 0.1, "not a flat board")
	for region in GameMap.Region.values():
		assert_true(seen.has(region), "region %d appears" % region)


func test_the_river_runs_top_to_bottom_only_inside_the_crossing() -> void:
	for map in _maps:
		var strip := _crossing(map)
		assert_false(map.river.is_empty(), "every valley has its river, seed %d" % map.seed)
		assert_eq(map.river[0].y, 0, "top edge, seed %d" % map.seed)
		assert_eq(map.river[map.river.size() - 1].y, map.rows - 1, "bottom, seed %d" % map.seed)
		for i in map.river.size():
			assert_true(strip.has_point(map.river[i]), "inside C, seed %d" % map.seed)
			if i > 0:
				var step := map.river[i] - map.river[i - 1]
				assert_eq(absi(step.x) + absi(step.y), 1, "4-connected, seed %d" % map.seed)
				assert_gte(step.y, 0, "never flows back up, seed %d" % map.seed)


func test_one_road_bridge_and_the_hero_bridge_cross_the_river() -> void:
	for map in _maps:
		var where := "seed %d" % map.seed
		assert_eq(map.bridges.size(), 1, "one road bridge, " + where)
		assert_eq(map.hero_bridges.size(), 1, "one hero bridge, " + where)
		var bridge := map.bridges[0]
		assert_true(map.river.has(bridge.cell) and _on_road(map, bridge.cell), where)
		assert_true(bridge.horizontal, where)
		assert_between(bridge.path_index, 1, map.path.size() - 2, where)
		assert_eq(map.path[bridge.path_index], bridge.cell, "path_index, " + where)
		var hero := map.hero_bridges[0]
		assert_true(map.river.has(hero), where)
		assert_false(_on_road(map, hero), "the hero bridge is off the road, " + where)
		assert_true(map.is_walkable(hero), where)
		for cell in map.river:
			if _on_road(map, cell):
				assert_eq(cell, bridge.cell, "an unbridged crossing, " + where)
			elif cell != hero:
				assert_false(map.is_walkable(cell), "water is not walkable, " + where)


func test_the_board_is_reproducible_and_the_road_leaves_room_for_the_sockets() -> void:
	var a := Game.create_on_strip_valley(7).map
	var b := Game.create_on_strip_valley(7).map
	assert_eq(a.heights, b.heights)
	assert_eq(a.regions, b.regions)
	assert_eq(a.river, b.river)
	assert_eq(a.routes, b.routes)
	assert_eq(a.sockets, b.sockets)
	assert_eq(a.bridges.size(), b.bridges.size())
	assert_eq(a.bridges[0].cell, b.bridges[0].cell)
	assert_eq(a.hero_bridges, b.hero_bridges)
