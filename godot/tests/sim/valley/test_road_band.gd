## The road as a band (#430): the cells under it are road, a block never comes near it and a level
## 1 tower on every block still covers cells of the centre line. The layout valley's band is the
## drawn width (0.9, #469); the wider band (2.4) waits for #446, so those tests turn it on by hand.
extends GutTest

const ROAD := preload("res://content/valley/road_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEEDS: Array[int] = [1, 2, 3]

var _maps := {}


func _layout_valley(seed: int) -> GameMap:
	if not _maps.has(seed):
		var layout := ValleyLayout.generate(seed, 40, 24)
		_maps[seed] = ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
	return _maps[seed]


## A straight road along row 5 of a 20 by 12 strip, with a band of `width` cells.
func _straight(width: float) -> SectionResult:
	var slot := ValleyPlan.Slot.new()
	slot.rect = Rect2i(0, 0, 20, 12)
	var result := SectionResult.create(slot)
	result.road_width = width
	for x in 20:
		result.road.append(Vector2i(x, 5))
	return result


func test_the_layout_valleys_band_is_the_drawn_width() -> void:
	assert_eq(GameMap.new().road_width, ROAD.OLD_WIDTH_CELLS)
	assert_eq(ROAD.ROAD_WIDTH_CELLS, ROAD.OLD_WIDTH_CELLS)
	assert_eq(ValleyLayout.generate(1, 40, 24).road_width, ROAD.OLD_WIDTH_CELLS)
	assert_eq(_layout_valley(1).road_width, ROAD.OLD_WIDTH_CELLS)


func test_every_cell_the_drawn_bed_touches_is_road() -> void:
	# a curve running diagonally across a staircase of cells touches cells whose centres lie
	# further off than half the width; the bed would poke out of them (#469)
	var half := ROAD.OLD_WIDTH_CELLS / 2.0
	for seed in SEEDS:
		var map := _layout_valley(seed)
		var touched := 0
		for curve: RoadCurve in map.route_curves:
			for y in map.rows:
				for x in map.cols:
					if curve.rect_gap(x, y, 1) < half - 1e-6:
						touched += 1
						assert_eq(
							map.tiles[y][x], GameMap.Tile.ROAD, "cell %d,%d, seed %d" % [x, y, seed]
						)
		assert_gt(touched, map.path.size(), "the bed touches more than the centre line")


func test_the_distance_to_a_square_is_zero_where_the_curve_crosses_it() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2)]
	var curve := RoadCurve.from_cells(cells)
	assert_almost_eq(curve.rect_gap(1, 0, 1), 0.0, 1e-9, "the diagonal clips the corner")
	assert_almost_eq(curve.rect_gap(4, 2, 1), 1.5, 1e-9)


func test_the_band_reach_is_wider_than_the_one_cell_roads_and_only_for_the_band() -> void:
	assert_eq(ROAD.BAND_COVERAGE_REACH, 2.7)
	assert_eq(RULES.SOCKET_COVERAGE_REACH, 2.3, "the strip valley and old boards keep theirs")
	# three road cells 2.55 cells from the block's centre: in the band's reach, out of the other
	var road: Array[Vector2i] = [Vector2i(8, 5), Vector2i(9, 5), Vector2i(6, 7)]
	var block := Rect2i(8, 7, 2, 2)
	var band := _straight(ROAD.OLD_WIDTH_CELLS)
	band.road = road
	assert_true(SectionSockets.reaches(band, block))
	var plain := _straight(0.0)
	plain.road = road
	assert_false(SectionSockets.reaches(plain, block))


