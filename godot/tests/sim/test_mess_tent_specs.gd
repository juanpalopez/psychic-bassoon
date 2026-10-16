## Tier 4 for the Kitchen Mess Tent: Iron Rations (Fortified Feast, Hardtack Toughness) and
## Gourmet Frenzy (Boiling Broth Splash, Sugar Rush).
extends GutTest

const SPECS := preload("res://content/specs.gd")
const TOWERS := preload("res://content/towers.gd")

const RATIONS := "ironRations"
const FRENZY := "gourmetFrenzy"


## A game with a Guard Tent and a Mess Tent at the top level near its guards, spec chosen.
func _game_with(spec: String) -> GameState:
	var game := GuardKit.game_with_both(0)
	assert_not_null(game, "some seed has a socket by the guards' post")
	var mess := mess_of(game)
	game.buttons = 100000
	Game.submit(game, Command.upgrade(mess.id))
	Game.submit(game, Command.upgrade(mess.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(mess.id, spec))
	Game.tick(game)
	return game


func mess_of(game: GameState) -> Tower:
	for tower in game.towers:
		if tower.type == "messTent":
			return tower
	return null


func _rejected(game: GameState) -> Array:
	var reasons := []
	for event in GuardKit.events_of(game, GameEvent.Kind.COMMAND_REJECTED):
		reasons.append(event.reason)
	return reasons


func test_the_content_gives_the_mess_tent_two_specs() -> void:
	var specs: Array = SPECS.for_tower("messTent")
	assert_eq(specs.size(), 2)
	assert_eq(specs[0].id, RATIONS)
	assert_eq(specs[1].id, FRENZY)
	assert_eq(specs[0].passive.kind, "hardtack")
	assert_eq(specs[0].active.kind, "fortified_feast")
	assert_eq(specs[1].passive.kind, "sugar_rush")
	assert_eq(specs[1].active.kind, "boiling_broth")


# --- Iron Rations ---


func test_hardtack_raises_the_max_hp_of_guards_in_the_aura_and_gives_it_back_clamped() -> void:
	var game := _game_with(RATIONS)
	var bonus: float = SPECS.find("messTent", RATIONS).passive.bonus
	var base := float(TOWERS.DEFS.guardTent.guard_hp[0])
	GuardKit.tick(game, 1)
	for guard in game.guards:
		assert_almost_eq(guard.max_hp, base * (1.0 + bonus), 1e-9)
		assert_almost_eq(guard.hp, guard.max_hp, 1e-9, "the added hp comes with it")
	# the Mess Tent is sold: the max goes back, and a full guard is clamped, never healed
	Game.submit(game, Command.sell(mess_of(game).id))
	GuardKit.tick(game, 2)
	for guard in game.guards:
		assert_almost_eq(guard.max_hp, base, 1e-9)
		assert_almost_eq(guard.hp, base, 1e-9)


func test_hardtack_does_not_stack_between_two_mess_tents() -> void:
	var game := _game_with(RATIONS)
	var bonus: float = SPECS.find("messTent", RATIONS).passive.bonus
	var first := mess_of(game)
	var twin := Tower.new()
	twin.id = 950
	twin.type = "messTent"
	twin.level = 2
	twin.spec = RATIONS
	twin.col = first.col
	twin.row = first.row
	game.towers.append(twin)
	var base := float(TOWERS.DEFS.guardTent.guard_hp[0])
	GuardKit.tick(game, 1)
	assert_almost_eq(game.guards[0].max_hp, base * (1.0 + bonus), 1e-9)


func test_fortified_feast_shields_the_guards_in_the_aura_and_the_shield_soaks_blows_first() -> void:
	var game := _game_with(RATIONS)
	var active: Dictionary = SPECS.find("messTent", RATIONS).active
	GuardKit.tick(game, 1)
	Game.submit(game, Command.activate(mess_of(game).id))
	Game.tick(game)
	for guard in game.guards:
		assert_gt(guard.shield_hp, 0.0)
	var guard: Guard = game.guards[0]
	var shield := guard.shield_hp
	var hp := guard.hp
	# a blow smaller than the shield only wears the shield
	Specs.guard_absorb(guard, 10.0)
	assert_eq(guard.shield_hp, shield - 10.0)
	assert_eq(guard.hp, hp)
	# a blow bigger than what is left spills over to hp
	var spill := Specs.guard_absorb(guard, guard.shield_hp + 7.0)
	assert_almost_eq(spill, 7.0, 1e-9)
	assert_eq(guard.shield_hp, 0.0)
	# the shield of the others goes after its seconds
	GuardKit.tick(game, int(float(active.seconds) * 30.0) + 3)
	for other in game.guards:
		assert_eq(other.shield_hp, 0.0)
		assert_eq(other.shield_timer, 0.0)


func test_fortified_feast_needs_a_guard_in_the_aura() -> void:
	var game := _game_with(RATIONS)
	for guard in game.guards:
		guard.alive = false
	Game.submit(game, Command.activate(mess_of(game).id))
	Game.tick(game)
	assert_eq(_rejected(game), [GameEvent.RejectReason.NO_TARGET])
	assert_eq(mess_of(game).ability_cooldown, 0.0)


# --- Gourmet Frenzy ---


func test_sugar_rush_adds_to_the_guards_attack_speed_once() -> void:
	var game := _game_with(FRENZY)
	var rush: float = SPECS.find("messTent", FRENZY).passive.bonus
	var aura: float = TOWERS.DEFS.messTent.guard_speed_bonus[2]
	GuardKit.tick(game, 1)
	for guard in game.guards:
		assert_almost_eq(guard.speed_bonus, aura + rush, 1e-9)
	var lone := GuardKit.game_with_tent(game.seed)
	GuardKit.tick(lone, 1)
	assert_eq(lone.guards[0].speed_bonus, 0.0, "no Mess Tent, no rush")


func test_boiling_broth_burns_and_slows_the_foes_around_the_target_but_not_flyers() -> void:
	var game := _game_with(FRENZY)
	var active: Dictionary = SPECS.find("messTent", FRENZY).active
	var lead := GuardKit.foe_before_post(game, "corrugatedOrc", 0.2)
	var rear := GuardKit.foe_before_post(game, "corrugatedOrc", 0.6)
	for foe in [lead, rear]:
		foe.hp = 1.0e9
		foe.max_hp = 1.0e9
		foe.engaged_guard_id = -1
	for guard in game.guards:
		guard.cooldown = 1000.0
		guard.alive = false
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.hp = 1.0e9
	moth.max_hp = 1.0e9
	moth.x = lead.x
	moth.y = lead.y
	var before := lead.hp
	Game.submit(game, Command.activate(mess_of(game).id))
	Game.tick(game)
	assert_gt(before - lead.hp, 0.0, "scalding stew hurts")
	assert_eq(lead.slow, float(active.slow))
	assert_eq(rear.slow, float(active.slow), "the whole area")
	assert_eq(moth.hp, moth.max_hp)
	assert_eq(moth.slow, 0.0)


func test_boiling_broth_needs_a_foe_in_reach() -> void:
	var game := _game_with(FRENZY)
	Game.submit(game, Command.activate(mess_of(game).id))
	Game.tick(game)
	assert_eq(_rejected(game), [GameEvent.RejectReason.NO_TARGET])


func test_the_same_commands_give_the_same_game_for_both_mess_specs() -> void:
	for spec in [RATIONS, FRENZY]:
		var snapshots := []
		for run in 2:
			var game := _game_with(spec)
			GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
			GuardKit.foe_before_post(game, "corrugatedOrc", 0.5)
			Game.submit(game, Command.activate(mess_of(game).id))
			GuardKit.tick(game, 400)
			snapshots.append(GameTestKit.snapshot(game))
		assert_eq(snapshots[0], snapshots[1], spec)


func test_the_mess_scenarios_match_their_golden() -> void:
	var file := FileAccess.open(SpecScenario.MESS_GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	var played := {
		"ironRations": SpecScenario.play_mess("ironRations"),
		"gourmetFrenzy": SpecScenario.play_mess("gourmetFrenzy"),
	}
	# JSON turns whole numbers into floats, so compare after the same round trip
	var round_trip = JSON.parse_string(JSON.stringify(played, "\t", true))
	assert_eq(round_trip, JSON.parse_string(file.get_as_text()))
