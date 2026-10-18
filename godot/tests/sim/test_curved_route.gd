## Curved routes (#321): on the valley board the line foes walk rounds the grid path's corners,
## and that curve is the truth for movement, distance, range and hits. The grid path and
## `Route.build` stay as the frozen fixtures pin them (`test_route.gd`).
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const EPSILON := 1e-9
## Sub-points checked on each segment between two route points.
const SUBSTEPS := 4
## The most a route turns from one segment to the next: cos 25 degrees. A grid corner turns
## 90 degrees at once; a curve sampled at `CURVE_POINT_SPACING` turns a few degrees a segment.
const MIN_TURN_COS := 0.9

var _seeds: Array[int] = []


func before_all() -> void:
	for i in 40:
		_seeds.append(i * 7919 + 1)
	_seeds.append_array([0, 42, 4294967295, -7])


func _cells(points: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for point in points:
		cells.append(point)
	return cells


func _valley(map_seed: int) -> GameMap:
	return MapGen.generate(
		map_seed, RULES.GRID_COLS, RULES.GRID_ROWS, false, RULES.GAME_SOCKET_FOOTPRINT, true
	)


## Right along row 0, a corner, then down column 3.
func _one_corner() -> Array[Vector2i]:
	return _cells(
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(3, 0),
			Vector2i(3, 1),
			Vector2i(3, 2),
			Vector2i(3, 3)
		]
	)


## An S-bend whose two corners are one cell apart: right, one cell down, right again.
func _s_bend() -> Array[Vector2i]:
	return _cells(
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(2, 1),
			Vector2i(3, 1),
			Vector2i(4, 1)
		]
	)


## A U-turn: right, one cell down, back left.
func _u_turn() -> Array[Vector2i]:
	return _cells(
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(2, 0),
			Vector2i(2, 1),
			Vector2i(1, 1),
			Vector2i(0, 1)
		]
	)


## A staircase: every cell after the first two is a corner.
func _stairs() -> Array[Vector2i]:
	return _cells(
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
			Vector2i(1, 1),
			Vector2i(2, 1),
			Vector2i(2, 2),
			Vector2i(3, 2),
			Vector2i(3, 3),
			Vector2i(3, 4)
		]
	)


## Checks every property the ticket asks of a curved route over `cells`, with `label` in the
## messages: the curve stays inside the road's cells (or the spawn approach off the board), only
## ever moves on to later cells of the route (no overlap, no doubling back), turns smoothly,
## grows in distance and ends at the last cell's centre.
func _check_curve(route: Route, cells: Array[Vector2i], label: String) -> void:
	var index := {}
	for i in cells.size():
		index[cells[i]] = i
	var last := cells[cells.size() - 1]
	assert_eq(route.xs[route.xs.size() - 1], float(last.x) + RULES.CELL_CENTRE, "end x, " + label)
	assert_eq(route.ys[route.ys.size() - 1], float(last.y) + RULES.CELL_CENTRE, "end y, " + label)
	var grid := Route.build(cells)
	assert_eq(route.xs[0], grid.xs[0], "same spawn x, " + label)
	assert_eq(route.ys[0], grid.ys[0], "same spawn y, " + label)
	var reached := 0
	var bad_cell := 0
	var backwards := 0
	var sharp := 0
	var long := 0
	for p in range(1, route.xs.size()):
		var dx := route.xs[p] - route.xs[p - 1]
		var dy := route.ys[p] - route.ys[p - 1]
		if route.cumulative[p] <= route.cumulative[p - 1]:
			backwards += 1
		if sqrt(dx * dx + dy * dy) > 1.0 + EPSILON:
			long += 1
		if p >= 2:
			var ex := route.xs[p - 1] - route.xs[p - 2]
			var ey := route.ys[p - 1] - route.ys[p - 2]
			var dot := (dx * ex + dy * ey) / sqrt((dx * dx + dy * dy) * (ex * ex + ey * ey))
			if dot < MIN_TURN_COS:
				sharp += 1
		for s in SUBSTEPS + 1:
			var t := float(s) / float(SUBSTEPS)
			var x := route.xs[p - 1] + dx * t
			var y := route.ys[p - 1] + dy * t
			var cell := Vector2i(int(floor(x)), int(floor(y)))
			if not index.has(cell):
				# only the spawn approach, before the first cell, may lie off the road
				if p != 1:
					bad_cell += 1
				continue
			if index[cell] < reached:
				backwards += 1
			reached = maxi(reached, index[cell])
	assert_eq(bad_cell, 0, "every point lies in a road cell of the route, " + label)
	assert_eq(backwards, 0, "the curve never doubles back, " + label)
	assert_eq(sharp, 0, "the curve turns smoothly, " + label)
	assert_eq(long, 0, "no segment is longer than a cell, " + label)
	assert_eq(reached, cells.size() - 1, "it reaches the last cell, " + label)
	assert_almost_eq(route.total, route.cumulative[route.cumulative.size() - 1], 0.0, label)
	for i in cells.size():
		var at := route.position_at(route.cell_distance(i))
		var cell := Vector2i(int(floor(at.x)), int(floor(at.y)))
		assert_eq(cell, cells[i], "cell_distance(%d) is in that cell, %s" % [i, label])
		if i > 0:
			assert_gt(route.cell_distance(i), route.cell_distance(i - 1), label)


