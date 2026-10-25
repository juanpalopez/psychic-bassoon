## The road as a band (#430): the cells under it are road, a block never comes near it and a level
## 1 tower on every block still covers cells of the centre line. The layout valley's band is 2.0
## cells (owner, 2026-10-25, #446); the tests that turn on a wider band (2.4) set it by hand.
extends GutTest

const ROAD := preload("res://content/valley/road_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEEDS: Array[int] = [1, 2, 3]
## The fewest centre-line cells within a level 1 Spool Guard's range of any block, seeds 1..300.
const MIN_CELLS_IN_OWN_RANGE := 1

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


func test_the_layout_valleys_band_is_two_cells_and_towers_reach_to_its_edge() -> void:
	assert_eq(GameMap.new().road_width, ROAD.OLD_WIDTH_CELLS)
	assert_eq(GameMap.new().reach_band, 0.0, "a map built another way has no band to reach")
	assert_eq(ROAD.ROAD_WIDTH_CELLS, 2.0)
	assert_eq(ValleyLayout.generate(1, 40, 24).road_width, ROAD.ROAD_WIDTH_CELLS)
	assert_eq(_layout_valley(1).road_width, ROAD.ROAD_WIDTH_CELLS)
	assert_eq(_layout_valley(1).reach_band, ROAD.ROAD_WIDTH_CELLS, "the drawn width")
	assert_eq(_layout_valley(1).reach_margin(), ROAD.ROAD_WIDTH_CELLS / 2.0)


func test_every_cell_the_drawn_bed_touches_is_road() -> void:
	# a curve running diagonally across a staircase of cells touches cells whose centres lie
	# further off than half the width; the bed would poke out of them (#469)
	var half := ROAD.ROAD_WIDTH_CELLS / 2.0
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
	assert_eq(SectionSockets.coverage_reach(ROAD.OLD_WIDTH_CELLS), 2.3 + 0.45)
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
			SectionSockets.covers(block, result.road, 0.0, SectionSockets.coverage_reach(1.0)),
			"block %s" % anchor
		)


func test_every_block_keeps_centre_line_cells_within_a_level_one_towers_own_range() -> void:
	# Measured over seeds 1..300 on the 40 by 24 layout valley (#469): the fewest centre-line cells
	# within the Spool Guard's range of a block's centre is 1 on the 0.9 band; on the 2.0 band a
	# tower reaches 3.3 (2.3 plus half the band) and the fewest is 3. A further loosening of
	# `coverage_reach` shows up here as a block with too few.
	var range_1: float = TOWERS.DEFS["spoolGuard"].range[0]
	var band_reach := SectionSockets.coverage_reach(ROAD.ROAD_WIDTH_CELLS)
	# a tower on the banded map reaches its range plus half the band (`reach_margin`, #446)
	range_1 += ROAD.ROAD_WIDTH_CELLS / 2.0
	var fewest := 1000
	var fewest_in_band_reach := 1000
	for seed in SEEDS:
		var map := _layout_valley(seed)
		# a block reaches the lane it covers best: the fork's lower lane has blocks of its own (#481)
		var lanes: Array = [map.path]
		for fork in map.forks:
			lanes.append(map.routes[fork.route])
		for anchor in map.sockets:
			var own := 0
			var wide := 0
			for lane: Array in lanes:
				var lane_own := 0
				var lane_wide := 0
				for cell: Vector2i in lane:
					var gap := SectionSockets.centre_gap(anchor, cell)
					lane_own += 1 if gap <= range_1 else 0
					lane_wide += 1 if gap <= band_reach else 0
				own = maxi(own, lane_own)
				wide = maxi(wide, lane_wide)
			fewest = mini(fewest, own)
			fewest_in_band_reach = mini(fewest_in_band_reach, wide)
	assert_gte(fewest, MIN_CELLS_IN_OWN_RANGE, "cells within the Spool Guard's range")
	assert_gte(fewest_in_band_reach, RULES.SOCKET_MIN_ROAD_COVERAGE, "cells within the band reach")


func test_the_coverage_reach_is_the_level_one_range_plus_the_reach_margin() -> void:
	var range_1: float = TOWERS.DEFS["spoolGuard"].range[0]
	for width in [0.9, 1.0, 2.4]:
		var map := GameMap.new()
		map.reach_band = width
		assert_eq(SectionSockets.coverage_reach(width), range_1 + map.reach_margin())
	assert_almost_eq(SectionSockets.coverage_reach(2.4), 3.5, 1e-9, "the owner's band")


func test_a_wider_band_widens_the_reach_and_blocks_are_chosen_by_it() -> void:
	# three centre-line cells 2.92 cells from the block's centre: out of reach on the 0.9 band
	# (2.75), in reach on the owner's 2.4 band (3.5)
	var block := Rect2i(8, 7, 2, 2)
	var road: Array[Vector2i] = [Vector2i(7, 5), Vector2i(10, 5), Vector2i(6, 6)]
	var narrow := _straight(ROAD.OLD_WIDTH_CELLS)
	narrow.road = road
	var wide := _straight(2.4)
	wide.road = road
	assert_false(SectionSockets.reaches(narrow, block))
	assert_true(SectionSockets.reaches(wide, block))
	# on a straight road a wider band keeps blocks further off it, so it reaches further out
	var found := SectionSockets.candidates(_straight(2.4), [] as Array[Rect2i])
	assert_gt(found.size(), 0)
	for anchor in found:
		assert_true(SectionSockets.reaches(_straight(2.4), Rect2i(anchor, Vector2i(2, 2))))


func test_a_wide_band_does_not_loosen_the_coverage_rule() -> void:
	# a block whose centre is 2.5 cells off the road has two centre-line cells in a 1.0 band's
	# reach (2.8), too few to be placed; the wider the band, the further out blocks are placed,
	# but a block 4.5 off the road is out of reach even of a 2.4 band (3.5)
	var far := Rect2i(8, 7, 2, 2)
	assert_false(SectionSockets.reaches(_straight(1.0), far))
	assert_true(SectionSockets.off_band(_straight(1.0), far))
	var wide := _straight(2.4)
	var beyond := Rect2i(8, 9, 2, 2)
	assert_true(SectionSockets.off_band(wide, beyond))
	assert_false(SectionSockets.reaches(wide, beyond), "4.5 off the road, reach 3.5")
	assert_true(SectionSockets.reaches(wide, far), "2.5 off the road is in reach 3.5")
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
	assert_eq(map.reach_band, 0.0)
	var plain := MapGen._tiles_for(map.routes, 32, 20)
	for y in 20:
		assert_eq(map.tiles[y], plain[y], "row %d" % y)
