## The Prism Spire's beam: a continuous magic beam that locks one foe and hurts
## it a little every tick, with no shots, until the foe falls or leaves reach.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


## The beam's damage a second at a level, read from the content.
func _dps(level: int = 0) -> float:
	return float(TOWERS.DEFS.prismSpire.damage[level])


func _hp_lost(foe: Foe, from: float) -> float:
	return from - foe.hp


func test_the_beam_deals_its_damage_per_second_spread_over_the_ticks() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var start := foe.hp
	Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps() / 30.0, 1e-12, "one tick of a second's damage")
	for i in 29:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps(), 1e-9, "a second of beam")
	for i in 60:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps() * 3.0, 1e-9, "three seconds")


func test_a_higher_level_hits_harder() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	scene.game.buttons = 1000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(scene.tower.level, 1)
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var start := foe.hp
	for i in 30:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps(1), 1e-9)


func test_the_beam_ignores_armor_where_a_spool_guard_loses_some_to_it() -> void:
	var prism := TowerFireKit.scene("prismSpire")
	var orc_a := TowerFireKit.foe(prism.game, prism.near, "corrugatedOrc")
	var start := orc_a.hp
	for i in 30:
		Game.tick(prism.game)
	assert_almost_eq(_hp_lost(orc_a, start), _dps(), 1e-9, "the whole damage a second")
	var spool := TowerFireKit.scene("spoolGuard")
	var orc_b := TowerFireKit.foe(spool.game, spool.near, "corrugatedOrc")
	for i in 30:
		Game.tick(spool.game)
	# shots a second of the Spool Guard's damage, each less the orc's armor
	var spool_def: Dictionary = TOWERS.DEFS.spoolGuard
	var armor := float(FoeStats.for_wave("corrugatedOrc", 1).armor)
	var shots: float = spool_def.rate[0]
	var damage: float = spool_def.damage[0]
	assert_almost_eq(_hp_lost(orc_b, start), (damage - armor) * shots, 1e-9)
	assert_lt(
		_hp_lost(orc_b, start) / (damage * shots), 0.6, "armor ate over 40% of the Spool Guard"
	)


func test_the_beam_locks_the_foe_nearest_the_heartstone() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var behind := TowerFireKit.foe(scene.game, scene.near - 0.3, "cardboardGolem")
	var ahead := TowerFireKit.foe(scene.game, scene.near + 0.3, "cardboardGolem")
	assert_eq(scene.tower.target_id, -1, "no lock before the first tick")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, ahead.id)
	assert_eq(behind.hp, behind.max_hp)
	assert_lt(ahead.hp, ahead.max_hp)


func test_the_lock_stays_on_its_foe_even_when_another_gets_ahead() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	# the older foe spawned first and starts behind, so the lock is on the newer one
	var older := TowerFireKit.foe(scene.game, scene.near - 0.3, "cardboardGolem")
	var newer := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, newer.id)
	older.distance = scene.near + 0.4
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, newer.id, "it keeps the lock")
	assert_eq(older.hp, older.max_hp)


func test_the_lock_drops_when_the_foe_leaves_reach_and_moves_on() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var first := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var second := TowerFireKit.foe(scene.game, scene.near - 0.3, "cardboardGolem")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, first.id)
	var away := TowerFireKit.farthest_from(scene)
	assert_gt(away[1], 2.3, "some of the road is out of reach")
	first.distance = away[0]
	var start := first.hp
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, second.id, "re-locked on the foe still in reach")
	assert_eq(first.hp, start, "the first foe is no longer hurt")


func test_with_nobody_in_reach_there_is_no_lock_and_no_damage() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, -1)
	var away := TowerFireKit.farthest_from(scene)
	assert_gt(away[1], 2.3, "some of the road is out of reach")
	var foe := TowerFireKit.foe(scene.game, away[0], "cardboardGolem")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, -1)
	assert_eq(foe.hp, foe.max_hp)