func test_a_straight_road_curves_nowhere() -> void:
	var cells := _cells([Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)])
	var curved := Route.build_curved(cells)
	var grid := Route.build(cells)
	assert_eq(curved.xs, grid.xs)
	assert_eq(curved.ys, grid.ys)
	assert_eq(curved.cumulative, grid.cumulative)
	assert_eq(curved.total, grid.total)


func test_a_corner_is_rounded_by_a_curve_through_the_corner_cell() -> void:
	var cells := _one_corner()
	var route := Route.build_curved(cells)
	var grid := Route.build(cells)
	assert_gt(route.xs.size(), grid.xs.size(), "the corner gets curve points")
	assert_lt(route.total, grid.total, "cutting the corner is shorter")
	# the curve's middle (a quadratic Bezier from the cell before the corner to the cell
	# after it, the corner's centre as control) is a quarter cell in from the corner's centre
	var middle := route.position_at(route.cell_distance(3))
	assert_almost_eq(middle.x, 3.5 - 0.25, EPSILON)
	assert_almost_eq(middle.y, 0.5 + 0.25, EPSILON)
	# the cells either side keep their centres on the route
	var before := route.position_at(route.cell_distance(2))
	assert_eq([before.x, before.y], [2.5, 0.5])
	var after := route.position_at(route.cell_distance(4))
	assert_eq([after.x, after.y], [3.5, 1.5])
	_check_curve(route, cells, "one corner")


func test_the_curve_is_sampled_at_the_spacing_in_the_content() -> void:
	var route := Route.build_curved(_one_corner())
	# the corner's two legs are a cell each; a point every `CURVE_POINT_SPACING` of them
	var segments := int(floor(2.0 / RULES.CURVE_POINT_SPACING + 0.5))
	assert_eq(route.xs.size(), Route.build(_one_corner()).xs.size() - 1 + segments - 1)


func test_corners_one_cell_apart_do_not_overlap_or_double_back() -> void:
	for pair in [["S-bend", _s_bend()], ["U-turn", _u_turn()], ["stairs", _stairs()]]:
		var cells: Array[Vector2i] = pair[1]
		_check_curve(Route.build_curved(cells), cells, pair[0])


func test_every_valley_route_stays_on_its_road_and_flows_smoothly() -> void:
	for map_seed in _seeds:
		var map := _valley(map_seed)
		for r in map.routes.size():
			var cells: Array[Vector2i] = []
			cells.assign(map.routes[r])
			_check_curve(Route.build_curved(cells), cells, "seed %d route %d" % [map_seed, r])


func test_position_at_is_continuous_along_a_curved_route() -> void:
	var route := Route.build_curved(_valley(42).path)
	var step := 0.05
	var previous := route.position_at(0.0)
	var along := step
	while along <= route.total + step:
		var at := route.position_at(along)
		var dx := at.x - previous.x
		var dy := at.y - previous.y
		assert_lte(sqrt(dx * dx + dy * dy), step + EPSILON, "at %f" % along)
		previous = at
		along += step


func test_position_at_finds_the_same_segment_as_a_walk_from_the_start() -> void:
	# `position_at` searches the distances by bisection; it must pick the segment the old
	# walk from the start picked, ties and repeated distances included, so classic boards
	# move bit for bit as before
	var routes: Array[Route] = [Route.build_curved(_valley(7).path), Route.build(_valley(7).path)]
	routes.append(Route.straight(0.5, -0.45, 0.5, -0.45))
	for route in routes:
		var alongs: Array[float] = [-1.0, 0.0, route.total, route.total + 3.0]
		for i in route.cumulative.size():
			alongs.append(route.cumulative[i])
			alongs.append(route.cumulative[i] + 1e-7)
			alongs.append(route.cumulative[i] - 1e-7)
		for along in alongs:
			var want := _walked_position(route, along)
			var got := route.position_at(along)
			assert_eq([got.x, got.y], [want.x, want.y], "at %f" % along)


