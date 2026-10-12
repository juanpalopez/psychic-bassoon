## Damage types: physical is cut by armor, magic by resist, true by neither. A
## hit never drops below a share of its damage, and a kill pays its reward once.
extends GutTest

const FOES := preload("res://content/foes.gd")
const RULES := preload("res://content/game_rules.gd")


func _game_with(type: String, wave: int = 1) -> Array:
	var game := Game.create(1)
	var foe := FoeSpawner.spawn(game, type, wave, 0)
	game.events = []
	return [game, foe]


func test_every_foe_has_a_resist_in_its_content_and_on_the_foe() -> void:
	for id in FOES.FOE_IDS:
		assert_true(FOES.DEFS[id].has("resist"), id)
		var made := _game_with(id)
		assert_eq((made[1] as Foe).resist, int(FOES.DEFS[id].resist), id)
		assert_eq((made[1] as Foe).resist, 0, "no foe resists magic yet")


func test_the_ground_foes_start_with_the_hp_and_armor_the_tests_below_rely_on() -> void:
	var goblin: Foe = _game_with("scrapGoblin")[1]
	var orc: Foe = _game_with("corrugatedOrc")[1]
	assert_eq([goblin.hp, goblin.armor, goblin.reward], [20.0, 0, 4])
	assert_eq([orc.hp, orc.armor], [130.0, 4])


func test_physical_damage_is_cut_by_armor() -> void:
	var made := _game_with("corrugatedOrc")
	var dealt := Damage.apply(made[0], made[1], 10.0, Damage.Kind.PHYSICAL)
	assert_eq(dealt, 6.0)
	assert_eq((made[1] as Foe).hp, 124.0)


func test_physical_damage_against_no_armor_is_whole() -> void:
	var made := _game_with("scrapGoblin")
	assert_eq(Damage.apply(made[0], made[1], 5.0, Damage.Kind.PHYSICAL), 5.0)
	assert_eq((made[1] as Foe).hp, 15.0)


func test_armor_never_cuts_a_hit_below_a_quarter_of_it() -> void:
	assert_eq(RULES.MIN_DAMAGE_FRACTION, 0.25)
	var made := _game_with("corrugatedOrc")
	# 4 damage against 4 armor would be 0: the floor is a quarter of 4
	assert_eq(Damage.apply(made[0], made[1], 4.0, Damage.Kind.PHYSICAL), 1.0)
	# 2 damage against 4 armor: the floor, 0.5
	assert_eq(Damage.apply(made[0], made[1], 2.0, Damage.Kind.PHYSICAL), 0.5)


func test_magic_damage_ignores_armor() -> void:
	var made := _game_with("corrugatedOrc")
	assert_eq(Damage.apply(made[0], made[1], 10.0, Damage.Kind.MAGIC), 10.0)
	assert_eq((made[1] as Foe).hp, 120.0)


func test_magic_damage_is_cut_by_resist_with_the_same_floor() -> void:
	var made := _game_with("corrugatedOrc")
	var foe: Foe = made[1]
	foe.resist = 3
	assert_eq(Damage.apply(made[0], foe, 10.0, Damage.Kind.MAGIC), 7.0)
	foe.resist = 20
	assert_eq(Damage.apply(made[0], foe, 10.0, Damage.Kind.MAGIC), 2.5)


func test_physical_damage_ignores_resist() -> void:
	var made := _game_with("scrapGoblin")
	var foe: Foe = made[1]
	foe.resist = 5
	assert_eq(Damage.apply(made[0], foe, 4.0, Damage.Kind.PHYSICAL), 4.0)


func test_true_damage_ignores_armor_and_resist() -> void:
	var made := _game_with("corrugatedOrc")
	var foe: Foe = made[1]
	foe.resist = 3
	assert_eq(Damage.apply(made[0], foe, 10.0, Damage.Kind.TRUE), 10.0)
	assert_eq(foe.hp, 120.0)


func test_the_orcs_armor_makes_magic_the_better_counter() -> void:
	var physical := _game_with("corrugatedOrc")
	var magic := _game_with("corrugatedOrc")
	var by_spool := Damage.apply(physical[0], physical[1], 9.0, Damage.Kind.PHYSICAL)
	var by_prism := Damage.apply(magic[0], magic[1], 9.0, Damage.Kind.MAGIC)
	assert_eq(by_spool, 5.0)
	assert_eq(by_prism, 9.0)