func test_a_kill_pays_once_and_the_lock_moves_off_the_fallen_foe() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 0.3
	var buttons := scene.game.buttons
	Game.tick(scene.game)
	assert_false(foe.alive)
	assert_eq(scene.game.buttons, buttons + foe.reward)
	var killed := 0
	for event in scene.game.events:
		if event.kind == GameEvent.Kind.FOE_KILLED:
			killed += 1
	assert_eq(killed, 1)
	assert_eq(scene.tower.target_id, -1, "no lock on a foe that is already gone")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, -1, "nothing left to lock")
	assert_eq(scene.game.buttons, buttons + foe.reward, "no second reward")


func test_a_beam_fires_no_shot_events() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	for i in 10:
		Game.tick(scene.game)
		assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.TOWER_FIRED).size(), 0)


func test_two_beams_on_one_foe_add_up() -> void:
	var scene := TowerFireKit.pair("prismSpire", "prismSpire")
	assert_eq(scene.second.type, "prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var start := foe.hp
	for i in 30:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps() * 2.0, 1e-9)


func test_a_lock_is_released_the_tick_another_tower_kills_the_foe() -> void:
	var scene := TowerFireKit.pair("prismSpire", "spoolGuard")
	assert_eq(scene.second.type, "spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "scrapGoblin")
	scene.game.events = []
	foe.hp = 5.0
	Game.tick(scene.game)
	# the beam (first in the list) hurt it by 0.53, the Spool Guard's 9 killed it
	assert_false(foe.alive)
	assert_eq(scene.tower.target_id, -1)


func test_defence_is_taken_off_the_beams_damage_per_second_not_per_tick() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	foe.resist = 1
	var start := foe.hp
	for i in 30:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps() - 1.0, 1e-9, "a second less 1 resist")
	foe.resist = 40
	start = foe.hp
	for i in 30:
		Game.tick(scene.game)
	assert_almost_eq(_hp_lost(foe, start), _dps() / 4.0, 1e-9, "the floor is a quarter")


func test_an_upgrade_while_locked_keeps_the_lock_and_hits_harder() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, foe.id)
	scene.game.buttons = 1000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	var start := foe.hp
	for i in 30:
		Game.tick(scene.game)
	assert_eq(scene.tower.target_id, foe.id)
	assert_almost_eq(_hp_lost(foe, start), _dps(1), 1e-9, "a level 2 beam")


func test_selling_a_locked_tower_stops_the_beam() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	var before_sale := foe.hp
	assert_lt(before_sale, foe.max_hp, "the beam was hurting it")
	Game.submit(scene.game, Command.sell(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(foe.hp, before_sale, "the sale tick burns nothing: the tower is gone first")
	for i in 10:
		Game.tick(scene.game)
	assert_eq(scene.game.towers.size(), 0)
	assert_eq(foe.hp, before_sale)


func test_a_non_beam_tower_never_holds_a_lock() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, -1)


func test_the_beam_draws_no_random_numbers() -> void:
	var with_tower := TowerFireKit.scene("prismSpire")
	var without := Game.create(1)
	for game in [with_tower.game, without]:
		Game.submit(game, Command.launch_wave())
	for i in 600:
		Game.tick(with_tower.game)
		Game.tick(without)
	assert_eq(with_tower.game.rng.state, without.rng.state)
	assert_eq(with_tower.game.route_rng.state, without.route_rng.state)


func test_the_same_seed_and_commands_replay_the_same_with_a_beam() -> void:
	var snapshots: Array[Dictionary] = []
	for run in 2:
		var scene := TowerFireKit.scene("prismSpire")
		Game.submit(scene.game, Command.launch_wave())
		for i in 900:
			Game.tick(scene.game)
		snapshots.append(GameTestKit.snapshot(scene.game))
	assert_eq(snapshots[0], snapshots[1])
