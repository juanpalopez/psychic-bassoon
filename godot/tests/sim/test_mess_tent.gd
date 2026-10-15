## The Kitchen Mess Tent: an aura that makes nearby guards faster and heal faster.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_the_mess_tent_is_content_with_three_levels_and_no_attack() -> void:
	var def: Dictionary = TOWERS.DEFS.messTent
	assert_eq(def.name, "Kitchen Mess Tent")
	assert_true(def.support)
	assert_eq(def.cost, [100, 100, 160])
	assert_eq(def.range, [3.0, 3.3, 3.6])
	assert_eq(def.guard_speed_bonus, [0.12, 0.18, 0.25])
	assert_eq(def.guard_regen_bonus, [2.0, 3.0, 4.0])
	assert_false(def.has("damage"))
	assert_true(TOWERS.TOWER_IDS.has("messTent"))


func test_a_game_with_both_tents_exists_for_the_tests() -> void:
	assert_not_null(GuardKit.game_with_both(), "some seed has a socket by the guards' post")


func test_guards_inside_the_aura_get_its_bonus_and_others_do_not() -> void:
	var game := GuardKit.game_with_both(0)
	GuardKit.tick(game, 1)
	for guard in game.guards:
		assert_almost_eq(guard.speed_bonus, 0.12, 1e-12)
		assert_almost_eq(guard.regen_bonus, 2.0, 1e-12)
	var lone := GuardKit.game_with_tent()
	GuardKit.tick(lone, 1)
	assert_eq(lone.guards[0].speed_bonus, 0.0)
	assert_eq(lone.guards[0].regen_bonus, 0.0)


func test_a_higher_level_gives_a_bigger_bonus() -> void:
	var game := GuardKit.game_with_both(2)
	GuardKit.tick(game, 1)
	assert_almost_eq(game.guards[0].speed_bonus, 0.25, 1e-12)
	assert_almost_eq(game.guards[0].regen_bonus, 4.0, 1e-12)


func test_the_aura_makes_a_hurt_guard_heal_faster() -> void:
	var with_tent := GuardKit.game_with_both(0)
	var without := GuardKit.game_with_tent(with_tent.seed)
	for game in [with_tent, without]:
		game.guards[0].hp = 10.0
		GuardKit.tick(game, 60)
	# 2 seconds at 1 hp a second, and at 1 + 2 hp a second
	assert_almost_eq(without.guards[0].hp, 12.0, 0.2)
	assert_almost_eq(with_tent.guards[0].hp, 16.0, 0.2)


func test_the_aura_makes_a_guard_strike_more_often() -> void:
	var with_tent := GuardKit.game_with_both(2)
	var without := GuardKit.game_with_tent(with_tent.seed)
	var orcs := []
	for game in [with_tent, without]:
		game.guards[1].alive = false
		game.guards[1].respawn_timer = 1000.0
		# a wave 10 orc has 785 hp, so it is still there after ten seconds
		orcs.append(GuardKit.foe_before_post(game, "corrugatedOrc", 0.3, 10))
		GuardKit.tick(game, 300)
	# a blow of 16 does 10 against the orc's armor, one a second; with the strongest
	# aura (25 percent faster) about 25 percent more blows land
	var plain: float = 785.0 - orcs[1].hp
	var fed: float = 785.0 - orcs[0].hp
	assert_almost_eq(plain, 100.0, 15.0)
	assert_almost_eq(fed, 125.0, 15.0)
	assert_gt(fed, plain + 10.0)


func _level0_within(sockets: Array, reach: float, count: int) -> Array:
	var found := []
	for entry in sockets:
		if entry[2] == 0 and entry[1] <= reach - 0.05:
			found.append(entry[0])
	return found.slice(0, count) if found.size() >= count else []


func test_two_mess_tents_do_not_stack_and_the_strongest_wins_in_either_order() -> void:
	var reach: float = TOWERS.DEFS.messTent.range[0]
	var game := GuardKit.find_game(
		func(sockets: Array) -> bool: return not _level0_within(sockets, reach, 2).is_empty()
	)
	assert_not_null(game, "some seed has two plain sockets in a level 1 aura's reach")
	var pair := _level0_within(GuardKit.sockets_by_distance(game), reach, 2)
	var top := TOWERS.DEFS.messTent
	# the strong tent on the nearer socket and built first, the weak one last ...
	var first := GuardKit.game_with_tent(game.seed)
	GameTestKit.run(first, [Command.build("messTent", pair[0].x, pair[0].y)])
	GameTestKit.run(first, [Command.upgrade(first.towers[1].id)])
	GameTestKit.run(first, [Command.upgrade(first.towers[1].id)])
	GameTestKit.run(first, [Command.build("messTent", pair[1].x, pair[1].y)])
	# ... and the other way round: the weak tent first and nearer, the strong one last
	var second := GuardKit.game_with_tent(game.seed)
	GameTestKit.run(second, [Command.build("messTent", pair[0].x, pair[0].y)])
	GameTestKit.run(second, [Command.build("messTent", pair[1].x, pair[1].y)])
	GameTestKit.run(second, [Command.upgrade(second.towers[2].id)])
	GameTestKit.run(second, [Command.upgrade(second.towers[2].id)])
	for built in [first, second]:
		GuardKit.tick(built, 1)
		assert_almost_eq(built.guards[0].speed_bonus, float(top.guard_speed_bonus[2]), 1e-12)
		assert_almost_eq(built.guards[0].regen_bonus, float(top.guard_regen_bonus[2]), 1e-12)


