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
