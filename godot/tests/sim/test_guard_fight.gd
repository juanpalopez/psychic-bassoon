## Guards block one foe each, fight it, and come back when they fall.
extends GutTest


func test_a_foe_reaching_a_guard_stops_and_the_engagement_is_reported() -> void:
	var game := GuardKit.game_with_tent()
	var goblin := GuardKit.foe_before_post(game, "scrapGoblin", 0.5)
	var engaged := 0
	var at := -1.0
	for i in 60:
		Game.tick(game)
		engaged += GuardKit.events_of(game, GameEvent.Kind.FOE_ENGAGED).size()
		if goblin.engaged_guard_id != -1 and at < 0.0:
			at = goblin.distance
	assert_ne(goblin.engaged_guard_id, -1)
	assert_eq(engaged, 1)
	assert_eq(goblin.distance, at, "a held foe does not walk")


func test_each_guard_holds_one_foe_and_the_third_walks_past() -> void:
	var game := GuardKit.game_with_tent()
	var held := [
		GuardKit.foe_before_post(game, "corrugatedOrc", 0.4),
		GuardKit.foe_before_post(game, "corrugatedOrc", 0.45),
	]
	var third := GuardKit.foe_before_post(game, "corrugatedOrc", 0.5)
	GuardKit.tick(game, 45)
	var guards_used := {}
	for foe in held:
		assert_ne(foe.engaged_guard_id, -1)
		guards_used[foe.engaged_guard_id] = true
	assert_eq(guards_used.size(), 2, "one guard each")
	assert_eq(third.engaged_guard_id, -1)
	assert_gt(third.distance, GuardKit.post(game), "the third went past")


func test_a_goblin_loses_to_a_guard_and_pays_its_reward() -> void:
	var game := GuardKit.game_with_tent()
	var goblin := GuardKit.foe_before_post(game, "scrapGoblin", 0.3)
	var before := game.buttons
	GuardKit.tick(game, 150)
	assert_false(goblin.alive)
	assert_eq(game.buttons, before + 4)
	for guard in game.guards:
		assert_eq(guard.foe_id, -1, "the guard is free again")
	var hurt: Guard = game.guards[0] if game.guards[0].hp < game.guards[1].hp else game.guards[1]
	assert_gt(hurt.hp, 60.0 - 24.0, "a goblin hits for 3 about every 0.8 s")
	assert_lt(hurt.hp, 60.0, "and did hit")


func test_an_orc_shrugs_off_a_guard_and_beats_it_in_the_end() -> void:
	var game := GuardKit.game_with_tent()
	# the second guard is down, so the first one stands alone
	game.guards[1].alive = false
	game.guards[1].respawn_timer = 1000.0
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	GuardKit.tick(game, 150)
	# a blow of 4 against armor 6 does the quarter that always gets through: 1 a second
	assert_almost_eq(orc.hp, 130.0 - 5.0, 2.0)
	var fell := false
	for i in 250:
		Game.tick(game)
		if not GuardKit.events_of(game, GameEvent.Kind.GUARD_FELL).is_empty():
			fell = true
			break
	assert_true(fell, "14 damage every 1.6 s wears 60 hp down in about 7 s")
	assert_eq(orc.engaged_guard_id, -1, "the orc walks on")
	assert_true(orc.alive)


func test_a_fallen_guard_comes_back_after_its_respawn_time() -> void:
	var game := GuardKit.game_with_tent()
	var guard: Guard = game.guards[0]
	guard.hp = 0.5
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	GuardKit.tick(game, 60)
	assert_false(guard.alive)
	var raised := false
	for i in 12 * 30:
		Game.tick(game)
		if guard.alive:
			raised = true
			break
	assert_true(raised, "back after 12 s")
	assert_eq(guard.hp, guard.max_hp)
	assert_true(orc.alive)


func test_a_guard_out_of_a_fight_regains_health() -> void:
	var game := GuardKit.game_with_tent()
	game.guards[0].hp = 30.0
	GuardKit.tick(game, 90)
	assert_almost_eq(game.guards[0].hp, 33.0, 0.2)
	GuardKit.tick(game, 3000)
	assert_eq(game.guards[0].hp, 60.0, "never above the maximum")


func test_the_golem_is_not_held() -> void:
	var game := GuardKit.game_with_tent()
	var golem := GuardKit.foe_before_post(game, "cardboardGolem", 0.6, 10)
	GuardKit.tick(game, 90)
	assert_eq(golem.engaged_guard_id, -1)
	assert_gt(golem.distance, GuardKit.post(game))


func test_a_foe_already_past_the_post_is_left_alone() -> void:
	var game := GuardKit.game_with_tent()
	var goblin := GuardKit.foe_before_post(game, "scrapGoblin", -0.8)
	GuardKit.tick(game, 10)
	assert_eq(goblin.engaged_guard_id, -1)


func test_towers_keep_shooting_a_held_foe() -> void:
	var game := GuardKit.game_with_tent()
	var anchor := _socket_nearest_the_post(game)
	GameTestKit.run(game, [Command.build("spoolGuard", anchor.x, anchor.y)])
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	var shots := 0
	for i in 120:
		Game.tick(game)
		shots += GuardKit.events_of(game, GameEvent.Kind.TOWER_FIRED).size()
	assert_gt(shots, 0, "the Spool Guard has the held orc in reach")
	assert_ne(orc.hp, 130.0)


func test_fights_draw_no_random_numbers() -> void:
	var game := GuardKit.game_with_tent()
	GuardKit.foe_before_post(game, "scrapGoblin", 0.3)
	GuardKit.foe_before_post(game, "corrugatedOrc", 0.4)
	var rng_state := game.rng.state
	var route_state := game.route_rng.state
	GuardKit.tick(game, 300)
	assert_eq(game.rng.state, rng_state)
	assert_eq(game.route_rng.state, route_state)


func test_the_same_seed_and_commands_replay_the_same_with_a_tent() -> void:
	var a := _play()
	var b := _play()
	assert_eq(a, b)


func _socket_nearest_the_post(game: GameState) -> Vector2i:
	var at := game.routes[0].position_at(GuardKit.post(game))
	var best := game.map.sockets[1]
	var best_distance := INF
	for i in range(1, game.map.sockets.size()):
		var centre := game.map.socket_centre(game.map.sockets[i])
		var distance := centre.distance_to(Vector2(at.x, at.y))
		if distance < best_distance:
			best_distance = distance
			best = game.map.sockets[i]
	assert_lt(best_distance, 2.3, "a socket within a level 1 Spool Guard's reach of the post")
	return best


func _play() -> Dictionary:
	var game := GuardKit.game_with_tent(3)
	var anchor := game.map.sockets[1]
	GameTestKit.run(
		game, [Command.build("thimbleMortar", anchor.x, anchor.y), Command.launch_wave()]
	)
	GuardKit.tick(game, 900)
	return GameTestKit.snapshot(game)
