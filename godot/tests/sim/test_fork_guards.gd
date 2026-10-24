## Guards on a forked road (#481): a Guard Tent posts its guards on the branch nearest it, a guard
## holds the foes that walk its own route up to it, and a foe on any branch has a distance along
## the main road wherever the branch is the main road's line.
extends GutTest

const BRANCH := 2
const EPSILON := 1e-9


func _foe(game: GameState, route: int, distance: float) -> Foe:
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, route)
	foe.distance = distance
	return foe


func _middle(game: GameState) -> float:
	return (game.guards[0].post + game.guards[1].post) / 2.0


## How much further along the branch a point of the shared tail is than along the main road.
func _tail_offset(game: GameState) -> float:
	return (
		game.routes[BRANCH].cell_distance(ForkKit.branch_merge_cell(game))
		- game.routes[0].cell_distance(ForkKit.MERGE_CELL)
	)


func _mess_of(game: GameState) -> Tower:
	for tower in game.towers:
		if tower.type == "messTent":
			return tower
	return null


func _build_mess(game: GameState, anchor: Vector2i) -> void:
	GameTestKit.run(game, [Command.build("messTent", anchor.x, anchor.y)])


# --- where guards post


func test_a_tent_beside_the_branch_posts_its_guards_on_the_branch() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	assert_eq(game.guards.size(), 2)
	for guard in game.guards:
		assert_eq(guard.route, BRANCH)
		var at := game.routes[BRANCH].position_at(guard.post)
		assert_almost_eq(at.y, 2.5, 0.01, "on the branch's row")
		assert_almost_eq(at.x, 6.5, 0.4, "beside the tent")


func test_a_tent_beside_the_main_road_keeps_its_guards_on_it() -> void:
	var game := ForkKit.game_with_tent(ForkKit.MAIN_SOCKET)
	for guard in game.guards:
		assert_eq(guard.route, 0)
		assert_almost_eq(game.routes[0].position_at(guard.post).y, 4.5, 1e-9)


func test_the_post_on_the_main_road_is_the_one_a_map_without_the_fork_gives() -> void:
	for anchor in [ForkKit.MAIN_SOCKET, ForkKit.TAIL_SOCKET]:
		var forked := ForkKit.game_with_tent(anchor)
		var plain := ForkKit.game_with_tent(anchor, 1, ForkKit.map_without_fork())
		assert_eq(forked.guards[0].route, 0)
		assert_eq(forked.guards[0].post, plain.guards[0].post)
		assert_eq(forked.guards[1].post, plain.guards[1].post)


func test_a_tent_beside_the_shared_tail_posts_on_the_main_road() -> void:
	var game := ForkKit.game_with_tent(ForkKit.TAIL_SOCKET)
	assert_eq(game.guards[0].route, 0)
	assert_almost_eq(game.routes[0].position_at(game.guards[0].post).x, 11.5, 0.4)


func test_guards_raised_on_the_branch_are_read_at_their_post_on_it() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	var at := Barracks.post_point(game, game.guards[0])
	assert_almost_eq(at.y, 2.5, 0.01)


# --- who a guard holds


func test_a_guard_on_the_branch_holds_a_foe_walking_the_branch() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	var foe := _foe(game, BRANCH, _middle(game) - 0.1)
	GameTestKit.run(game, [])
	assert_ne(foe.engaged_guard_id, -1, "held")
	var engaged := GuardKit.events_of(game, GameEvent.Kind.FOE_ENGAGED)
	assert_eq(engaged.size(), 1)
	assert_eq(engaged[0].foe_id, foe.id)


func test_a_guard_on_the_branch_ignores_a_foe_on_the_main_roads_parallel_stretch() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	# the same number along the main road is the stretch beside the branch (x about 6.5)
	var foe := _foe(game, 0, _middle(game) - 0.1)
	GameTestKit.run(game, [])
	assert_eq(foe.engaged_guard_id, -1)
	var feeder := _foe(game, 1, _middle(game) - 0.1 + game.second_offset)
	GameTestKit.run(game, [])
	assert_eq(feeder.engaged_guard_id, -1, "nor the feeder's foe in the same place")