func test_a_cell_is_road_when_any_part_of_it_is_within_half_the_band_of_a_curve() -> void:
	for seed in SEEDS:
		var map := _layout_valley(seed)
		map.road_width = 2.4
		map.tiles = MapGen._tiles_for(map.routes, map.cols, map.rows)
		ValleyStitcher._mark_band(map)
		var half := map.road_width / 2.0
		var near := 0
		for y in map.rows:
			for x in map.cols:
				var gap := 1.0e30
				for curve: RoadCurve in map.route_curves:
					gap = minf(gap, curve.rect_gap(x, y, 1))
				var road := map.tiles[y][x] == GameMap.Tile.ROAD
				if gap <= half - 1e-6:
					assert_true(road, "cell %d,%d is under the band, seed %d" % [x, y, seed])
					near += 1
				elif gap > half + 1e-6 and not _on_a_route(map, Vector2i(x, y)):
					assert_false(road, "cell %d,%d is off the band, seed %d" % [x, y, seed])
		assert_gt(near, map.path.size(), "the band covers more than the centre line")


func _on_a_route(map: GameMap, cell: Vector2i) -> bool:
	for route: Array in map.routes:
		if route.has(cell):
			return true
	return false


func test_the_centre_line_cells_and_the_hero_walk_stay_as_they_were() -> void:
	var map := _layout_valley(2)
	for cell in map.path:
		assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD)
		assert_true(map.is_walkable(cell), "the hero walks the road at %s" % cell)


func test_no_candidate_block_touches_the_band_and_each_one_still_covers_the_road() -> void:
	var result := _straight(1.0)
	var least := SectionSockets.least_gap(result)
	var found := SectionSockets.candidates(result, [] as Array[Rect2i])
	assert_gt(found.size(), 0)
	for anchor in found:
		var block := Rect2i(anchor, Vector2i(2, 2))
		assert_gte(
			RoadCurve.from_cells(result.road).distance_to(
				float(anchor.x) + 1.0, float(anchor.y) + 1.0
			),
			least - 1e-6
		)
		assert_true(
			SectionSockets.covers(block, result.road, 0.0, ROAD.BAND_COVERAGE_REACH),
			"block %s" % anchor
		)


func test_every_block_has_cells_of_the_centre_line_within_the_band_reach() -> void:
	# a level 1 Spool Guard reaches 2.3, a little under the band's reach (owner, 2026-10-24, #469);
	# the road the tower shoots at is the band, which lies nearer than its centre line
	var reach: float = ROAD.BAND_COVERAGE_REACH
	assert_gte(reach, TOWERS.DEFS["spoolGuard"].range[0])
	for seed in SEEDS:
		var map := _layout_valley(seed)
		for anchor in map.sockets:
			var cells := 0
			for cell in map.path:
				if SectionSockets.centre_gap(anchor, cell) <= reach:
					cells += 1
			assert_gte(cells, RULES.SOCKET_MIN_ROAD_COVERAGE, "block %s, seed %d" % [anchor, seed])


func test_a_wide_band_does_not_loosen_the_coverage_rule() -> void:
	# a block whose centre is 2.5 cells off the road is clear of a 2.4 band but a level 1 tower
	# there covers none of the road, so it is not placed
	var far := Rect2i(8, 7, 2, 2)
	for width in [1.0, 2.4]:
		var result := _straight(width)
		assert_true(SectionSockets.off_band(result, far))
		assert_false(SectionSockets.reaches(result, far), "width %s" % width)
	assert_true(SectionSockets.reaches(_straight(1.0), Rect2i(8, 6, 2, 2)))


func test_distance_to_a_curve_is_the_gap_to_its_nearest_segment() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var curve := RoadCurve.from_cells(cells)
	assert_almost_eq(curve.distance_to(1.5, 2.5), 2.0, 1e-9)
	assert_almost_eq(curve.distance_to(4.5, 0.5), 2.0, 1e-9)
	assert_almost_eq(curve.distance_to(1.0, 0.5), 0.0, 1e-9)


func test_the_strip_valley_keeps_its_one_cell_road() -> void:
	var map := ValleyStitcher.build(1, 32, 20)
	assert_not_null(map)
	assert_eq(map.road_width, ROAD.OLD_WIDTH_CELLS)
	var plain := MapGen._tiles_for(map.routes, 32, 20)
	for y in 20:
		assert_eq(map.tiles[y], plain[y], "row %d" % y)