## The position as `position_at` found it before the bisection: a walk from the first point.
func _walked_position(route: Route, along: float) -> RoutePoint:
	var i := 0
	while i < route.cumulative.size() - 2 and route.cumulative[i + 1] < along:
		i += 1
	var start := route.cumulative[i]
	var length := route.cumulative[i + 1] - start
	var fraction := 0.0
	if length > 0.0:
		fraction = minf(1.0, maxf(0.0, (along - start) / length))
	var point := RoutePoint.new()
	point.x = route.xs[i] + (route.xs[i + 1] - route.xs[i]) * fraction
	point.y = route.ys[i] + (route.ys[i + 1] - route.ys[i]) * fraction
	return point


func test_cell_distance_on_a_grid_route_is_the_distance_to_the_cell_centre() -> void:
	var cells := _one_corner()
	var route := Route.build(cells)
	for i in cells.size():
		assert_eq(route.cell_distance(i), route.cumulative[i + 1])


func test_the_valley_game_walks_curved_routes() -> void:
	for map_seed in [1, 42]:
		var game := Game.create(map_seed)
		assert_gte(game.map.cols, RULES.VALLEY_MIN_COLS)
		for r in game.routes.size():
			var cells: Array[Vector2i] = []
			cells.assign(game.map.routes[r])
			var want := Route.build_curved(cells)
			assert_eq(game.routes[r].xs, want.xs, "seed %d route %d" % [map_seed, r])
			assert_eq(game.routes[r].ys, want.ys, "seed %d route %d" % [map_seed, r])
			assert_gt(game.routes[r].xs.size(), cells.size() + 1, "it has corners to round")


func test_classic_boards_keep_the_grid_route() -> void:
	var games: Array[GameState] = [
		Game.create(3, RULES.LANDSCAPE_COLS, RULES.LANDSCAPE_ROWS),
		# the fixtures' board, with their detour and single-cell sockets
		Game.create(3, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1, false),
	]
	for game in games:
		assert_gt(game.routes.size(), 0)
		for r in game.routes.size():
			var cells: Array[Vector2i] = []
			cells.assign(game.map.routes[r])
			var want := Route.build(cells)
			var label := "%d by %d, route %d" % [game.map.cols, game.map.rows, r]
			assert_eq(game.routes[r].xs, want.xs, label)
			assert_eq(game.routes[r].cumulative, want.cumulative, label)
			assert_false(game.routes[r].curved, label)


func test_after_the_join_both_routes_are_the_same_curve() -> void:
	var checked := 0
	for map_seed in _seeds:
		var game := Game.create(map_seed)
		if game.routes.size() < 2:
			continue
		checked += 1
		var main := game.routes[0]
		var second := game.routes[1]
		var settled := second.cell_distance(game.map.feeder_length + Route.JOIN_SETTLE_CELLS)
		assert_almost_eq(
			settled - game.second_offset,
			main.cell_distance(game.map.join_index + Route.JOIN_SETTLE_CELLS),
			EPSILON,
			"seed %d" % map_seed
		)
		assert_almost_eq(second.total - game.second_offset, main.total, EPSILON)
		var along := settled
		while along <= second.total:
			var a := second.position_at(along)
			var b := main.position_at(along - game.second_offset)
			assert_almost_eq(a.x, b.x, EPSILON, "x at %f, seed %d" % [along, map_seed])
			assert_almost_eq(a.y, b.y, EPSILON, "y at %f, seed %d" % [along, map_seed])
			along += 0.1
	assert_gt(checked, 25, "most valley maps have a second road")


func test_a_second_route_foe_is_on_the_main_road_from_the_join_cell() -> void:
	for map_seed in range(1, 40):
		var game := Game.create(map_seed)
		if game.routes.size() < 2:
			continue
		var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 1)
		var join := game.routes[1].cell_distance(game.map.feeder_length)
		foe.distance = join - 0.01
		assert_eq(Barracks.main_distance(game, foe), -1.0, "still on the feeder")
		foe.distance = join
		assert_gte(Barracks.main_distance(game, foe), 0.0, "on the main road")
		return
	fail_test("no seed with a second road")


func test_flying_routes_start_where_the_curved_routes_start() -> void:
	var game := Game.create(42)
	for r in game.routes.size():
		var start := game.routes[r].position_at(0.0)
		var air := game.air_routes[r].position_at(0.0)
		assert_eq([air.x, air.y], [start.x, start.y])