func test_a_guard_on_the_main_road_ignores_a_branch_foe_beside_it() -> void:
	var game := ForkKit.game_with_tent(ForkKit.MAIN_SOCKET)
	var foe := _foe(game, BRANCH, _middle(game) - 0.1)
	GameTestKit.run(game, [])
	assert_eq(foe.engaged_guard_id, -1)
	var main_foe := _foe(game, 0, _middle(game) - 0.1)
	GameTestKit.run(game, [])
	assert_ne(main_foe.engaged_guard_id, -1, "the main road's foe is held")


func test_a_foe_walking_the_other_branch_is_never_held() -> void:
	for anchor in [ForkKit.BRANCH_SOCKET, ForkKit.MAIN_SOCKET]:
		var game := ForkKit.game_with_tent(anchor)
		var other := 0 if game.guards[0].route == BRANCH else BRANCH
		var foe := _foe(game, other, 0.0)
		var steps := 0
		while foe.alive and foe.distance < game.routes[other].total - 1.0 and steps < 2000:
			Game.tick(game)
			assert_eq(foe.engaged_guard_id, -1, "at %f" % foe.distance)
			steps += 1
		assert_gt(foe.distance, game.routes[other].total - 1.5, "it walked to the end")


func test_a_foe_walking_up_to_a_guard_on_its_own_branch_is_held() -> void:
	for anchor in [ForkKit.BRANCH_SOCKET, ForkKit.MAIN_SOCKET]:
		var game := ForkKit.game_with_tent(anchor)
		var route: int = game.guards[0].route
		var foe := _foe(game, route, 0.0)
		var steps := 0
		while foe.engaged_guard_id == -1 and steps < 2000:
			Game.tick(game)
			steps += 1
		assert_ne(foe.engaged_guard_id, -1, "held on route %d" % route)
		assert_lte(foe.distance, _middle(game) + 0.3)


func test_a_guard_on_the_shared_tail_holds_the_foes_of_both_branches_and_the_feeder() -> void:
	var middle := _middle(ForkKit.game_with_tent(ForkKit.TAIL_SOCKET))
	var kinds := {
		"main": [0, 0.0],
		"branch": [BRANCH, _tail_offset(ForkKit.game())],
		"feeder": [1, ForkKit.game().second_offset],
	}
	for kind: String in kinds:
		var game := ForkKit.game_with_tent(ForkKit.TAIL_SOCKET)
		var foe := _foe(game, kinds[kind][0], middle - 0.1 + kinds[kind][1])
		GameTestKit.run(game, [])
		assert_ne(foe.engaged_guard_id, -1, kind)


# --- the distance along the main road


func test_main_distance_of_a_branch_foe_follows_the_link() -> void:
	var game := ForkKit.game()
	var head := game.routes[0].cell_distance(ForkKit.FORK_CELL)
	var tail := game.routes[BRANCH].cell_distance(ForkKit.branch_merge_cell(game))
	var offset := _tail_offset(game)
	assert_gt(offset, 0.0, "the branch is the longer way")
	var foe := _foe(game, BRANCH, 1.25)
	assert_eq(Barracks.main_distance(game, foe), 1.25, "on the shared prefix")
	foe.distance = head
	assert_eq(Barracks.main_distance(game, foe), head, "at the fork cell")
	foe.distance = head + 0.01
	assert_eq(Barracks.main_distance(game, foe), -1.0, "just past the fork")
	foe.distance = (head + tail) / 2.0
	assert_eq(Barracks.main_distance(game, foe), -1.0, "on its own stretch")
	foe.distance = tail - 0.01
	assert_eq(Barracks.main_distance(game, foe), -1.0, "just before the merge")
	foe.distance = tail
	assert_almost_eq(Barracks.main_distance(game, foe), tail - offset, EPSILON, "at the merge")
	foe.distance = tail + 2.0
	assert_almost_eq(
		Barracks.main_distance(game, foe),
		game.routes[0].cell_distance(ForkKit.MERGE_CELL) + 2.0,
		EPSILON,
		"two cells past the merge on both roads"
	)


