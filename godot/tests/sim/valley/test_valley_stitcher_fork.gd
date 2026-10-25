extends GutTest
## The stitcher builds the fork's second lane (#481): on the layout valley the routes are
## `[A, feeder, B]`, the sources `[[0, B], [1]]`, B is the sections' branches where they have one
## and their roads where they do not, and a Guard Tent on B's bridge holds B's foes. Every board
## without a branch stays as it was.

const SEEDS: Array[int] = [1, 7, 42, 2026, 3001]
const MEADOW := ValleyLayout.Region.SUNKEN_MEADOW
const CROSSING := ValleyLayout.Region.BLUEWATER_CROSSING
const LANE := 2
const FEEDER := 1

var _maps := {}


func _map(seed: int) -> GameMap:
	if not _maps.has(seed):
		_maps[seed] = MapGen.generate_layout_valley(seed)
	return _maps[seed]


func _own_cells(map: GameMap) -> Array[Vector2i]:
	var fork := map.forks[0]
	var route: Array[Vector2i] = []
	route.assign(map.routes[LANE])
	return route.slice(fork.fork_index + 1, fork.fork_index + 1 + fork.branch_length)


func test_the_layout_valley_has_three_routes_and_two_sources() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		assert_not_null(map, "seed %d" % seed)
		assert_eq(map.routes.size(), 3, "seed %d: A, the feeder, B" % seed)
		assert_eq(map.sources.size(), 2)
		assert_eq(Array(map.sources[0]), [0, LANE], "seed %d" % seed)
		assert_eq(Array(map.sources[1]), [FEEDER])
		assert_eq(map.source_count(), 2)
		assert_eq(map.forks.size(), 1)
		assert_eq(map.forks[0].route, LANE)
		assert_eq(map.route_curves.size(), 3, "a curve per route, seed %d" % seed)


func test_the_fork_runs_from_the_meadows_entry_to_the_crossings_exit() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var layout := ValleyLayout.generate(seed, 40, 24)
		var fork := map.forks[0]
		assert_eq(map.path[fork.fork_index], layout.slots[MEADOW].entry, "seed %d" % seed)
		assert_eq(map.path[fork.merge_index], layout.slots[CROSSING].exit, "seed %d" % seed)
		assert_gt(fork.branch_length, 0)


func test_route_b_shares_the_road_before_the_fork_and_after_the_merge() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var fork := map.forks[0]
		var lane: Array = map.routes[LANE]
		assert_eq(lane.slice(0, fork.fork_index + 1), map.path.slice(0, fork.fork_index + 1))
		var tail_from := fork.fork_index + 1 + fork.branch_length
		assert_eq(lane.slice(tail_from), map.path.slice(fork.merge_index), "seed %d" % seed)
		assert_eq(lane.size(), tail_from + map.path.size() - fork.merge_index)


func test_route_b_walks_in_unit_steps_and_is_the_longer_way() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var lane: Array = map.routes[LANE]
		for index in range(1, lane.size()):
			assert_eq((lane[index] - lane[index - 1]).length_squared(), 1, "seed %d" % seed)
		# the lanes may share raster cells near the fork and the merge (the curves still differ);
		# B has cells of its own that A does not
		var between := map.path.slice(map.forks[0].fork_index + 1, map.forks[0].merge_index)
		assert_true(
			_own_cells(map).any(func(cell: Vector2i) -> bool: return not between.has(cell)),
			"seed %d" % seed
		)
		var routes := Route.for_map(map)
		assert_gt(routes[LANE].total, routes[0].total, "seed %d: B is longer" % seed)


func test_every_curve_has_a_point_for_each_cell_of_its_route() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		for index in map.routes.size():
			var curve: RoadCurve = map.route_curves[index]
			assert_eq(curve.cells, map.routes[index], "route %d, seed %d" % [index, seed])
			assert_eq(curve.cell_points.size(), map.routes[index].size())
		var main: RoadCurve = map.route_curves[0]
		var lane: RoadCurve = map.route_curves[LANE]
		var fork := map.forks[0]
		var shared := main.cell_points[fork.fork_index]
		for point in shared + 1:
			assert_eq(lane.xs[point], main.xs[point], "same line before the fork, seed %d" % seed)
			assert_eq(lane.ys[point], main.ys[point])