func test_a_kill_pays_the_reward_marks_the_foe_fallen_and_reports_it() -> void:
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	var foe: Foe = made[1]
	var before := game.buttons
	var dealt := Damage.apply(game, foe, 25.0, Damage.Kind.PHYSICAL)
	assert_eq(dealt, 20.0, "only the hp that was left")
	assert_false(foe.alive)
	assert_eq(game.buttons, before + 4)
	assert_eq(game.events.size(), 1)
	var event := game.events[0]
	assert_eq(event.kind, GameEvent.Kind.FOE_KILLED)
	assert_eq(event.foe_id, foe.id)
	assert_eq(event.foe_type, "scrapGoblin")
	assert_eq(event.reward, 4)
	assert_eq([event.x, event.y], [foe.x, foe.y])


func test_exactly_the_foes_hp_is_a_kill() -> void:
	var made := _game_with("scrapGoblin")
	Damage.apply(made[0], made[1], 20.0, Damage.Kind.TRUE)
	assert_false((made[1] as Foe).alive)


func test_a_foe_that_survives_pays_nothing_and_reports_nothing() -> void:
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	var before := game.buttons
	Damage.apply(game, made[1], 5.0, Damage.Kind.PHYSICAL)
	assert_true((made[1] as Foe).alive)
	assert_eq(game.buttons, before)
	assert_eq(game.events.size(), 0)


func test_a_fallen_foe_takes_no_more_damage_and_pays_once() -> void:
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	Damage.apply(game, made[1], 99.0, Damage.Kind.PHYSICAL)
	var buttons := game.buttons
	var again := Damage.apply(game, made[1], 99.0, Damage.Kind.PHYSICAL)
	assert_eq(again, 0.0)
	assert_eq(game.buttons, buttons, "no second reward")
	assert_eq(game.events.size(), 1, "no second event")


func test_a_fallen_foe_leaves_the_game_on_the_next_tick() -> void:
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	Damage.apply(game, made[1], 99.0, Damage.Kind.PHYSICAL)
	Game.tick(game)
	assert_eq(game.foes.size(), 0)


func test_damage_draws_no_random_numbers() -> void:
	var made := _game_with("corrugatedOrc")
	var game: GameState = made[0]
	var wave_stream := game.rng.state
	var route_stream := game.route_rng.state
	for kind in [Damage.Kind.PHYSICAL, Damage.Kind.MAGIC, Damage.Kind.TRUE]:
		Damage.apply(game, made[1], 3.0, kind)
	assert_eq(game.rng.state, wave_stream)
	assert_eq(game.route_rng.state, route_stream)


func test_a_non_positive_hit_does_nothing() -> void:
	var made := _game_with("scrapGoblin")
	assert_eq(Damage.apply(made[0], made[1], 0.0, Damage.Kind.PHYSICAL), 0.0)
	assert_eq(Damage.apply(made[0], made[1], -5.0, Damage.Kind.TRUE), 0.0)
	assert_eq((made[1] as Foe).hp, 20.0, "a negative hit never heals")


func test_a_foe_that_leaked_this_tick_pays_no_reward_for_a_late_hit() -> void:
	# a leaked foe is not alive but still has its hp
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	var foe: Foe = made[1]
	foe.alive = false
	var buttons := game.buttons
	assert_eq(Damage.apply(game, foe, 99.0, Damage.Kind.TRUE), 0.0)
	assert_eq(game.buttons, buttons)
	assert_eq(game.events.size(), 0)
	assert_eq(foe.hp, 20.0)


func test_a_foe_killed_one_step_from_the_end_does_not_also_leak() -> void:
	var made := _game_with("scrapGoblin")
	var game: GameState = made[0]
	var foe: Foe = made[1]
	foe.distance = game.routes[foe.route].total - 0.0001
	var health := game.heartstone_health
	var buttons := game.buttons
	Damage.apply(game, foe, 99.0, Damage.Kind.TRUE)
	Game.tick(game)
	assert_eq(game.heartstone_health, health, "no health lost for a dead foe")
	assert_eq(game.buttons, buttons + foe.reward, "paid once")
	for event in game.events:
		assert_ne(event.kind, GameEvent.Kind.FOE_LEAKED)


func test_a_hit_that_is_not_a_number_does_nothing() -> void:
	var made := _game_with("scrapGoblin")
	assert_eq(Damage.apply(made[0], made[1], NAN, Damage.Kind.TRUE), 0.0)
	assert_eq((made[1] as Foe).hp, 20.0)
	assert_true((made[1] as Foe).alive)
	# and a later real hit still works
	assert_eq(Damage.apply(made[0], made[1], 5.0, Damage.Kind.TRUE), 5.0)
