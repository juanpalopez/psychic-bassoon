## When towers fire: their rate, and where they sit in the tick (foes walk first).
extends GutTest


func test_the_spool_guard_fires_every_10_ticks_at_3_shots_a_second() -> void:
	var scene := TowerFireKit.scene()
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	# 30 ticks a second at 3 shots a second is exactly 10 ticks apart
	assert_eq(
		TowerFireKit.shot_ticks(scene, foe, 90), [0, 10, 20, 30, 40, 50, 60, 70, 80] as Array[int]
	)


func test_a_rate_that_does_not_divide_the_tick_averages_out() -> void:
	var scene := TowerFireKit.scene()
	scene.game.buttons = 1000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(scene.tower.level, 1)
	scene.tower.cooldown = 0.0
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	# 3.6 shots a second is 8.33 ticks: 9, 8, 8 ticks apart, repeating, so 11 shots
	# in 3 seconds (the carried remainder keeps the average at the content's rate)
	var expected: Array[int] = [0, 9, 17, 25, 34, 42, 50, 59, 67, 75, 84]
	assert_eq(TowerFireKit.shot_ticks(scene, foe, 90), expected)


func test_an_upgrade_speeds_the_rate_up() -> void:
	var scene := TowerFireKit.scene()
	scene.game.buttons = 1000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(scene.tower.level, 2)
	scene.tower.cooldown = 0.0
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	# 4.5 shots a second: 7, 7, 6 ticks apart, repeating
	var expected: Array[int] = [0, 7, 14, 20, 27, 34, 40, 47, 54, 60, 67, 74, 80, 87]
	assert_eq(TowerFireKit.shot_ticks(scene, foe, 90), expected)


func test_a_tower_that_waited_for_a_target_fires_at_once_with_no_head_start() -> void:
	var scene := TowerFireKit.scene()
	for i in 25:
		Game.tick(scene.game)
	assert_eq(scene.tower.cooldown, 0.0, "an idle tower's cooldown stays at 0")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	assert_eq(TowerFireKit.shot_ticks(scene, foe, 30), [0, 10, 20] as Array[int])


func test_foes_move_first_so_the_shot_lands_where_the_foe_now_stands() -> void:
	var scene := TowerFireKit.scene()
	var foe := TowerFireKit.foe(scene.game, scene.near - 0.5, "cardboardGolem")
	foe.speed = 1.9
	var before := Vector2(foe.x, foe.y)
	Game.tick(scene.game)
	var shots := TowerFireKit.kinds(scene.game, GameEvent.Kind.TOWER_FIRED)
	assert_eq(shots.size(), 1)
	assert_ne(Vector2(foe.x, foe.y), before, "the foe walked")
	assert_eq([shots[0].x, shots[0].y], [foe.x, foe.y], "aimed after the walk")


func test_a_foe_that_walks_off_the_end_this_tick_leaks_before_a_tower_can_shoot_it() -> void:
	var scene := TowerFireKit.scene("spoolGuard", 1, true)
	# the Heartstone keeps its footprint clear, so the nearest block is a little
	# further than a level 1 tower reaches: level 3 reaches it
	scene.tower.level = 2
	assert_lt(scene.gap, TowerFire.reach_of(scene.game, scene.tower), "within reach of the end")
	var route := scene.game.routes[0]
	var foe := TowerFireKit.foe(scene.game, route.total - 0.01)
	foe.speed = 1.9
	foe.hp = 1.0
	var health := scene.game.heartstone_health
	var buttons := scene.game.buttons
	Game.tick(scene.game)
	assert_eq(scene.game.heartstone_health, health - foe.leak)
	assert_eq(scene.game.buttons, buttons, "no reward for a foe that got through")
	assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.FOE_LEAKED).size(), 1)
	assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.TOWER_FIRED).size(), 0)


func test_reach_includes_its_exact_edge_and_nothing_beyond() -> void:
	var game := Game.create(1)
	var foe := TowerFireKit.foe(game, 0.0)
	# a 3-4-5 triangle: exactly 5 cells from the origin
	foe.x = 3.0
	foe.y = 4.0
	assert_eq(TowerFire.foes_within(game, 0.0, 0.0, 5.0), [foe] as Array[Foe])
	assert_eq(TowerFire.foes_within(game, 0.0, 0.0, 4.999), [] as Array[Foe])