func test_the_band_and_the_road_tiles_cover_route_b() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		for cell in _own_cells(map):
			assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "seed %d at %s" % [seed, cell])
		# every cell any part of which lies within half the band of the lane's curve is road
		# (#469), the cells off the lane's centre line included
		var curve: RoadCurve = map.route_curves[LANE]
		var smooth := 0
		for k in range(map.forks[0].fork_index + 1, map.forks[0].fork_index + 1 + 20):
			var point := curve.cell_points[k]
			smooth += 1 if curve.xs[point] != float(curve.cells[k].x) + 0.5 else 0
		assert_gt(smooth, 0, "the lane's own stretch is a spline, seed %d" % seed)
		var half := map.road_width / 2.0
		var beside := 0
		for index in curve.xs.size():
			var at := Vector2i(int(floor(curve.xs[index])), int(floor(curve.ys[index])))
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var cell := at + Vector2i(dx, dy)
					if map.in_bounds(cell) and curve.rect_gap(cell.x, cell.y, 1) < half - 1e-6:
						assert_eq(map.tiles[cell.y][cell.x], GameMap.Tile.ROAD, "seed %d" % seed)
						beside += 0 if curve.cells.has(cell) else 1
		assert_gt(beside, 0, "the band reaches cells off the centre line, seed %d" % seed)


func test_each_lane_has_a_bridge_and_lane_bs_names_its_route() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var on_a := 0
		var on_b := 0
		for bridge in map.bridges:
			if bridge.route == LANE:
				on_b += 1
				assert_eq(map.routes[LANE][bridge.path_index], bridge.cell, "seed %d" % seed)
				assert_false(map.path.has(bridge.cell), "B's own cell")
			else:
				on_a += 1
				assert_eq(bridge.route, 0)
				assert_eq(map.path[bridge.path_index], bridge.cell)
		assert_gt(on_a, 0, "seed %d: the upper bridge" % seed)
		assert_gt(on_b, 0, "seed %d: the lower bridge" % seed)


func test_the_sockets_keep_off_the_band_of_lane_b() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var lane: RoadCurve = map.route_curves[LANE]
		for anchor in map.sockets:
			var gap := lane.rect_gap(anchor.x, anchor.y, map.footprint)
			assert_gte(gap, map.road_width / 2.0, "seed %d: block %s" % [seed, anchor])


func test_the_hero_walks_from_the_spawn_over_each_bridge_to_the_heartstone() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var graph := HeroGraph.from_map(map)
		var spawn := map.path[0]
		var last := map.path[map.path.size() - 1]
		assert_gt(graph.steps(spawn, last), 0, "seed %d" % seed)
		for bridge in map.bridges:
			assert_true(map.is_walkable(bridge.cell), "seed %d at %s" % [seed, bridge.cell])
			assert_gt(
				graph.steps(spawn, bridge.cell), 0, "seed %d: spawn to %s" % [seed, bridge.cell]
			)
			assert_gt(
				graph.steps(bridge.cell, last), 0, "seed %d: %s to the end" % [seed, bridge.cell]
			)


func test_a_layout_without_the_fork_stitches_as_before() -> void:
	for seed in [1, 42]:
		var layout := ValleyLayout.generate(seed, 40, 24, false)
		var map := ValleyStitcher.build(seed, 40, 24, ValleyLayout.sections(), layout)
		assert_eq(map.routes.size(), 2)
		assert_true(map.sources.is_empty())
		assert_true(map.forks.is_empty())
		assert_eq(map.route_curves.size(), 2)
		for bridge in map.bridges:
			assert_eq(bridge.route, 0)


func test_the_game_board_and_the_strip_valley_have_no_fork() -> void:
	for seed in [1, 42, 2026]:
		for map in [Game.create_on_strip_valley(seed).map, MapGen.generate_valley(seed)]:
			assert_eq(map.routes.size(), 2, "seed %d" % seed)
			assert_true(map.sources.is_empty())
			assert_true(map.forks.is_empty())
			for bridge in map.bridges:
				assert_eq(bridge.route, 0)


# --- a Guard Tent on lane B's bridge


## The block whose guards would stand on lane B's own stretch nearest its bridge, along the lane.
func _tent_socket(game: GameState) -> Vector2i:
	var bridge: GameMap.Bridge = null
	for each in game.map.bridges:
		if each.route == LANE:
			bridge = each
			break
	var at := game.routes[LANE].cell_distance(bridge.path_index)
	var best := Vector2i(-1, -1)
	var best_gap := 1.0e30
	for anchor in game.map.sockets:
		var tent := Tower.new()
		tent.col = anchor.x
		tent.row = anchor.y
		var spot := Barracks.post_spot(game, tent)
		if spot.route == LANE and absf(spot.along - at) < best_gap:
			best = anchor
			best_gap = absf(spot.along - at)
	return best


