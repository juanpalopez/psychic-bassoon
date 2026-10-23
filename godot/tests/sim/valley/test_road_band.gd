## The road as a band (#430): the cells under it are road, a block never comes near it and a level
## 1 tower on every block still covers cells of the centre line. The content has the band off
## (`ROAD_WIDTH_CELLS` 0) until the owner picks how wide the road can be with that coverage, so
## the band tests turn it on by hand.
extends GutTest

const ROAD := preload("res://content/valley/road_rules.gd")
const RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEEDS: Array[int] = [1, 2, 3]

var _maps := {}


func _layout_valley(seed: int) -> GameMap:
	if not _maps.has(seed):
		_maps[seed] = _fresh_valley(seed)
	return _maps[seed]


func _fresh_valley(seed: int) -> GameMap:
	var layout := ValleyLayout.generate(seed, 32, 20)
	return ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout)


## A straight road along row 5 of a 20 by 12 strip, with a band of `width` cells.
func _straight(width: float) -> SectionResult:
	var slot := ValleyPlan.Slot.new()
	slot.rect = Rect2i(0, 0, 20, 12)
	var result := SectionResult.create(slot)
	result.road_width = width
	for x in 20:
		result.road.append(Vector2i(x, 5))
	return result


func test_the_layout_valleys_band_is_the_drawn_width_from_the_content() -> void:
	assert_eq(ROAD.ROAD_WIDTH_CELLS, ROAD.OLD_WIDTH_CELLS)
	assert_eq(ROAD.OLD_WIDTH_CELLS, 0.9)
	assert_eq(GameMap.new().road_width, ROAD.OLD_WIDTH_CELLS)
	for seed in SEEDS:
		assert_eq(ValleyLayout.generate(seed, 32, 20).road_width, ROAD.ROAD_WIDTH_CELLS)
		assert_eq(_layout_valley(seed).road_width, ROAD.ROAD_WIDTH_CELLS)


func test_a_cell_is_road_when_the_band_reaches_any_part_of_it() -> void:
	for width in [ROAD.ROAD_WIDTH_CELLS, 2.4]:
		for seed in SEEDS:
			var map := _fresh_valley(seed)
			map.road_width = width
			map.tiles = MapGen._tiles_for(map.routes, map.cols, map.rows)
			ValleyStitcher._mark_band(map)
			var half := map.road_width / 2.0
			var near := 0
			for y in map.rows:
				for x in map.cols:
					var gap := _gap_to_cell(map, x, y)
					var road := map.tiles[y][x] == GameMap.Tile.ROAD
					var label := "cell %d,%d, width %s, seed %d" % [x, y, width, seed]
					if gap <= half - 1e-3:
						assert_true(road, "%s is under the band" % label)
						near += 1
					elif gap > half + 1e-3 and not _on_a_route(map, Vector2i(x, y)):
						assert_false(road, "%s is off the band" % label)
			assert_gt(near, map.path.size(), "the band covers more than the centre line")


## The least distance from the curves to any point of the cell, by walking the curves finely.
func _gap_to_cell(map: GameMap, x: int, y: int) -> float:
	var rect := Rect2(Vector2(x, y), Vector2.ONE)
	var best := 1.0e30
	for curve: RoadCurve in map.route_curves:
		for index in curve.xs.size() - 1:
			var a := Vector2(curve.xs[index], curve.ys[index])
			var b := Vector2(curve.xs[index + 1], curve.ys[index + 1])
			for step in 21:
				var at := a.lerp(b, float(step) / 20.0)
				best = minf(best, at.distance_to(at.clamp(rect.position, rect.end)))
	return best


func test_the_gap_from_a_segment_to_a_cell_is_zero_when_it_crosses_the_cell() -> void:
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var curve := RoadCurve.from_cells(cells)
	# the curve runs along y 0.5 from x 0.5 to 2.5
	assert_almost_eq(curve.segment_rect_gap(0, 0, 0, 1), 0.0, 1e-9)
	assert_almost_eq(curve.segment_rect_gap(0, 1, 0, 1), 0.0, 1e-9)
	assert_almost_eq(curve.segment_rect_gap(0, 1, 1, 1), 0.5, 1e-9)
	assert_almost_eq(curve.segment_rect_gap(0, 3, 0, 1), 1.5, 1e-9)
	assert_almost_eq(curve.segment_rect_gap(0, 3, 1, 1), sqrt(2.5), 1e-9)
	# a segment that passes through a cell without an end inside it
	var long := RoadCurve.new()
	long.xs = PackedFloat64Array([-1.0, 3.0])
	long.ys = PackedFloat64Array([1.5, 1.5])
	assert_almost_eq(long.segment_rect_gap(0, 1, 1, 1), 0.0, 1e-9)
	assert_almost_eq(long.segment_rect_gap(0, 1, 3, 1), 1.5, 1e-9)


func test_no_socket_cell_is_road_or_near_the_band_and_the_route_cells_are_road() -> void:
	for seed in SEEDS:
		var map := _layout_valley(seed)
		var half := map.road_width / 2.0
		for anchor in map.sockets:
			for dy in map.footprint:
				for dx in map.footprint:
					var cell := anchor + Vector2i(dx, dy)
					assert_ne(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "socket %s" % anchor)
					assert_gte(_gap_to_cell(map, cell.x, cell.y), half - 1e-3, "socket %s" % anchor)
		for route: Array in map.routes:
			for index in route.size():
				assert_eq(map.tiles[route[index].y][route[index].x], GameMap.Tile.ROAD)
				if index > 0:
					assert_eq(
						absi(route[index].x - route[index - 1].x)
						+ absi(route[index].y - route[index - 1].y),
						1,
						"route cells %s and %s touch" % [route[index - 1], route[index]]
					)


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
		assert_true(SectionSockets.covers(block, result.road, 0.0), "block %s" % anchor)


func test_every_block_gives_a_level_one_tower_cells_of_the_centre_line_to_shoot_at() -> void:
	var reach: float = TOWERS.DEFS["spoolGuard"].range[0]
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


func test_a_block_beside_a_diagonal_road_is_judged_by_its_square_not_its_centre() -> void:
	# a diagonal road: the block's corner cell reaches the band though the centre keeps 1.3 away
	var cells: Array[Vector2i] = []
	for step in 12:
		cells.append(Vector2i(step, step))
	var result := SectionResult.create(ValleyPlan.Slot.new())
	result.road_width = 0.9
	result.road = cells
	var curve := RoadCurve.from_cells(cells)
	assert_almost_eq(curve.rect_gap(5, 3, 2), curve.segment_rect_gap(4, 5, 3, 2), 1e-9)
	var near := Rect2i(5, 3, 2, 2)
	var far := Rect2i(7, 3, 2, 2)
	assert_gt(curve.distance_to(6.0, 4.0), SectionSockets.least_gap(result) - 0.2)
	assert_false(SectionSockets.off_band(result, near))
	assert_true(SectionSockets.off_band(result, far))
