## Tier 4 for the Guard Tent: the Cardboard Knights (Shield Wall, Corrugated Plating) and the
## Scissor Rogues (Precision Snipe, Paper Cuts).
extends GutTest

const SPECS := preload("res://content/specs.gd")

const KNIGHTS := "cardboardKnights"
const ROGUES := "scissorRogues"


## A game with a Guard Tent taken to the top level with the spec chosen.
func _game_with(spec: String) -> GameState:
	var game := GuardKit.game_with_tent()
	var tent := GuardKit.tent(game)
	game.buttons = 100000
	Game.submit(game, Command.upgrade(tent.id))
	Game.submit(game, Command.upgrade(tent.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(tent.id, spec))
	Game.tick(game)
	return game


## A foe that a guard holds, with hp to spare, and the guard that holds it (hp to spare too).
func _held(game: GameState) -> Array:
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	GuardKit.tick(game, 3)
	var guard: Guard = null
	for candidate in game.guards:
		if candidate.id == foe.engaged_guard_id:
			guard = candidate
	assert_not_null(guard, "a guard holds the foe")
	guard.hp = 1.0e9
	guard.max_hp = 1.0e9
	return [foe, guard]


func _rejected(game: GameState) -> Array:
	var reasons := []
	for event in GuardKit.events_of(game, GameEvent.Kind.COMMAND_REJECTED):
		reasons.append(event.reason)
	return reasons


func test_the_content_gives_the_guard_tent_two_specs() -> void:
	var specs: Array = SPECS.for_tower("guardTent")
	assert_eq(specs.size(), 2)
	assert_eq(specs[0].id, KNIGHTS)
	assert_eq(specs[1].id, ROGUES)
	assert_eq(specs[0].passive.kind, "plating")
	assert_eq(specs[0].active.kind, "shield_wall")
	assert_eq(specs[1].passive.kind, "paper_cuts")
	assert_eq(specs[1].active.kind, "precision_snipe")


# --- Cardboard Knights ---


func test_shield_wall_doubles_the_guards_armor_for_its_seconds() -> void:
	var game := _game_with(KNIGHTS)
	var active: Dictionary = SPECS.find("guardTent", KNIGHTS).active
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	var blow := foe.attack_damage - float(guard.armor)
	var walled := foe.attack_damage - 2.0 * float(guard.armor)
	assert_gt(blow, walled, "armor matters at this level")
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	Game.tick(game)
	for g in game.guards:
		assert_gt(g.wall_timer, 0.0)
	var before := guard.hp
	foe.attack_cooldown = 0.0
	GuardKit.tick(game, 1)
	assert_almost_eq(before - guard.hp, walled, 1e-6)
	# the wall ends after its seconds
	GuardKit.tick(game, int(float(active.seconds) * 30.0))
	for g in game.guards:
		assert_eq(g.wall_timer, 0.0)


func test_shield_wall_needs_a_guard_on_its_feet() -> void:
	var game := _game_with(KNIGHTS)
	for guard in game.guards:
		guard.alive = false
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	Game.tick(game)
	assert_eq(_rejected(game), [GameEvent.RejectReason.NO_TARGET])
	assert_eq(GuardKit.tent(game).ability_cooldown, 0.0)


func test_corrugated_plating_reflects_a_share_of_the_blow_that_lands() -> void:
	var game := _game_with(KNIGHTS)
	var share: float = SPECS.find("guardTent", KNIGHTS).passive.share
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	var blow := maxf(foe.attack_damage * 0.25, foe.attack_damage - float(guard.armor))
	foe.attack_cooldown = 0.0
	guard.cooldown = 1000.0
	var foe_before := foe.hp
	var guard_before := guard.hp
	GuardKit.tick(game, 1)
	assert_almost_eq(guard_before - guard.hp, blow, 1e-6)
	assert_almost_eq(foe_before - foe.hp, blow * share, 1e-6, "a share comes back as true damage")


func test_a_blind_foes_missed_blow_reflects_nothing() -> void:
	var game := _game_with(KNIGHTS)
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	foe.blind = 1.0
	foe.blind_timer = 100.0
	foe.attack_cooldown = 0.0
	guard.cooldown = 1000.0
	var before := foe.hp
	GuardKit.tick(game, 1)
	assert_eq(foe.hp, before)


# --- Scissor Rogues ---


func test_precision_snipe_hits_the_toughest_ground_foe_in_reach_with_true_damage() -> void:
	var game := _game_with(ROGUES)
	var active: Dictionary = SPECS.find("guardTent", ROGUES).active
	var weak := GuardKit.foe_before_post(game, "scrapGoblin", 0.5)
	var strong := GuardKit.foe_before_post(game, "cardboardGolem", 0.3)
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.hp = 1.0e9
	moth.max_hp = 1.0e9
	moth.x = strong.x
	moth.y = strong.y
	weak.hp = 500.0
	for guard in game.guards:
		guard.cooldown = 1000.0
	var strong_before := strong.hp
	var weak_before := weak.hp
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	Game.tick(game)
	assert_almost_eq(strong_before - strong.hp, float(active.damage), 1e-6, "armor does not apply")
	# a guard may have struck the weak one on taking it, but the snipe went to the other
	assert_gt(weak.hp, weak_before - 100.0)
	assert_eq(moth.hp, moth.max_hp, "guards cannot reach a flyer")
	assert_eq(GuardKit.events_of(game, GameEvent.Kind.ABILITY_USED).size(), 1)


func test_precision_snipe_needs_a_foe_and_a_guard() -> void:
	var game := _game_with(ROGUES)
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	Game.tick(game)
	assert_eq(_rejected(game), [GameEvent.RejectReason.NO_TARGET])
	GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	for guard in game.guards:
		guard.alive = false
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	Game.tick(game)
	assert_eq(_rejected(game), [GameEvent.RejectReason.NO_TARGET])


func test_paper_cuts_slow_a_foe_a_tenth_per_landed_hit_up_to_three_and_wear_off() -> void:
	var game := _game_with(ROGUES)
	var passive: Dictionary = SPECS.find("guardTent", ROGUES).passive
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	foe.attack_cooldown = 1000.0
	for hit in 5:
		guard.cooldown = 0.0
		GuardKit.tick(game, 1)
	assert_eq(foe.cut_stacks, int(passive.max_stacks), "three stacks at most")
	assert_gt(foe.cut_timer, 0.0)
	# released, it walks at 70 percent of its pace
	game.guards.clear()
	foe.engaged_guard_id = -1
	var before := foe.distance
	GuardKit.tick(game, 1)
	var pace := foe.speed * (1.0 - float(passive.slow) * 3.0)
	assert_almost_eq(foe.distance - before, pace * Game.TICK_SECONDS, 1e-9)
	GuardKit.tick(game, int(float(passive.seconds) * 30.0) + 5)
	assert_eq(foe.cut_stacks, 0)
	assert_eq(foe.cut_timer, 0.0)


func test_the_same_commands_give_the_same_game_for_both_guard_specs() -> void:
	for spec in [KNIGHTS, ROGUES]:
		var snapshots := []
		for run in 2:
			var game := _game_with(spec)
			GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
			GuardKit.foe_before_post(game, "cardboardGolem", 0.6)
			Game.submit(game, Command.activate(GuardKit.tent(game).id))
			GuardKit.tick(game, 400)
			snapshots.append(GameTestKit.snapshot(game))
		assert_eq(snapshots[0], snapshots[1], spec)


func test_a_guard_that_the_blow_drops_to_zero_falls_even_if_the_reflection_kills_the_foe() -> void:
	var game := _game_with(KNIGHTS)
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	guard.hp = 0.5
	foe.hp = 0.01
	foe.max_hp = 0.01
	foe.attack_cooldown = 0.0
	guard.cooldown = 1000.0
	GuardKit.tick(game, 1)
	assert_false(foe.alive, "the reflection killed it")
	assert_false(guard.alive, "and the guard still fell")
	assert_eq(guard.hp, 0.0)
	assert_eq(GuardKit.events_of(game, GameEvent.Kind.GUARD_FELL).size(), 1)
	assert_gt(guard.respawn_timer, 0.0)


func test_precision_snipe_prefers_the_first_to_spawn_on_a_tie_and_skips_a_foe_out_of_reach(
) -> void:
	var game := _game_with(ROGUES)
	var first := GuardKit.foe_before_post(game, "cardboardGolem", 0.3)
	var second := GuardKit.foe_before_post(game, "cardboardGolem", 0.3)
	for guard in game.guards:
		guard.cooldown = 1000.0
	var tent := GuardKit.tent(game)
	var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
	var distant := GuardKit.foe_before_post(game, "cardboardGolem", 0.3)
	distant.hp = first.hp + 100.0
	distant.x = centre.x + 90.0
	distant.y = centre.y
	var active: Dictionary = SPECS.find("guardTent", ROGUES).active
	var before := first.hp
	Game.submit(game, Command.activate(tent.id))
	Game.tick(game)
	assert_almost_eq(before - first.hp, float(active.damage), 1e-6, "the first to spawn")
	assert_eq(second.hp, before)
	assert_gt(distant.hp, before, "out of reach, so never chosen")


func test_the_wall_is_over_when_its_seconds_are_up_and_the_next_blow_has_normal_armor() -> void:
	var game := _game_with(KNIGHTS)
	var active: Dictionary = SPECS.find("guardTent", KNIGHTS).active
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	foe.attack_cooldown = 1000.0
	guard.cooldown = 1000.0
	Game.submit(game, Command.activate(GuardKit.tent(game).id))
	GuardKit.tick(game, int(float(active.seconds) * 30.0) + 2)
	assert_eq(guard.wall_timer, 0.0)
	var before := guard.hp
	foe.attack_cooldown = 0.0
	GuardKit.tick(game, 1)
	var normal := foe.attack_damage - float(guard.armor)
	assert_almost_eq(before - guard.hp, normal, 1e-6)


func test_paper_cuts_wear_off_four_seconds_after_the_last_hit_not_the_first() -> void:
	var game := _game_with(ROGUES)
	var passive: Dictionary = SPECS.find("guardTent", ROGUES).passive
	var held := _held(game)
	var foe: Foe = held[0]
	var guard: Guard = held[1]
	foe.attack_cooldown = 1000.0
	guard.interval = 1000.0  # it strikes only when this test says so
	guard.cooldown = 0.0
	GuardKit.tick(game, 1)
	GuardKit.tick(game, 60)
	guard.cooldown = 0.0
	GuardKit.tick(game, 1)
	GuardKit.tick(game, int((float(passive.seconds) - 1.0) * 30.0))
	assert_gt(foe.cut_stacks, 0, "the second hit renewed the cuts")
	guard.cooldown = 1000.0
	GuardKit.tick(game, 60)
	assert_eq(foe.cut_stacks, 0)


func test_cuts_combine_with_a_slow_and_never_reverse_a_foe() -> void:
	var passive: Dictionary = SPECS.find("guardTent", ROGUES).passive
	assert_lt(float(passive.slow) * float(passive.max_stacks), 1.0)
	var game := _game_with(ROGUES)
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 3.0)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	foe.cut_stacks = 3
	foe.cut_slow = float(passive.slow)
	foe.cut_timer = 100.0
	Status.apply_slow(foe, 0.5, 100.0)
	var before := foe.distance
	GuardKit.tick(game, 1)
	var pace := foe.speed * (1.0 - 0.5) * (1.0 - float(passive.slow) * 3.0)
	assert_almost_eq(foe.distance - before, pace * Game.TICK_SECONDS, 1e-9)


func test_the_guard_scenarios_match_their_golden() -> void:
	var file := FileAccess.open(SpecScenario.GUARD_GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	var played := {
		"cardboardKnights": SpecScenario.play_guard("cardboardKnights"),
		"scissorRogues": SpecScenario.play_guard("scissorRogues"),
	}
	# JSON turns whole numbers into floats, so compare after the same round trip
	var round_trip = JSON.parse_string(JSON.stringify(played, "\t", true))
	assert_eq(round_trip, JSON.parse_string(file.get_as_text()))
