## The valley's terrain layer (#322): terrace heights, regions (meadow, forest, rocks, dirt) and
## a river the road crosses on bridges, drawn from its own stream after the road and the
## sockets, so neither of them moves. The sim keeps it as plain data; the render builds the
## diorama from it.
extends GutTest

const RULES := preload("res://content/map_rules.gd")

var _seeds: Array[int] = []
var _maps: Array[GameMap] = []


func before_all() -> void:
	for i in 120:
		_seeds.append(i * 104729 + 3)
	_seeds.append_array([0, 1, 42, 4294967295])
	for map_seed in _seeds:
		_maps.append(Game.create(map_seed).map)


func _cells(map: GameMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.rows:
		for x in map.cols:
			out.append(Vector2i(x, y))
	return out


func _on_road(map: GameMap, cell: Vector2i) -> bool:
	return map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD


func test_every_cell_has_a_height_and_a_region() -> void:
	for map in _maps:
		assert_eq(map.heights.size(), map.rows)
		assert_eq(map.regions.size(), map.rows)
		for y in map.rows:
			assert_eq(map.heights[y].size(), map.cols)
			assert_eq(map.regions[y].size(), map.cols)
			for x in map.cols:
				assert_between(map.heights[y][x], 0, RULES.TERRAIN_LEVELS - 1)
				assert_between(map.regions[y][x], 0, GameMap.Region.size() - 1)


func test_the_road_lies_on_the_valley_floor_and_its_banks_stay_low() -> void:
	for map in _maps:
		for cell in _cells(map):
			if _on_road(map, cell):
				assert_eq(map.height_at(cell), 0, "road at %s, seed %d" % [cell, map.seed])
		for route in map.routes:
			for cell: Vector2i in route:
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var next: Vector2i = cell + Vector2i(dx, dy)
						if map.in_bounds(next) and not map.is_socket_cell(next):
							assert_lte(
								map.height_at(next),
								RULES.TERRAIN_ROADSIDE_MAX,
								"bank %s, seed %d" % [next, map.seed]
							)


func test_a_socket_block_stands_on_its_own_level() -> void:
	for map in _maps:
		for anchor in map.sockets:
			for dy in map.footprint:
				for dx in map.footprint:
					var cell := anchor + Vector2i(dx, dy)
					assert_eq(map.height_at(cell), map.elevation_at(anchor), "seed %d" % map.seed)


func test_neighbouring_cells_step_at_most_one_terrace_except_at_cliffs() -> void:
	# cliffs are allowed (the canyon walls), but no cell is a pit or a spike: each has a
	# neighbour no more than one terrace away
	for map in _maps:
		for cell in _cells(map):
			var near := false
			for step: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				var next := cell + step
				if map.in_bounds(next) and absi(map.height_at(next) - map.height_at(cell)) <= 1:
					near = true
			assert_true(near, "lone cell %s, seed %d" % [cell, map.seed])


func test_the_terrain_has_hills_not_a_flat_board() -> void:
	var high := 0
	var total := 0
	for map in _maps:
		for cell in _cells(map):
			total += 1
			if map.height_at(cell) >= 2:
				high += 1
	var share := float(high) / float(total)
	assert_between(share, 0.15, 0.5, "share of cells on terrace 2 or higher: %.2f" % share)


func test_regions_put_forest_away_from_the_road_and_every_region_appears() -> void:
	var seen := {}
	for map in _maps:
		for cell in _cells(map):
			var region := map.region_at(cell)
			seen[region] = true
			if region == GameMap.Region.FOREST:
				assert_gte(_road_gap(map, cell), RULES.FOREST_ROAD_GAP, "seed %d" % map.seed)
			if _on_road(map, cell) or map.is_socket_cell(cell) or map.river.has(cell):
				assert_eq(region, GameMap.Region.MEADOW, "kept clear, seed %d" % map.seed)
	for region in GameMap.Region.values():
		assert_true(seen.has(region), "region %d appears" % region)


func _road_gap(map: GameMap, cell: Vector2i) -> int:
	var best := 1000
	for route in map.routes:
		for road: Vector2i in route:
			best = mini(best, maxi(absi(road.x - cell.x), absi(road.y - cell.y)))
	return best


func test_the_river_runs_from_the_top_edge_to_the_bottom_edge() -> void:
	var with_river := 0
	for map in _maps:
		if map.river.is_empty():
			continue
		with_river += 1
		assert_eq(map.river[0].y, 0, "starts on the top edge, seed %d" % map.seed)
		assert_eq(map.river[map.river.size() - 1].y, map.rows - 1, "seed %d" % map.seed)
		for i in range(1, map.river.size()):
			var step := map.river[i] - map.river[i - 1]
			assert_eq(absi(step.x) + absi(step.y), 1, "4-connected, seed %d" % map.seed)
			assert_gte(step.y, 0, "never flows back up, seed %d" % map.seed)
	var share := float(with_river) / float(_maps.size())
	assert_gte(share, 0.9, "share of maps with a river: %.2f" % share)


func test_the_river_keeps_off_the_sockets_the_heartstone_and_the_spawns() -> void:
	for map in _maps:
		for cell in map.river:
			assert_false(map.is_socket_cell(cell), "socket, seed %d" % map.seed)
			assert_false(map.heartstone.has_point(cell), "heartstone, seed %d" % map.seed)
			for route in map.routes:
				var start: Vector2i = route[0]
				assert_gte(
					absi(cell.x - start.x) + absi(cell.y - start.y),
					RULES.RIVER_SPAWN_GAP,
					"spawn, seed %d" % map.seed
				)


func test_the_road_crosses_the_river_only_on_bridges_over_straight_road() -> void:
	for map in _maps:
		if map.river.is_empty():
			continue
		assert_eq(map.bridges.size(), 1, "one crossing, one bridge, seed %d" % map.seed)
		var bridged := {}
		for bridge in map.bridges:
			var cell := bridge.cell
			bridged[cell] = true
			assert_true(_on_road(map, cell), "on the road, seed %d" % map.seed)
			assert_true(map.river.has(cell), "on the river, seed %d" % map.seed)
			# the road runs straight across: road on both sides along it, river on both sides
			# across it
			var side := Vector2i(1, 0) if bridge.horizontal else Vector2i(0, 1)
			var cross := Vector2i(side.y, side.x)
			assert_true(_on_road(map, cell + side) and _on_road(map, cell - side), "straight road")
			assert_true(
				map.river.has(cell + cross) and map.river.has(cell - cross), "straight river"
			)
		for cell in map.river:
			if _on_road(map, cell):
				assert_true(bridged.has(cell), "an unbridged crossing, seed %d" % map.seed)


func test_a_bridge_knows_where_it_sits_on_the_main_road() -> void:
	for map in _maps:
		for bridge in map.bridges:
			if bridge.path_index >= 0:
				assert_eq(map.path[bridge.path_index], bridge.cell, "seed %d" % map.seed)


func test_the_terrain_is_reproducible_and_leaves_the_road_and_sockets_alone() -> void:
	var a := Game.create(7).map
	var b := Game.create(7).map
	assert_eq(a.heights, b.heights)
	assert_eq(a.regions, b.regions)
	assert_eq(a.river, b.river)
	assert_eq(a.bridges.size(), b.bridges.size())
	for i in a.bridges.size():
		assert_eq(a.bridges[i].cell, b.bridges[i].cell)
	# building the terrain again on the finished map changes nothing and never touches the
	# road, the tiles, the sockets or their levels
	var routes := a.routes.duplicate(true)
	var tiles := a.tiles.duplicate(true)
	var sockets := a.sockets.duplicate()
	var elevation := a.elevation.duplicate(true)
	var heights := a.heights.duplicate(true)
	TerrainGen.build(a)
	assert_eq(a.routes, routes, "the terrain never moves the road")
	assert_eq(a.tiles, tiles)
	assert_eq(a.sockets, sockets)
	assert_eq(a.elevation, elevation)
	assert_eq(a.heights, heights, "the same seed gives the same terrain")


func test_the_classic_boards_get_no_terrain_layer() -> void:
	# the 16 by 11 and the fixtures' 9 by 13 boards stay flat with no river, as before
	var map := MapGen.generate(1, 16, 11, false, 2, false)
	assert_true(map.river.is_empty())
	assert_true(map.bridges.is_empty())
	for y in map.rows:
		for x in map.cols:
			assert_eq(map.height_at(Vector2i(x, y)), map.elevation_at(Vector2i(x, y)))
