## Sockets sit next to the road: close to it, and with a stretch of road in reach
## of even a level 1 tower.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const COLS := 22
const ROWS := 16
## A block touches the road when its centre is at most this far from a road cell's
## centre: the nearest that a corner-centred 2x2 block allows is 1.58 cells, the next
## is 2.12 (a diagonal), so 1.6 means beside the road.
const BESIDE := 1.6

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 80:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _blocks(map_seed: int) -> GameMap:
	return MapGen.generate(map_seed, COLS, ROWS, false, 2)


## Every road cell of the map (all routes), as the cell's centre.
func _road_centres(map: GameMap) -> Array[Vector2]:
	var centres: Array[Vector2] = []
	for row in map.rows:
		for col in map.cols:
			if map.tiles[row][col] == GameMap.Tile.ROAD:
				centres.append(Vector2(float(col) + 0.5, float(row) + 0.5))
	return centres


func test_every_blocks_centre_is_close_to_the_road() -> void:
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		var road := _road_centres(map)
		for anchor in map.sockets:
			var centre := map.socket_centre(anchor)
			var nearest := 1000.0
			for road_centre in road:
				nearest = minf(nearest, centre.distance_to(road_centre))
			assert_lte(
				nearest,
				BESIDE + 1e-9,
				"seed %d at %s is %f from the road" % [map_seed, anchor, nearest]
			)


func test_every_socket_gives_a_level_1_spool_guard_some_road_to_shoot_at() -> void:
	var base: float = preload("res://content/towers.gd").DEFS.spoolGuard.range[0]
	for map_seed in _seeds:
		var map := _blocks(map_seed)
		var road := _road_centres(map)
		for anchor in map.sockets:
			var centre := map.socket_centre(anchor)
			var reach := base
			var covered := 0
			for road_centre in road:
				if centre.distance_to(road_centre) <= reach:
					covered += 1
			assert_gte(
				covered, 3, "seed %d at %s covers %d road cells" % [map_seed, anchor, covered]
			)


func test_a_detour_does_not_let_a_block_drift_from_the_road_either() -> void:
	for map_seed in range(1, 60):
		var map := MapGen.generate(map_seed, COLS, ROWS, true, 2)
		var road := _road_centres(map)
		for anchor in map.sockets:
			var centre := map.socket_centre(anchor)
			var nearest := 1000.0
			for road_centre in road:
				nearest = minf(nearest, centre.distance_to(road_centre))
			assert_lte(nearest, BESIDE + 1e-9, "seed %d" % map_seed)
