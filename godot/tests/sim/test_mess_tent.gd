## The Kitchen Mess Tent: an aura that makes nearby guards faster and heal faster.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_the_mess_tent_is_content_with_three_levels_and_no_attack() -> void:
	var def: Dictionary = TOWERS.DEFS.messTent
	assert_eq(def.name, "Kitchen Mess Tent")
	assert_true(def.support)
	assert_eq(def.cost, [100, 100, 160])
	assert_eq(def.range, [2.2, 2.5, 2.8])
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
		orcs.append(GuardKit.foe_before_post(game, "corrugatedOrc", 0.3))
		GuardKit.tick(game, 300)
	# a blow of 4 does 1 against the orc's armor, one a second after the first; with
	# the strongest aura (25 percent faster) about 25 percent more blows land
	var plain: float = 130.0 - orcs[1].hp
	var fed: float = 130.0 - orcs[0].hp
	assert_almost_eq(plain, 7.0, 1.0)
	assert_almost_eq(fed, 9.0, 1.0)
	assert_gt(fed, plain)


func test_two_mess_tents_do_not_stack_and_the_strongest_wins() -> void:
	var game := GuardKit.game_with_both(2)
	var second := GuardKit.socket_near_post(game, 2.1)
	var spare := Vector2i(-1, -1)
	for anchor in game.map.sockets:
		var taken := false
		for tower in game.towers:
			taken = taken or (tower.col == anchor.x and tower.row == anchor.y)
		var centre := game.map.socket_centre(anchor)
		var at := game.routes[0].position_at(GuardKit.post(game))
		if not taken and centre.distance_to(Vector2(at.x, at.y)) <= 2.6:
			spare = anchor
			break
	if spare == Vector2i(-1, -1):
		pending("no second socket near the post on this seed")
		return
	GameTestKit.run(game, [Command.build("messTent", spare.x, spare.y)])
	GuardKit.tick(game, 1)
	assert_almost_eq(game.guards[0].speed_bonus, 0.25, 1e-12, "the level 3 aura, not the sum")
	assert_ne(second, Vector2i(-1, -1))


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
