## Tier 4: a level 3 tower chooses one specialisation, once. The choice costs
## Buttons, gives a passive and unlocks an active ability with a cooldown.
extends GutTest

const SPECS := preload("res://content/specs.gd")
const RULES := preload("res://content/game_rules.gd")

const BALLISTA := "crossbowBallista"


## A Spool Guard at level 3 (the top level), with plenty of Buttons.
func _top_level_scene() -> TowerFireKit.Scene:
	var scene := TowerFireKit.scene()
	scene.game.buttons = 10000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	scene.tower.cooldown = 0.0
	return scene


func _chosen_scene() -> TowerFireKit.Scene:
	var scene := _top_level_scene()
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BALLISTA))
	Game.tick(scene.game)
	scene.tower.cooldown = 0.0
	return scene


func _reasons(game: GameState) -> Array:
	var found := []
	for event in TowerFireKit.kinds(game, GameEvent.Kind.COMMAND_REJECTED):
		found.append(event.reason)
	return found


func _line_of_orcs(scene: TowerFireKit.Scene, offsets: Array) -> Array[Foe]:
	# foes on a line out of the tower, the farthest one nearest the Heartstone (so it is the target)
	var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	var foes: Array[Foe] = []
	var distance := 10.0
	for offset in offsets:
		var foe := TowerFireKit.foe(scene.game, distance, "corrugatedOrc")
		foe.x = centre.x + float(offset)
		foe.y = centre.y
		foes.append(foe)
		distance += 0.5
	return foes


func test_the_content_gives_the_spool_guard_a_crossbow_spec_with_a_passive_and_an_active() -> void:
	var spec: Dictionary = SPECS.for_tower("spoolGuard")[0]
	assert_eq(spec.id, BALLISTA)
	assert_eq(spec.name, "Crossbow Ballista")
	assert_gt(spec.cost, 0)
	assert_eq(spec.passive.kind, "armor_ignore")
	assert_eq(spec.active.kind, "skewer")
	assert_gt(spec.active.cooldown, 0.0)


func test_a_tower_below_the_top_level_cannot_choose() -> void:
	var scene := TowerFireKit.scene()
	scene.game.buttons = 10000
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BALLISTA))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.NOT_AT_TOP_LEVEL])
	assert_eq(scene.tower.spec, "")


func test_an_unknown_spec_or_one_of_another_tower_is_refused() -> void:
	var scene := _top_level_scene()
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, "bogus"))
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, ""))
	Game.tick(scene.game)
	assert_eq(
		_reasons(scene.game),
		[GameEvent.RejectReason.UNKNOWN_SPEC, GameEvent.RejectReason.UNKNOWN_SPEC]
	)
	assert_eq(scene.tower.spec, "")


func test_a_missing_tower_is_refused() -> void:
	var scene := _top_level_scene()
	Game.submit(scene.game, Command.choose_spec(999, BALLISTA))
	Game.submit(scene.game, Command.activate(999))
	Game.tick(scene.game)
	assert_eq(
		_reasons(scene.game),
		[GameEvent.RejectReason.NO_SUCH_TOWER, GameEvent.RejectReason.NO_SUCH_TOWER]
	)


func test_too_few_buttons_refuses_the_choice_and_keeps_them() -> void:
	var scene := _top_level_scene()
	var cost: int = SPECS.for_tower("spoolGuard")[0].cost
	scene.game.buttons = cost - 1
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BALLISTA))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.NOT_ENOUGH_BUTTONS])
	assert_eq(scene.game.buttons, cost - 1)
	assert_eq(scene.tower.spec, "")


func test_choosing_pays_marks_the_tower_and_says_so() -> void:
	var scene := _top_level_scene()
	var cost: int = SPECS.for_tower("spoolGuard")[0].cost
	var buttons := scene.game.buttons
	var invested := scene.tower.invested
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BALLISTA))
	Game.tick(scene.game)
	assert_eq(scene.tower.spec, BALLISTA)
	assert_eq(scene.game.buttons, buttons - cost)
	assert_eq(scene.tower.invested, invested + cost)
	assert_eq(scene.tower.ability_cooldown, 0.0, "the active is ready when the spec is chosen")
	var events := TowerFireKit.kinds(scene.game, GameEvent.Kind.SPEC_CHOSEN)
	assert_eq(events.size(), 1)
	assert_eq(events[0].tower_id, scene.tower.id)
	assert_eq(events[0].spec, BALLISTA)