func test_a_tent_posted_on_lane_b_holds_lane_b_foes_on_a_real_map() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var anchor := _tent_socket(ForkKit.game(seed, map))
		assert_ne(anchor, Vector2i(-1, -1), "seed %d: a block posts on lane B" % seed)
		var game := ForkKit.game_with_tent(anchor, seed, map)
		assert_eq(game.guards.size(), 2, "seed %d" % seed)
		var link: RouteLink = game.links[LANE]
		for guard in game.guards:
			assert_eq(guard.route, LANE, "seed %d" % seed)
		var post: float = (game.guards[0].post + game.guards[1].post) / 2.0
		assert_gt(post, link.head)
		assert_lt(post, link.tail_route)
		var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, LANE)
		foe.distance = post - 0.1
		GameTestKit.run(game, [])
		assert_ne(foe.engaged_guard_id, -1, "seed %d: lane B's foe is held" % seed)
		assert_eq(Barracks.main_distance(game, foe), -1.0, "on B's own stretch")
		var main_foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
		main_foe.distance = post - 0.1
		GameTestKit.run(game, [])
		assert_eq(main_foe.engaged_guard_id, -1, "seed %d: the upper lane's foe walks on" % seed)


func test_main_distance_maps_lane_b_foes_through_the_link_on_a_real_map() -> void:
	for seed in SEEDS:
		var map := _map(seed)
		var game := ForkKit.game(seed, map)
		var link: RouteLink = game.links[LANE]
		var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, LANE)
		foe.distance = link.head * 0.5
		assert_eq(Barracks.main_distance(game, foe), foe.distance, "before the fork")
		foe.distance = (link.head + link.tail_route) / 2.0
		assert_eq(Barracks.main_distance(game, foe), -1.0, "on its own stretch")
		foe.distance = link.tail_route + 1.0
		assert_almost_eq(
			Barracks.main_distance(game, foe), link.tail_main + 1.0, 1e-9, "after the merge"
		)
		assert_gt(link.offset(), 0.0, "B is the longer way, seed %d" % seed)


# --- the section checks of a branch


func _crossing_attempt(seed: int) -> Array:
	var layout := ValleyLayout.generate(seed, 40, 24)
	var slot := layout.slots[CROSSING]
	var section := ValleyLayout.sections()[CROSSING]
	return [slot, section, section.generate(slot, layout.rng_for(CROSSING, 0))]


func _texts(slot: ValleyPlan.Slot, result: SectionResult, section: ValleySection) -> String:
	var found := ValleyChecks.section_problems(slot, result, section)
	return " | ".join(found.map(func(p: ValleyChecks.Problem) -> String: return p.text))


func test_a_branch_that_misses_its_gates_or_jumps_fails_its_section() -> void:
	var made := _crossing_attempt(42)
	var slot: ValleyPlan.Slot = made[0]
	var section: ValleySection = made[1]
	var result: SectionResult = made[2]
	assert_false(result.branch.is_empty(), "the crossing carries its lane")
	assert_eq(_texts(slot, result, section).count("branch"), 0, _texts(slot, result, section))
	var missing := result.branch.duplicate()
	result.branch = []
	assert_string_contains(_texts(slot, result, section), "branch does not run")
	result.branch.assign(missing.slice(1))
	assert_string_contains(_texts(slot, result, section), "branch does not run")
	missing.remove_at(3)
	result.branch.assign(missing)
	assert_string_contains(_texts(slot, result, section), "branch jumps")


func test_a_branch_the_slot_does_not_plan_fails_its_section() -> void:
	var made := _crossing_attempt(42)
	var slot: ValleyPlan.Slot = made[0]
	slot.branch_spine = []
	assert_string_contains(_texts(slot, made[2], made[1]), "does not plan")


func test_a_block_or_a_bridge_off_the_lane_fails_its_section() -> void:
	var made := _crossing_attempt(42)
	var slot: ValleyPlan.Slot = made[0]
	var result: SectionResult = made[2]
	var held: Vector2i = result.sockets[0]
	result.sockets[0] = result.branch[result.branch.size() / 2] - Vector2i.ONE
	assert_string_contains(_texts(slot, result, made[1]), "does not fit")
	result.sockets[0] = held
	for bridge in result.bridges:
		if bridge.on_branch:
			bridge.cell = Vector2i.ZERO
			break
	assert_string_contains(_texts(slot, result, made[1]), "is off the road")
