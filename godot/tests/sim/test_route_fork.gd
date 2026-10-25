## A spawn source that can walk several routes picks one per foe from the route stream (#481).
extends GutTest

const WAVES := preload("res://content/waves.gd")
const FOES := 600
## Wave 15 is a swarm and past the wave where the second spawn source starts.
const BIG_WAVE := 15


func test_a_map_without_sources_has_one_source_per_route() -> void:
	assert_eq(ForkKit.map_without_fork().source_count(), 2)
	assert_eq(ForkKit.map().source_count(), 2, "the branch is not a source of its own")
	var plain := ForkKit.map_without_fork()
	plain.routes.remove_at(1)
	assert_eq(plain.source_count(), 1)


func test_from_map_builds_a_route_for_every_map_route() -> void:
	var game := ForkKit.game()
	assert_eq(game.routes.size(), 3)
	assert_eq(game.air_routes.size(), 3)
	assert_false(game.random_lanes)


func test_both_branches_get_foes_about_evenly() -> void:
	var game := ForkKit.game(3)
	var on_main := 0
	var on_branch := 0
	for i in FOES:
		var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, FoeSpawner.route_of_source(game, 0))
		assert_true(foe.route == 0 or foe.route == 2, "source 0 walks the main road or the branch")
		if foe.route == 0:
			on_main += 1
		else:
			on_branch += 1
	assert_gt(on_main, FOES * 4 / 10)
	assert_gt(on_branch, FOES * 4 / 10)


func test_the_feeder_source_never_draws() -> void:
	var game := ForkKit.game(3)
	var before := game.route_rng.state
	for i in 20:
		assert_eq(FoeSpawner.route_of_source(game, 1), 1)
	assert_eq(game.route_rng.state, before)


func test_one_draw_per_foe_of_a_forked_source() -> void:
	var game := ForkKit.game(5)
	var twin := Rng.derive(5, Streams.ROUTES)
	for i in 10:
		var route := FoeSpawner.route_of_source(game, 0)
		assert_eq(route, [0, 2][twin.next_int(2)])


func test_a_wave_sends_foes_down_both_branches_and_the_feeder() -> void:
	var game := ForkKit.game(7)
	var routes := ForkKit.routes_spawned(game, BIG_WAVE)
	assert_true(routes.has(0))
	assert_true(routes.has(1), "the second source sends groups down the feeder")
	assert_true(routes.has(2))


func test_a_wave_with_no_source_given_draws_once_per_foe_between_the_branches() -> void:
	# up to wave 10 every order has source -1, which means the first source
	var game := ForkKit.game(9)
	var routes := ForkKit.routes_spawned(game, 3)
	assert_gt(routes.size(), 4)
	assert_true(routes.has(0))
	assert_true(routes.has(2))
	assert_false(routes.has(1), "the feeder source is not used before the split")
	var twin := Rng.derive(9, Streams.ROUTES)
	for i in routes.size():
		assert_eq(routes[i], [0, 2][twin.next_int(2)])
	assert_eq(game.route_rng.state, twin.state, "one draw per foe, no more")


func test_a_replay_on_a_forked_map_is_reproducible() -> void:
	var first := ForkKit.game(11)
	var second := ForkKit.game(11)
	var a := ForkKit.routes_spawned(first, BIG_WAVE)
	var b := ForkKit.routes_spawned(second, BIG_WAVE)
	assert_eq(a, b)
	assert_eq(first.route_rng.state, second.route_rng.state)
	assert_eq(GameTestKit.snapshot(first), GameTestKit.snapshot(second))
	var other := ForkKit.game(12)
	assert_ne(ForkKit.routes_spawned(other, BIG_WAVE), a, "another seed picks differently")


## Grid routes: the positions are checked against the cells each route is made of.
func test_foes_walk_the_grid_route_of_the_branch_they_took() -> void:
	var game := ForkKit.game(2)
	var main := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	var branch := FoeSpawner.spawn(game, "scrapGoblin", 1, 2)
	for foe in [main, branch]:
		foe.speed = 1.0
	for i in 60:
		Game.tick(game)
	# 2 s at 1 cell per second would be 2 cells on route 0; both follow their own line
	assert_almost_eq(main.y, float(ForkKit.MAIN_ROW) + 0.5, 1e-9)
	assert_gt(branch.distance, 0.0)
	assert_almost_eq(branch.y, float(ForkKit.MAIN_ROW) + 0.5, 1e-9, "still on the shared road")
	# on the branch's turn (column 3, row 2) it is on row 2; the main road is on row 4 there
	var top := game.routes[2].position_at(game.routes[2].cell_distance(ForkKit.FORK_CELL + 2))
	assert_almost_eq(top.x, float(ForkKit.FORK_CELL) + 0.5, 1e-9)
	assert_almost_eq(top.y, float(ForkKit.BRANCH_ROW) + 0.5, 1e-9)
	var main_at := game.routes[0].position_at(game.routes[0].cell_distance(ForkKit.FORK_CELL + 2))
	assert_almost_eq(main_at.x, float(ForkKit.FORK_CELL) + 2.5, 1e-9)
	assert_almost_eq(main_at.y, float(ForkKit.MAIN_ROW) + 0.5, 1e-9)


func test_a_map_without_a_fork_draws_nothing() -> void:
	var game := ForkKit.game(7, ForkKit.map_without_fork())
	var before := game.route_rng.state
	ForkKit.routes_spawned(game, BIG_WAVE)
	assert_eq(game.route_rng.state, before)


func test_the_game_board_draws_nothing() -> void:
	var game := Game.create_on_strip_valley(1)
	assert_true(game.map.sources.is_empty())
	assert_true(game.map.forks.is_empty())
	var before := game.route_rng.state
	game.heartstone_health = 1000000
	ForkKit.routes_spawned(game, BIG_WAVE)
	assert_eq(game.route_rng.state, before)


func test_a_split_child_keeps_its_branch() -> void:
	var game := ForkKit.game(4)
	var golem := FoeSpawner.spawn(game, "cardboardGolem", 10, 2)
	var child := FoeSpawner.spawn(game, "scrapGoblin", 10, golem.route)
	assert_eq(child.route, 2)
