## The layout valley's road is a wide band (#430): the cells under it are road, no socket block
## comes near it, and the strip valley and the old boards keep their one-cell road.
extends GutTest

const ROAD := preload("res://content/valley/road_rules.gd")
const SEEDS: Array[int] = [1, 2, 3]

var _maps := {}


func _layout_valley(seed: int) -> GameMap:
	if not _maps.has(seed):
		var layout := ValleyLayout.generate(seed, 32, 20)
		_maps[seed] = ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout)
	return _maps[seed]


func test_the_band_is_wide_and_the_old_width_is_the_default() -> void:
	assert_gte(ROAD.ROAD_WIDTH_CELLS, 2.0, "several foes abreast")
	assert_eq(GameMap.new().road_width, ROAD.OLD_WIDTH_CELLS)
	assert_eq(_layout_valley(1).road_width, ROAD.ROAD_WIDTH_CELLS)


func test_a_cell_is_road_when_its_centre_is_within_half_the_band_of_a_curve() -> void:
	for seed in SEEDS:
		var map := _layout_valley(seed)
		var half := map.road_width / 2.0
		var near := 0
		for y in map.rows:
			for x in map.cols:
				var gap := 1.0e30
				for curve: RoadCurve in map.route_curves:
					gap = minf(gap, curve.distance_to(float(x) + 0.5, float(y) + 0.5))
				var road := map.tiles[y][x] == GameMap.Tile.ROAD
				if gap <= half - 1e-6:
					assert_true(road, "cell %d,%d is under the band, seed %d" % [x, y, seed])
					near += 1
				elif gap > half + 1e-6 and not map.path.has(Vector2i(x, y)):
					assert_false(road, "cell %d,%d is off the band, seed %d" % [x, y, seed])
		assert_gt(near, map.path.size(), "the band covers more than the centre line")


func test_the_centre_line_cells_and_the_hero_walk_stay_as_they_were() -> void:
	var map := _layout_valley(2)
	for cell in map.path:
		assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD)
		assert_true(map.is_walkable(cell), "the hero walks the road at %s" % cell)


func test_no_socket_block_touches_the_band() -> void:
	for seed in SEEDS:
		var map := _layout_valley(seed)
		var least := map.road_width / 2.0 + ROAD.ROAD_CLEARANCE_CELLS + 1.0
		for anchor in map.sockets:
			var centre := Vector2(anchor) + Vector2.ONE
			for curve: RoadCurve in map.route_curves:
				assert_gte(curve.distance_to(centre.x, centre.y), least - 1e-6, "block %s" % anchor)
			for dy in 2:
				for dx in 2:
					assert_eq(
						map.tiles[anchor.y + dy][anchor.x + dx],
						GameMap.Tile.PLOT,
						"block %s stands on plot cells" % anchor
					)


func test_the_strip_valley_keeps_its_one_cell_road() -> void:
	var map := ValleyStitcher.build(1, 32, 20)
	assert_not_null(map)
	assert_eq(map.road_width, ROAD.OLD_WIDTH_CELLS)
	var plain := MapGen._tiles_for(map.routes, 32, 20)
	for y in 20:
		assert_eq(map.tiles[y], plain[y], "row %d" % y)


func test_distance_to_a_curve_is_the_gap_to_its_nearest_segment() -> void:
	var curve := RoadCurve.from_cells(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i]
	)
	assert_almost_eq(curve.distance_to(1.5, 2.5), 2.0, 1e-9)
	assert_almost_eq(curve.distance_to(4.5, 0.5), 2.0, 1e-9)
	assert_almost_eq(curve.distance_to(1.0, 0.5), 0.0, 1e-9)