func test_main_distance_of_the_feeder_and_the_main_road_is_unchanged_on_a_forked_map() -> void:
	var game := ForkKit.game()
	var join := game.routes[0].cell_distance(game.map.join_index)
	var main_foe := _foe(game, 0, 4.0)
	assert_eq(Barracks.main_distance(game, main_foe), 4.0)
	var feeder := _foe(game, 1, join + game.second_offset - 0.01)
	assert_eq(Barracks.main_distance(game, feeder), -1.0, "still on the feeder")
	feeder.distance = join + game.second_offset + 2.0
	assert_eq(Barracks.main_distance(game, feeder), feeder.distance - game.second_offset)


func test_along_a_branch_maps_every_road_onto_that_branch() -> void:
	var game := ForkKit.game()
	var head := game.routes[0].cell_distance(ForkKit.FORK_CELL)
	var tail_main := game.routes[0].cell_distance(ForkKit.MERGE_CELL)
	var offset := _tail_offset(game)
	var own := _foe(game, BRANCH, 5.0)
	assert_eq(Barracks.along(game, own, BRANCH), 5.0, "its own route")
	var main_foe := _foe(game, 0, head)
	assert_eq(Barracks.along(game, main_foe, BRANCH), head, "the shared prefix")
	main_foe.distance = head + 0.01
	assert_eq(Barracks.along(game, main_foe, BRANCH), -1.0, "the parallel stretch")
	main_foe.distance = tail_main - 0.01
	assert_eq(Barracks.along(game, main_foe, BRANCH), -1.0, "just before the merge")
	main_foe.distance = tail_main
	assert_almost_eq(Barracks.along(game, main_foe, BRANCH), tail_main + offset, EPSILON, "merge")
	main_foe.distance = tail_main + 1.0
	assert_almost_eq(Barracks.along(game, main_foe, BRANCH), tail_main + 1.0 + offset, EPSILON)
	var feeder := _foe(game, 1, tail_main + 1.0 + game.second_offset)
	assert_almost_eq(Barracks.along(game, feeder, BRANCH), tail_main + 1.0 + offset, EPSILON)
	var early := _foe(game, 1, 1.0)
	assert_eq(Barracks.along(game, early, BRANCH), -1.0, "the feeder before it joins")
	assert_eq(Barracks.along(game, main_foe, 0), main_foe.distance)


# --- what else reads the guard's route


func test_a_mess_tent_beside_the_branch_guards_gives_them_its_aura() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	_build_mess(game, ForkKit.AURA_SOCKET)
	GameTestKit.run(game, [])
	for guard in game.guards:
		assert_gt(guard.regen_bonus, 0.0, "in the aura")
	var far := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	_build_mess(far, ForkKit.MAIN_SOCKET)
	GameTestKit.run(far, [])
	for guard in far.guards:
		assert_eq(guard.regen_bonus, 0.0, "a tent by the main road is far from the branch")


func test_fortified_feast_finds_the_guards_on_the_branch() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	_build_mess(game, ForkKit.AURA_SOCKET)
	var mess := _mess_of(game)
	GameTestKit.run(game, [Command.upgrade(mess.id)])
	GameTestKit.run(game, [Command.upgrade(mess.id)])
	GameTestKit.run(game, [Command.choose_spec(mess.id, "ironRations")])
	GameTestKit.run(game, [Command.activate(mess.id)])
	for guard in game.guards:
		assert_gt(guard.shield_hp, 0.0, "shielded")


func test_fortified_feast_needs_a_guard_on_the_branch_inside_the_aura() -> void:
	var game := ForkKit.game_with_tent(ForkKit.BRANCH_SOCKET)
	# the main road passes this tent, the branch's guards are out of its reach
	_build_mess(game, ForkKit.MAIN_SOCKET)
	var mess := _mess_of(game)
	GameTestKit.run(game, [Command.upgrade(mess.id)])
	GameTestKit.run(game, [Command.upgrade(mess.id)])
	GameTestKit.run(game, [Command.choose_spec(mess.id, "ironRations")])
	GameTestKit.run(game, [Command.activate(mess.id)])
	for guard in game.guards:
		assert_eq(guard.shield_hp, 0.0, "not shielded")
