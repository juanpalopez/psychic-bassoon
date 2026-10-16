## Tier 4 for the Thimble Mortar: the Glitter Cannon (Confetti Burst, Shrapnel Spread) and
## the Sticky Glue Mortar (PVA Deluge, Lingering Residue).
extends GutTest

const SPECS := preload("res://content/specs.gd")
const TOWERS := preload("res://content/towers.gd")

const GLITTER := "glitterCannon"
const GLUE := "stickyGlueMortar"


func _scene(spec: String) -> TowerFireKit.Scene:
	var scene := TowerFireKit.scene("thimbleMortar")
	scene.game.buttons = 100000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, spec))
	Game.tick(scene.game)
	scene.tower.cooldown = 1000.0
	return scene


func _tough(game: GameState, along: float, type: String = "corrugatedOrc") -> Foe:
	var foe := TowerFireKit.foe(game, along, type)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	return foe


func _kinds(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	return TowerFireKit.kinds(game, kind)


func test_the_content_gives_the_mortar_two_specs() -> void:
	var specs: Array = SPECS.for_tower("thimbleMortar")
	assert_eq(specs.size(), 2)
	assert_eq(specs[0].id, GLITTER)
	assert_eq(specs[1].id, GLUE)
	assert_eq(specs[0].passive.kind, "splash_bonus")
	assert_eq(specs[0].active.kind, "confetti_burst")
	assert_eq(specs[1].passive.kind, "residue")
	assert_eq(specs[1].active.kind, "pva_deluge")


# --- Blind ---


func test_a_blind_foe_misses_exactly_its_share_of_blows_without_random_numbers() -> void:
	var game := GuardKit.game_with_tent()
	var guard: Guard = game.guards[0]
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	GuardKit.tick(game, 3)
	var holder: Guard = (
		game.guards[0] if game.guards[0].id == foe.engaged_guard_id else game.guards[1]
	)
	guard = holder
	guard.hp = 1.0e9
	guard.max_hp = 1.0e9
	foe.blind = 0.4
	foe.blind_timer = 1000.0
	var armor := float(guard.armor)
	var blow := maxf(foe.attack_damage * 0.25, foe.attack_damage - armor)
	var before := guard.hp
	var blows := 0
	var previous := foe.attack_cooldown
	# count the blows by the cooldown restarting
	for i in 30 * 160:
		Game.tick(game)
		if foe.attack_cooldown > previous + 0.5:
			blows += 1
		previous = foe.attack_cooldown
	var hits := (before - guard.hp) / blow
	assert_almost_eq(hits / float(blows), 0.6, 0.02, "40 percent of the blows miss")


func test_blind_wears_off() -> void:
	var foe := Foe.new()
	foe.blind = 0.4
	foe.blind_timer = 0.1
	var game := GameState.new()
	game.foes.append(foe)
	for i in 5:
		Status.step_blind(game)
	assert_eq(foe.blind, 0.0)
	assert_eq(foe.blind_timer, 0.0)


# --- Glitter Cannon ---


func test_confetti_burst_hurts_and_blinds_every_foe_in_the_blast_only() -> void:
	var scene := _scene(GLITTER)
	var game := scene.game
	var active: Dictionary = SPECS.find("thimbleMortar", GLITTER).active
	var target := _tough(game, scene.near + 0.2)
	var beside := _tough(game, scene.near + 0.2)
	var away: Array = TowerFireKit.farthest_from(scene)
	var far := _tough(game, float(away[0]))
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	for foe in [target, beside]:
		assert_eq(foe.blind, float(active.blind))
		assert_almost_eq(foe.blind_timer, float(active.seconds) - Game.TICK_SECONDS, 1e-6)
		assert_lt(foe.hp, foe.max_hp, "the shell hurts")
	assert_eq(far.blind, 0.0)
	assert_eq(far.hp, far.max_hp)
	assert_eq(_kinds(game, GameEvent.Kind.ABILITY_USED).size(), 1)


func test_confetti_burst_with_no_target_is_refused() -> void:
	var scene := _scene(GLITTER)
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(
		_kinds(scene.game, GameEvent.Kind.COMMAND_REJECTED)[0].reason,
		GameEvent.RejectReason.NO_TARGET
	)
	assert_eq(scene.tower.ability_cooldown, 0.0)


func test_shrapnel_spread_widens_the_blast_by_its_share() -> void:
	var plain := TowerFireKit.scene("thimbleMortar")
	var spec := _scene(GLITTER)
	var bonus: float = SPECS.find("thimbleMortar", GLITTER).passive.bonus
	var base: float = TOWERS.DEFS.thimbleMortar.splash[2]
	var event_splash: Array[float] = []
	for scene in [plain, spec]:
		scene.game.buttons = 100000
		if scene == plain:
			Game.submit(scene.game, Command.upgrade(scene.tower.id))
			Game.submit(scene.game, Command.upgrade(scene.tower.id))
			Game.tick(scene.game)
		scene.tower.cooldown = 0.0
		var target := _tough(scene.game, scene.near)
		Game.tick(scene.game)
		event_splash.append(_kinds(scene.game, GameEvent.Kind.TOWER_FIRED)[0].splash)
		assert_not_null(target)
	assert_almost_eq(event_splash[0], base, 1e-9)
	assert_almost_eq(event_splash[1], base * (1.0 + bonus), 1e-9)


func test_shrapnel_spread_hits_a_foe_the_plain_blast_misses() -> void:
	var scene := _scene(GLITTER)
	var game := scene.game
	var bonus: float = SPECS.find("thimbleMortar", GLITTER).passive.bonus
	var base: float = TOWERS.DEFS.thimbleMortar.splash[2]
	var target := _tough(game, scene.near)
	var edge := _tough(game, scene.near)
	edge.x = target.x + base * (1.0 + bonus * 0.5)
	edge.y = target.y
	scene.tower.cooldown = 0.0
	Game.tick(game)
	assert_lt(edge.hp, edge.max_hp, "inside the widened blast, outside the plain one")


# --- Sticky Glue Mortar ---


func test_pva_deluge_slows_every_foe_in_the_area_then_lets_go() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var active: Dictionary = SPECS.find("thimbleMortar", GLUE).active
	var target := _tough(game, scene.near + 0.2)
	target.speed = 1.0
	var away: Array = TowerFireKit.farthest_from(scene)
	var far := _tough(game, float(away[0]))
	far.speed = 1.0
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(target.slow, float(active.slow))
	assert_almost_eq(target.slow_timer, float(active.seconds) - Game.TICK_SECONDS, 1e-6)
	assert_eq(far.slow, 0.0)
	for i in int(float(active.seconds) * 30.0):
		Game.tick(game)
	assert_eq(target.slow, 0.0)
	assert_eq(target.slow_timer, 0.0)


func test_a_shell_of_the_glue_mortar_leaves_a_pool_that_slows_for_its_seconds() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var passive: Dictionary = SPECS.find("thimbleMortar", GLUE).passive
	var target := _tough(game, scene.near)
	target.speed = 0.0
	scene.tower.cooldown = 0.0
	Game.tick(game)
	assert_eq(game.zones.size(), 1)
	assert_eq(_kinds(game, GameEvent.Kind.ZONE_OPENED).size(), 1)
	scene.tower.cooldown = 1000.0
	Game.tick(game)
	assert_eq(target.slow, float(passive.slow), "slowed while it stands in the pool")
	for i in int(float(passive.seconds) * 30.0) + 10:
		Game.tick(game)
	assert_eq(game.zones.size(), 0)
	assert_eq(target.slow, 0.0, "the pool is gone and so is the slow")


func test_a_pool_does_not_slow_a_flying_foe_or_one_outside_it() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var target := _tough(game, scene.near)
	var flyer := _tough(game, scene.near, "razorMoth")
	var away: Array = TowerFireKit.farthest_from(scene)
	var far := _tough(game, float(away[0]))
	target.speed = 0.0
	scene.tower.cooldown = 0.0
	Game.tick(game)
	scene.tower.cooldown = 1000.0
	Game.tick(game)
	assert_eq(flyer.slow, 0.0)
	assert_eq(far.slow, 0.0)


func test_the_same_commands_give_the_same_game_for_both_mortar_specs() -> void:
	for spec in [GLITTER, GLUE]:
		var snapshots := []
		for run in 2:
			var scene := _scene(spec)
			_tough(scene.game, scene.near)
			_tough(scene.game, scene.near)
			scene.tower.cooldown = 0.0
			Game.submit(scene.game, Command.activate(scene.tower.id))
			for i in 300:
				Game.tick(scene.game)
			snapshots.append(GameTestKit.snapshot(scene.game))
		assert_eq(snapshots[0], snapshots[1], spec)


func test_the_mortar_scenarios_match_their_golden() -> void:
	var file := FileAccess.open(SpecScenario.MORTAR_GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	var played := {
		"glitterCannon": SpecScenario.play_mortar("glitterCannon"),
		"stickyGlueMortar": SpecScenario.play_mortar("stickyGlueMortar"),
	}
	# JSON turns whole numbers into floats, so compare after the same round trip
	var round_trip = JSON.parse_string(JSON.stringify(played, "\t", true))
	assert_eq(round_trip, JSON.parse_string(file.get_as_text()))
