## The per-map foe pace (#458, #460): every foe of a map walks `foe_pace` times its content speed,
## applied once when it spawns. 1.0 on every map until the layout valley's content number is
## chosen, so no board moves. The slows and buffs stack on the paced speed, and nothing predicts a
## foe's place from content speed: tower fire, guards and zones read the foe's own `speed`.
extends GutTest

const LAYOUT := preload("res://content/valley/layout_rules.gd")
const FOES := preload("res://content/foes.gd")


func _walk_ticks(pace: float, type: String = "corrugatedOrc") -> int:
	var game := Game.create(1)
	game.hero = null
	game.map.foe_pace = pace
	var foe := FoeSpawner.spawn(game, type, 1, 0)
	var length: float = game.routes[0].total
	var ticks := 0
	while foe.distance < length * 0.25 and ticks < 100000:
		Game.tick(game)
		ticks += 1
	return ticks


func test_pace_is_one_on_every_board() -> void:
	assert_eq(GameMap.new().foe_pace, 1.0)
	for map_seed in [1, 2, 3]:
		assert_eq(Game.create(map_seed).map.foe_pace, 1.0)
		assert_eq(Game.create(map_seed, 32, 20).map.foe_pace, 1.0)
		assert_eq(MapGen.generate(map_seed).foe_pace, 1.0)
		assert_eq(MapGen.generate_valley(map_seed).foe_pace, 1.0)
	assert_eq(TowerFireKit.landscape(1).map.foe_pace, 1.0)


func test_the_layout_valley_takes_its_pace_from_content() -> void:
	var map := MapGen.generate_layout_valley(1)
	assert_not_null(map)
	assert_eq(map.foe_pace, LAYOUT.FOE_PACE)
	assert_eq(LAYOUT.FOE_PACE, 1.0, "off until the speed sweep chooses a number")


func test_a_spawned_foe_walks_the_paced_speed() -> void:
	for type in FOES.DEFS:
		var game := Game.create(1)
		var plain := FoeSpawner.spawn(game, type, 3, 0)
		game.map.foe_pace = 0.5
		var slow := FoeSpawner.spawn(game, type, 3, 0)
		assert_eq(slow.speed, plain.speed * 0.5, type)
		assert_eq(slow.hp, plain.hp, "only the speed moves")
		assert_eq(slow.reward, plain.reward)


func test_a_foe_takes_twice_as_long_to_walk_at_half_pace() -> void:
	var full := _walk_ticks(1.0)
	var half := _walk_ticks(0.5)
	assert_almost_eq(float(half), float(full) * 2.0, 2.0)


func test_a_slow_stacks_on_the_paced_speed() -> void:
	var game := Game.create(1)
	game.hero = null
	game.map.foe_pace = 0.5
	var foe := FoeSpawner.spawn(game, "corrugatedOrc", 1, 0)
	foe.slow = 0.5
	foe.slow_timer = 10.0
	Game.tick(game)
	assert_almost_eq(foe.distance, foe.speed * 0.5 * Game.TICK_SECONDS, 1.0e-9)


func test_a_guard_holds_a_slowed_foe() -> void:
	var game := GuardKit.game_with_tent(1)
	game.map.foe_pace = 0.5
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	GuardKit.tick(game, 60)
	assert_ne(foe.engaged_guard_id, -1, "the guard meets the foe at its slower pace")
	var held := foe.distance
	GuardKit.tick(game, 30)
	assert_eq(foe.distance, held, "a held foe does not walk")


func test_a_tower_hits_a_foe_walking_at_half_pace() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	scene.game.map.foe_pace = 0.5
	var foe := FoeSpawner.spawn(scene.game, "corrugatedOrc", 1, 0)
	foe.distance = maxf(scene.near - 0.5, 0.0)
	var at := scene.game.routes[0].position_at(foe.distance)
	foe.x = at.x
	foe.y = at.y
	var hp := foe.hp
	for i in 60:
		Game.tick(scene.game)
	assert_lt(foe.hp, hp, "tower fire reads the foe's own position, not a content speed")
