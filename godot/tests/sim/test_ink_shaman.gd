## The Ink Shaman: a support foe whose aura heals and speeds up the foes around it, and that
## towers shoot first.
extends GutTest

const FOES := preload("res://content/foes.gd")
const WAVES := preload("res://content/waves.gd")


func _game() -> GameState:
	var game := Game.create(1)
	game.heartstone_health = 100000
	return game


## A foe placed `along` cells down the main road, with no walking of its own for the test.
func _foe(game: GameState, type: String, along: float) -> Foe:
	var foe := FoeSpawner.spawn(game, type, 1, 0)
	foe.distance = along
	var at := game.routes[0].position_at(along)
	foe.x = at.x
	foe.y = at.y
	return foe


func test_the_shaman_is_a_support_foe_with_an_aura() -> void:
	assert_true(FOES.FOE_IDS.has("inkShaman"))
	var def: Dictionary = FOES.DEFS.inkShaman
	assert_eq(def.name, "Ink Shaman")
	assert_true(def.support)
	assert_gt(def.aura_radius, 0.0)
	assert_gt(def.aura_heal, 0.0)
	assert_gt(def.aura_speed, 0.0)
	assert_true(def.blockable)
	assert_lt(def.hp, FOES.DEFS.corrugatedOrc.hp, "frail, so it must be prioritised")


func test_a_spawned_shaman_carries_its_aura() -> void:
	var game := _game()
	var shaman := _foe(game, "inkShaman", 5.0)
	assert_true(shaman.support)
	assert_eq(shaman.aura_radius, FOES.DEFS.inkShaman.aura_radius)
	assert_false(_foe(game, "scrapGoblin", 5.0).support)


func test_the_aura_heals_hurt_foes_in_its_radius_each_tick() -> void:
	var game := _game()
	var shaman := _foe(game, "inkShaman", 6.0)
	var near := _foe(game, "corrugatedOrc", 6.3)
	near.hp = near.max_hp * 0.5
	var far := _foe(game, "corrugatedOrc", 12.0)
	far.hp = far.max_hp * 0.5
	var before := near.hp
	Game.tick(game)
	var healed := near.max_hp * FOES.DEFS.inkShaman.aura_heal * Game.TICK_SECONDS
	assert_almost_eq(near.hp - before, healed, 1e-9)
	assert_eq(far.hp, far.max_hp * 0.5, "out of the aura")
	assert_gt(shaman.hp, 0.0)


func test_the_heal_never_goes_above_the_maximum() -> void:
	var game := _game()
	_foe(game, "inkShaman", 6.0)
	var near := _foe(game, "corrugatedOrc", 6.2)
	near.hp = near.max_hp - 0.001
	Game.tick(game)
	assert_eq(near.hp, near.max_hp)


func test_the_shaman_does_not_heal_itself() -> void:
	var game := _game()
	var shaman := _foe(game, "inkShaman", 6.0)
	shaman.hp = shaman.max_hp * 0.5
	Game.tick(game)
	assert_eq(shaman.hp, shaman.max_hp * 0.5)


func test_the_aura_speeds_up_foes_in_its_radius_and_not_twice() -> void:
	var game := _game()
	var walker := _foe(game, "corrugatedOrc", 6.2)
	var lone := _foe(game, "corrugatedOrc", 14.0)
	_foe(game, "inkShaman", 6.0)
	_foe(game, "inkShaman", 6.1)
	var start := walker.distance
	var lone_start := lone.distance
	Game.tick(game)
	var bonus: float = FOES.DEFS.inkShaman.aura_speed
	assert_almost_eq(
		walker.distance - start, walker.speed * (1.0 + bonus) * Game.TICK_SECONDS, 1e-9
	)
	assert_almost_eq(lone.distance - lone_start, lone.speed * Game.TICK_SECONDS, 1e-9)


func test_the_speed_bonus_ends_when_the_shaman_is_gone() -> void:
	var game := _game()
	var walker := _foe(game, "corrugatedOrc", 6.2)
	var shaman := _foe(game, "inkShaman", 6.0)
	Game.tick(game)
	shaman.alive = false
	var start := walker.distance
	Game.tick(game)
	assert_almost_eq(walker.distance - start, walker.speed * Game.TICK_SECONDS, 1e-9)


func test_a_slow_and_the_aura_combine() -> void:
	var game := _game()
	var walker := _foe(game, "corrugatedOrc", 6.2)
	walker.slow = 0.5
	walker.slow_timer = 5.0
	_foe(game, "inkShaman", 6.0)
	var start := walker.distance
	Game.tick(game)
	var bonus: float = FOES.DEFS.inkShaman.aura_speed
	var expected := walker.speed * (1.0 + bonus) * 0.5 * Game.TICK_SECONDS
	assert_almost_eq(walker.distance - start, expected, 1e-9)


func test_a_tower_shoots_the_shaman_before_a_foe_nearer_the_heartstone() -> void:
	var scene := TowerFireKit.scene()
	var game: GameState = scene.game
	var ahead := TowerFireKit.foe(game, scene.near + 0.4)
	var shaman := TowerFireKit.foe(game, scene.near - 0.3, "inkShaman")
	assert_eq(TowerFire.target_for(game, scene.tower).id, shaman.id)
	assert_ne(ahead.id, shaman.id)


func test_without_a_shaman_the_target_is_still_the_foe_nearest_the_heartstone() -> void:
	var scene := TowerFireKit.scene()
	var game: GameState = scene.game
	var ahead := TowerFireKit.foe(game, scene.near + 0.3)
	TowerFireKit.foe(game, scene.near - 0.3)
	assert_eq(TowerFire.target_for(game, scene.tower).id, ahead.id)


func test_the_stats_scale_with_the_wave_like_any_foe() -> void:
	var early := FoeStats.for_wave("inkShaman", 1)
	var late := FoeStats.for_wave("inkShaman", 15)
	assert_gt(late.hp, early.hp)
	assert_gt(late.speed, early.speed)
