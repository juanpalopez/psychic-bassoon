## Guards block one foe each, fight it, and come back when they fall.
extends GutTest


func test_a_foe_reaching_a_guard_stops_and_the_engagement_is_reported() -> void:
	var game := GuardKit.game_with_tent()
	var goblin := GuardKit.foe_before_post(game, "scrapGoblin", 0.5)
	var engaged := 0
	var at := -1.0
	var held_ticks := 0
	for i in 20:
		Game.tick(game)
		engaged += GuardKit.events_of(game, GameEvent.Kind.FOE_ENGAGED).size()
		if goblin.engaged_guard_id != -1:
			held_ticks += 1
			if at < 0.0:
				at = goblin.distance
			assert_eq(goblin.distance, at, "a held foe does not walk")
	assert_gt(held_ticks, 5, "the goblin is held for a while (a guard needs two blows to kill it)")
	assert_eq(engaged, 1)


func test_a_foe_far_from_the_post_is_not_held_but_one_at_its_body_is() -> void:
	# the first guard stands 0.25 before the middle of the post, and its stop is
	# 0.2 + 0.24 = 0.44 further back: 0.69 before the middle; one tick walks 0.07
	var game := GuardKit.game_with_tent()
	var far := GuardKit.foe_before_post(game, "scrapGoblin", 0.9)
	GuardKit.tick(game, 1)
	assert_eq(far.engaged_guard_id, -1, "0.83 before the middle is out of reach")
	var other := GuardKit.game_with_tent()
	var near := GuardKit.foe_before_post(other, "scrapGoblin", 0.6)
	GuardKit.tick(other, 1)
	assert_ne(near.engaged_guard_id, -1, "0.53 before it is held")
	assert_gte(near.distance, GuardKit.post(other) - 0.69)


func test_a_guards_armor_cuts_the_foes_blow() -> void:
	var game := GuardKit.game_with_tent()
	GameTestKit.run(game, [Command.upgrade(GuardKit.tent(game).id)])
	GameTestKit.run(game, [Command.upgrade(GuardKit.tent(game).id)])
	assert_eq(game.guards[0].armor, 4)
	game.guards[1].alive = false
	game.guards[1].respawn_timer = 1000.0
	game.guards[0].hp = game.guards[0].max_hp
	GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	GuardKit.tick(game, 3)
	# the orc's first blow is 14, less the guard's 4 armor: 10 (320 to 310), and
	# nothing has regenerated in a fight
	assert_eq(game.guards[0].hp, 310.0)


func test_a_slow_on_a_held_foe_keeps_running_out() -> void:
	var game := GuardKit.game_with_tent()
	game.guards[1].alive = false
	game.guards[1].respawn_timer = 1000.0
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	Status.apply_slow(orc, 0.5, 0.5)
	GuardKit.tick(game, 3)
	assert_ne(orc.engaged_guard_id, -1)
	GuardKit.tick(game, 30)
	assert_eq(orc.slow_timer, 0.0, "the slow ran out while the orc was held")
	assert_eq(orc.slow, 0.0)


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
	assert_gt(hurt.hp, 120.0 - 24.0, "a goblin hits for 3 about every 0.8 s")
	assert_lt(hurt.hp, 120.0, "and did hit")


func test_an_orc_is_held_and_worn_down_and_a_later_orc_beats_the_guard() -> void:
	var game := GuardKit.game_with_tent()
	# the second guard is down, so the first one stands alone
	game.guards[1].alive = false
	game.guards[1].respawn_timer = 1000.0
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	GuardKit.tick(game, 150)
	# a blow of 16 against armor 6 does 10, about one a second: an early orc is worn down
	assert_almost_eq(orc.hp, 130.0 - 50.0, 12.0)
	var strong := GuardKit.game_with_tent()
	strong.guards[1].alive = false
	strong.guards[1].respawn_timer = 1000.0
	var late := GuardKit.foe_before_post(strong, "corrugatedOrc", 0.3, 10)
	var fell := false
	for i in 600:
		Game.tick(strong)
		if not GuardKit.events_of(strong, GameEvent.Kind.GUARD_FELL).is_empty():
			fell = true
			break
	# a wave 10 orc hits for 17.78 every 1.6 s (11 a second) and has 785 hp
	assert_true(fell, "it wears 120 hp down in about 11 s")
	assert_eq(late.engaged_guard_id, -1, "the orc walks on")
	assert_true(late.alive)


func test_a_fallen_guard_comes_back_after_exactly_its_respawn_time() -> void:
	var game := GuardKit.game_with_tent()
	var guard: Guard = game.guards[0]
	guard.hp = 0.5
	# the other guard is down, so the orc walks on once this one falls
	game.guards[1].alive = false
	game.guards[1].respawn_timer = 1000.0
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	var fell := -1
	var raised := -1
	for i in 16 * 30:
		Game.tick(game)
		if fell < 0 and not GuardKit.events_of(game, GameEvent.Kind.GUARD_FELL).is_empty():
			fell = game.tick_count
		elif fell >= 0 and raised < 0:
			for event in GuardKit.events_of(game, GameEvent.Kind.GUARD_RAISED):
				if event.guard_id == guard.id:
					raised = game.tick_count
	assert_gt(fell, 0, "the guard fell")
	assert_gt(raised, fell, "and was raised again")
	assert_almost_eq(float(raised - fell), 6.0 * 30.0, 1.0, "after 6 s, a level 1 tent")
	assert_eq(guard.hp, guard.max_hp)
	assert_true(orc.alive)


func test_a_guard_out_of_a_fight_regains_health() -> void:
	var game := GuardKit.game_with_tent()
	game.guards[0].hp = 30.0
	GuardKit.tick(game, 90)
	assert_almost_eq(game.guards[0].hp, 33.0, 0.2)
	GuardKit.tick(game, 3000)
	assert_eq(game.guards[0].hp, 120.0, "never above the maximum")


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