func test_a_spec_is_chosen_once() -> void:
	var scene := _chosen_scene()
	var buttons := scene.game.buttons
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BALLISTA))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.SPEC_ALREADY_CHOSEN])
	assert_eq(scene.game.buttons, buttons)


func test_selling_refunds_the_spec_like_any_upgrade() -> void:
	var scene := _chosen_scene()
	var refund := int(floor(float(scene.tower.invested) * RULES.SELL_REFUND))
	var buttons := scene.game.buttons
	Game.submit(scene.game, Command.sell(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(scene.game.buttons, buttons + refund)


func test_the_top_level_still_has_nothing_to_upgrade() -> void:
	var scene := _chosen_scene()
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.MAX_LEVEL])


func test_an_ability_needs_a_spec() -> void:
	var scene := _top_level_scene()
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.NO_SPEC])


func test_an_ability_with_no_foe_in_reach_is_refused_and_does_not_cool_down() -> void:
	var scene := _chosen_scene()
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.NO_TARGET])
	assert_eq(scene.tower.ability_cooldown, 0.0)


func test_an_ability_cools_down_then_is_ready_again() -> void:
	var scene := _chosen_scene()
	var foes := _line_of_orcs(scene, [1.0])
	foes[0].hp = 100000.0
	foes[0].max_hp = 100000.0
	scene.tower.cooldown = 1000.0
	var cooldown: float = SPECS.for_tower("spoolGuard")[0].active.cooldown
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.ABILITY_USED).size(), 1)
	assert_almost_eq(scene.tower.ability_cooldown, cooldown - Game.TICK_SECONDS, 1e-6)
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(_reasons(scene.game), [GameEvent.RejectReason.ABILITY_COOLING_DOWN])
	for i in int(cooldown * RULES.TICK_RATE):
		Game.tick(scene.game)
	assert_eq(scene.tower.ability_cooldown, 0.0)
	# the foe walked off its spot with the ticks: put it back in reach
	var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	foes[0].x = centre.x + 1.0
	foes[0].y = centre.y
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.ABILITY_USED).size(), 1)


func test_armor_piercing_ignores_a_share_of_the_armor() -> void:
	var results := []
	for scene in [_top_level_scene(), _chosen_scene()]:
		var foe := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
		var before := foe.hp
		scene.tower.cooldown = 0.0
		Game.tick(scene.game)
		results.append(before - foe.hp)
	# level 3 damage 33 against 6 armor
	assert_almost_eq(float(results[0]), 33.0 - 6.0, 1e-6)
	assert_almost_eq(float(results[1]), 33.0 - 6.0 * (1.0 - 0.4), 1e-6)