func test_a_mess_tent_out_of_reach_gives_the_guards_nothing() -> void:
	var farthest: float = TOWERS.DEFS.messTent.range[2] * 1.15 + 0.1
	var game := GuardKit.find_game(
		func(sockets: Array) -> bool:
			for entry in sockets:
				if entry[2] == 0 and entry[1] > farthest and entry[1] < farthest + 0.5:
					return true
			return false
	)
	assert_not_null(game)
	var far := Vector2i(-1, -1)
	for entry in GuardKit.sockets_by_distance(game):
		# nearest first: the socket just outside the largest reach there can be
		if entry[2] == 0 and entry[1] > farthest and entry[1] < farthest + 0.5:
			far = entry[0]
			break
	GameTestKit.run(game, [Command.build("messTent", far.x, far.y)])
	GameTestKit.run(game, [Command.upgrade(game.towers[1].id)])
	GameTestKit.run(game, [Command.upgrade(game.towers[1].id)])
	GuardKit.tick(game, 1)
	assert_eq(game.guards[0].speed_bonus, 0.0, "even a level 3 tent too far away")
	assert_eq(game.guards[0].regen_bonus, 0.0)


func test_a_high_socket_reaches_further_like_a_towers_range_does() -> void:
	var reach: float = TOWERS.DEFS.messTent.range[0]
	# the aura is checked against each guard's own post, so measure to the first guard's
	var spot := Vector2i(-1, -1)
	var game: GameState = null
	for map_seed in range(1, 400):
		var candidate := GuardKit.game_with_tent(map_seed)
		var at := candidate.routes[0].position_at(candidate.guards[0].post)
		for anchor in candidate.map.sockets:
			if anchor == Vector2i(candidate.towers[0].col, candidate.towers[0].row):
				continue
			var gap := candidate.map.socket_centre(anchor).distance_to(Vector2(at.x, at.y))
			if (
				candidate.map.elevation_at(anchor) == 2
				and gap > reach + 0.02
				and gap < reach * 1.15 - 0.02
			):
				spot = anchor
				game = candidate
		if game != null:
			break
	assert_not_null(game, "some seed has a level 2 socket just beyond a level 1 aura")
	GameTestKit.run(game, [Command.build("messTent", spot.x, spot.y)])
	GuardKit.tick(game, 1)
	assert_gt(
		game.guards[0].speed_bonus, 0.0, "the 15 percent of a level 2 socket reaches the post"
	)


func test_the_same_seed_and_commands_replay_the_same_with_both_tents() -> void:
	var a := GameTestKit.snapshot(_play_both())
	var b := GameTestKit.snapshot(_play_both())
	assert_eq(a, b)


func _play_both() -> GameState:
	var game := GuardKit.game_with_both(1)
	GameTestKit.run(game, [Command.launch_wave()])
	GuardKit.tick(game, 900)
	return game


func test_the_regen_and_speed_bonuses_both_rise_with_the_level() -> void:
	var def: Dictionary = TOWERS.DEFS.messTent
	for level in 2:
		assert_gt(def.guard_speed_bonus[level + 1], def.guard_speed_bonus[level])
		assert_gt(def.guard_regen_bonus[level + 1], def.guard_regen_bonus[level])


func test_selling_the_mess_tent_ends_the_bonus() -> void:
	var game := GuardKit.game_with_both(0)
	GuardKit.tick(game, 1)
	assert_gt(game.guards[0].speed_bonus, 0.0)
	GameTestKit.run(game, [Command.sell(game.towers[1].id)])
	GuardKit.tick(game, 1)
	assert_eq(game.guards[0].speed_bonus, 0.0)
	assert_eq(game.guards[0].regen_bonus, 0.0)


func test_a_mess_tent_never_shoots_and_draws_no_random_numbers() -> void:
	var game := GuardKit.game_with_both(0)
	GuardKit.foe_before_post(game, "scrapGoblin", 0.3)
	var rng_state := game.rng.state
	var shots := 0
	for i in 200:
		Game.tick(game)
		shots += GuardKit.events_of(game, GameEvent.Kind.TOWER_FIRED).size()
	assert_eq(shots, 0)
	assert_eq(game.rng.state, rng_state)
