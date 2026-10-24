## Guards on a forked road with curved routes and at the ends of a route (#481): the shared
## stretches stop short of the corners at the fork and the merge, the main road wins an exact tie,
## and a guard far along a branch longer than the main road is not pulled back.
extends GutTest

const BRANCH := 2


func _foe(game: GameState, route: int, distance: float) -> Foe:
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, route)
	foe.distance = distance
	return foe


func _post_of(game: GameState, anchor: Vector2i) -> Barracks.PostSpot:
	var tent := Tower.new()
	tent.col = anchor.x
	tent.row = anchor.y
	return Barracks.post_spot(game, tent)


## How many sampled points of `from` the map `to_other` calls the other road's whose line is
## not the other road's there (a shared stretch that is not one).
func _lies(game: GameState, route: int, to_other: Callable, other: int) -> int:
	var lies := 0
	var here: Route = game.routes[route]
	var steps := int(floor(here.total / 0.01))
	var shared := 0
	for i in steps:
		var distance := float(i) * 0.01
		var along: float = to_other.call(distance)
		if along < 0.0:
			continue
		shared += 1
		var a := here.position_at(distance)
		var b: RoutePoint = (game.routes[other] as Route).position_at(along)
		if absf(a.x - b.x) > 1e-6 or absf(a.y - b.y) > 1e-6:
			lies += 1
	assert_gt(shared, steps / 4, "most of the road is shared")
	assert_lt(shared, steps - 100, "but not all of it")
	return lies


func test_on_curved_routes_a_branch_is_the_main_road_only_where_the_two_lines_coincide() -> void:
	var game := ForkKit.game(1, ForkKit.curved_map())
	assert_true(game.routes[BRANCH].curved)
	var from_branch := func(distance: float) -> float:
		return Barracks.main_distance(game, _foe(game, BRANCH, distance))
	var from_main := func(distance: float) -> float:
		return Barracks.along(game, _foe(game, 0, distance), BRANCH)
	assert_eq(_lies(game, BRANCH, from_branch, 0), 0, "branch onto main")
	assert_eq(_lies(game, 0, from_main, BRANCH), 0, "main onto branch")


func test_main_distance_matches_the_link_both_ways_on_curved_routes() -> void:
	var game := ForkKit.game(1, ForkKit.curved_map())
	# the corner cells of the branch's curve (the fork and the merge) are off the main road's line
	var fork_corner := game.routes[BRANCH].cell_distance(ForkKit.FORK_CELL)
	assert_eq(Barracks.main_distance(game, _foe(game, BRANCH, fork_corner)), -1.0)
	var merge_corner := game.routes[BRANCH].cell_distance(ForkKit.branch_merge_cell(game))
	assert_eq(Barracks.main_distance(game, _foe(game, BRANCH, merge_corner)), -1.0)


func test_a_branch_stretch_the_link_gives_to_the_main_road_never_holds_the_post() -> void:
	var game := ForkKit.game(1, ForkKit.curved_map())
	var link := game.links[BRANCH] as RouteLink
	var nearest := _post_of(game, ForkKit.BRANCH_SOCKET)
	assert_eq(nearest.route, BRANCH)
	# the link's end points belong to the shared stretch: the next point in takes the post
	link.head = nearest.along
	var after := _post_of(game, ForkKit.BRANCH_SOCKET)
	assert_gt(after.along, nearest.along, "a point at the head is the main road's")
	link.head = 0.0
	link.tail_route = nearest.along
	var before := _post_of(game, ForkKit.BRANCH_SOCKET)
	assert_lt(before.along, nearest.along, "a point at the tail is the main road's")


func test_a_tent_equally_near_the_branch_and_the_main_road_keeps_the_main_road() -> void:
	var game := ForkKit.game()
	# the branch's line is the main road's moved up two rows: every point of one has a twin
	# on the other exactly as far from the tent, down to the last bit
	var cells: Array[Vector2i] = []
	for x in ForkKit.COLS:
		cells.append(Vector2i(x, ForkKit.BRANCH_ROW))
	game.routes[BRANCH] = Route.build(cells)
	var link := game.links[BRANCH] as RouteLink
	link.head = 0.0
	link.tail_route = game.routes[BRANCH].total + 1.0
	var spot := _post_of(game, ForkKit.TIE_SOCKET)
	assert_eq(spot.route, 0, "the main road wins a tie")
	assert_almost_eq(game.routes[0].position_at(spot.along).x, 6.5, 0.01)


func test_guards_far_along_a_branch_longer_than_the_main_road_are_not_pulled_back() -> void:
	# the board is narrow, so the branch (the longer way round) reaches past the main road's end
	var on := ForkKit.map(11)
	on.sockets = [Vector2i(9, 0)]
	var game := ForkKit.game_with_tent(Vector2i(9, 0), 1, on)
	assert_gt(game.routes[BRANCH].total, game.routes[0].total)
	for guard in game.guards:
		assert_eq(guard.route, BRANCH)
		assert_gt(guard.post, game.routes[0].total, "past the main road's length")
		assert_almost_eq(Barracks.post_point(game, guard).x, 9.5, 0.3, "beside the tent")