func test_the_skewer_hits_five_foes_in_a_band_nearest_first_for_full_damage_and_bleeds() -> void:
	var scene := _chosen_scene()
	var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	var spec: Dictionary = SPECS.for_tower("spoolGuard")[0]
	var active: Dictionary = spec.active
	var radius := TowerFireKit.foe(scene.game, 9.0, "corrugatedOrc").radius
	var band: float = float(active.width) + radius
	# edge-in (just inside the band), edge-out (just outside) and one behind the tower
	var edge_in := _orc_at(scene, 9.1, centre.x + 0.7, centre.y + band - 0.01)
	var edge_out := _orc_at(scene, 9.2, centre.x + 0.9, centre.y + band + 0.01)
	var behind := _orc_at(scene, 9.3, centre.x - 0.5, centre.y)
	var line: Array[Foe] = []
	# the last one is the target (nearest the Heartstone): it stands farthest, so it is the sixth
	for offset in [0.5, 1.0, 1.5, 2.0, 2.5]:
		line.append(_orc_at(scene, 10.0 + offset, centre.x + offset, centre.y))
	scene.tower.cooldown = 1000.0
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	var armor := float(line[0].armor)
	var lost: float = float(active.damage) - armor * (1.0 - float(spec.passive.share))
	var bled: float = float(active.bleed_dps) * Game.TICK_SECONDS
	for foe in [line[0], line[1], line[2], line[3], edge_in]:
		assert_almost_eq(foe.max_hp - foe.hp, lost + bled, 1e-6)
		assert_eq(foe.bleed_dps, float(active.bleed_dps))
		assert_almost_eq(foe.bleed_timer, float(active.bleed_seconds) - Game.TICK_SECONDS, 1e-6)
	for foe in [line[4], edge_out, behind]:
		assert_eq(foe.hp, foe.max_hp)
		assert_eq(foe.bleed_timer, 0.0)
	var event := TowerFireKit.kinds(scene.game, GameEvent.Kind.ABILITY_USED)[0]
	assert_eq(event.tower_id, scene.tower.id)
	assert_eq(event.foe_id, line[4].id)
	assert_almost_eq(event.x2, centre.x + TowerFire.reach_of(scene.game, scene.tower), 1e-6)
	assert_almost_eq(event.y2, centre.y, 1e-6)


func _orc_at(scene: TowerFireKit.Scene, along: float, x: float, y: float) -> Foe:
	var foe := TowerFireKit.foe(scene.game, along, "corrugatedOrc")
	foe.x = x
	foe.y = y
	return foe


func test_bleeding_hurts_a_little_each_tick_with_true_damage_and_ends() -> void:
	var scene := TowerFireKit.scene()
	var foe := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
	scene.tower.cooldown = 1000.0
	Status.apply_bleed(foe, 6.0, 2.0)
	var ticks := 0
	while foe.bleed_timer > 0.0 and ticks < 200:
		Game.tick(scene.game)
		ticks += 1
	assert_eq(ticks, 60)
	assert_almost_eq(foe.max_hp - foe.hp, 6.0 * 2.0, 1e-6)
	assert_eq(foe.bleed_dps, 0.0)


func test_a_stronger_bleed_replaces_a_weaker_one_and_a_weaker_does_not() -> void:
	var foe := Foe.new()
	Status.apply_bleed(foe, 5.0, 3.0)
	Status.apply_bleed(foe, 2.0, 9.0)
	assert_eq(foe.bleed_dps, 5.0)
	assert_eq(foe.bleed_timer, 3.0)
	Status.apply_bleed(foe, 8.0, 1.0)
	assert_eq(foe.bleed_dps, 8.0)
	assert_eq(foe.bleed_timer, 1.0)
	Status.apply_bleed(foe, 0.0, 5.0)
	Status.apply_bleed(foe, 8.0, 0.0)
	assert_eq(foe.bleed_timer, 1.0, "no bleed is no change")


func test_a_foe_that_bleeds_to_death_pays_its_reward_once() -> void:
	var scene := TowerFireKit.scene()
	var foe := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
	foe.hp = 0.1
	scene.tower.cooldown = 1000.0
	Status.apply_bleed(foe, 30.0, 3.0)
	var buttons := scene.game.buttons
	var kills := 0
	for i in 10:
		Game.tick(scene.game)
		kills += TowerFireKit.kinds(scene.game, GameEvent.Kind.FOE_KILLED).size()
	assert_eq(kills, 1)
	assert_eq(scene.game.buttons, buttons + foe.reward)


func test_the_scenario_with_a_spec_matches_its_golden() -> void:
	var file := FileAccess.open(SpecScenario.GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	# JSON turns whole numbers into floats, so compare after the same round trip
	var played = JSON.parse_string(JSON.stringify(SpecScenario.play(), "\t", true))
	assert_eq(played, JSON.parse_string(file.get_as_text()))


func test_the_scenario_plays_the_same_twice() -> void:
	assert_eq(SpecScenario.play(), SpecScenario.play())
