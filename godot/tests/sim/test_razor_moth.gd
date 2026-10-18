## The Razor Moth: a flying foe that crosses the board in a straight line to the Heartstone,
## no guard can hold, and only anti-air towers can hit.
extends GutTest

const FOES := preload("res://content/foes.gd")
const TOWERS := preload("res://content/towers.gd")


func _game() -> GameState:
	var game := Game.create(1)
	game.heartstone_health = 100
	return game


func test_the_moth_is_a_flying_unblockable_foe() -> void:
	assert_true(FOES.FOE_IDS.has("razorMoth"))
	var def: Dictionary = FOES.DEFS.razorMoth
	assert_eq(def.name, "Razor Moth")
	assert_true(def.flying)
	assert_false(def.blockable)
	assert_lt(def.hp, FOES.DEFS.corrugatedOrc.hp)


func test_a_spawned_moth_flies_and_the_ground_routes_are_untouched() -> void:
	var game := _game()
	var routes := game.routes.size()
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	assert_true(moth.flying)
	assert_false(FoeSpawner.spawn(game, "scrapGoblin", 1, 0).flying)
	assert_eq(game.routes.size(), routes)
	assert_eq(game.air_routes.size(), routes, "one flight line per source")


func test_the_flight_line_runs_from_the_spawn_to_the_middle_of_the_heartstone() -> void:
	var game := _game()
	var air := game.air_routes[0]
	var ground := game.routes[0]
	var start := ground.position_at(0.0)
	assert_almost_eq(air.xs[0], start.x, 1e-9)
	assert_almost_eq(air.ys[0], start.y, 1e-9)
	var block := game.map.heartstone
	var end := air.position_at(air.total)
	assert_almost_eq(end.x, float(block.position.x) + float(block.size.x) / 2.0, 1e-9)
	assert_almost_eq(end.y, float(block.position.y) + float(block.size.y) / 2.0, 1e-9)
	assert_lt(air.total, ground.total, "straight is shorter than the road")


func test_the_moth_flies_at_its_speed_in_a_straight_line() -> void:
	var game := _game()
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	var first := Vector2(moth.x, moth.y)
	Game.tick(game)
	Game.tick(game)
	var second := Vector2(moth.x, moth.y)
	Game.tick(game)
	var third := Vector2(moth.x, moth.y)
	assert_almost_eq(moth.distance, moth.speed * Game.TICK_SECONDS * 3.0, 1e-9)
	var one := second - first
	var two := third - second
	assert_almost_eq(one.cross(two), 0.0, 1e-6, "collinear")


func test_a_moth_that_arrives_hurts_the_heartstone_and_leaves() -> void:
	var game := _game()
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.distance = game.air_routes[0].total - 0.01
	var before := game.heartstone_health
	Game.tick(game)
	assert_false(moth.alive)
	assert_eq(game.heartstone_health, before - moth.leak)


func test_a_guard_does_not_hold_a_moth() -> void:
	var game := GuardKit.game_with_tent(1)
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.distance = GuardKit.post(game) - 0.1
	GuardKit.tick(game, 1)
	assert_eq(moth.engaged_guard_id, -1)


func test_spool_guard_and_prism_spire_are_anti_air_and_the_mortar_is_not() -> void:
	assert_true(TOWERS.DEFS.spoolGuard.anti_air)
	assert_true(TOWERS.DEFS.prismSpire.anti_air)
	assert_false(TOWERS.DEFS.thimbleMortar.get("anti_air", false))


func _moth_at_the_tower(scene: TowerFireKit.Scene) -> Foe:
	var game: GameState = scene.game
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	var centre := game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	moth.x = centre.x
	moth.y = centre.y
	return moth


func test_an_anti_air_tower_can_pick_a_moth() -> void:
	for type in ["spoolGuard", "prismSpire"]:
		var scene := TowerFireKit.scene(type)
		var moth := _moth_at_the_tower(scene)
		assert_eq(TowerFire.target_for(scene.game, scene.tower), moth, type)


func test_the_mortar_cannot_pick_a_moth_but_still_picks_the_ground_foe() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var moth := _moth_at_the_tower(scene)
	assert_null(TowerFire.target_for(scene.game, scene.tower))
	var goblin := TowerFireKit.foe(scene.game, scene.near)
	assert_eq(TowerFire.target_for(scene.game, scene.tower), goblin)
	assert_ne(goblin, moth)


func test_a_mortar_shell_does_not_hurt_a_moth_in_the_blast() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var goblin := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
	var moth := FoeSpawner.spawn(scene.game, "razorMoth", 1, 0)
	moth.x = goblin.x
	moth.y = goblin.y
	TowerFire._fire(scene.game, scene.tower, TOWERS.DEFS.thimbleMortar, goblin)
	assert_lt(goblin.hp, goblin.max_hp)
	assert_eq(moth.hp, moth.max_hp)


func test_a_beam_locks_a_moth_in_reach() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	var moth := _moth_at_the_tower(scene)
	TowerFire._beam(scene.game, scene.tower, TOWERS.DEFS.prismSpire)
	assert_eq(scene.tower.target_id, moth.id)
	assert_lt(moth.hp, moth.max_hp)


func test_an_air_foe_is_ranked_by_the_distance_left_on_its_own_line() -> void:
	# on the 16 by 11 board's map 1 the moth's line is short beside the road
	var scene := TowerFireKit.scene("spoolGuard", 1, false, TowerFireKit.landscape())
	var game: GameState = scene.game
	var goblin := TowerFireKit.foe(game, scene.near)
	var moth := _moth_at_the_tower(scene)
	# one cell into its short line the moth has less left to fly than the goblin has to walk;
	# measured on the ground road's length it would look the further one
	moth.distance = 1.0
	assert_lt(game.air_routes[0].total - moth.distance, game.routes[0].total - goblin.distance)
	assert_gt(
		game.routes[0].total - moth.distance,
		game.routes[0].total - goblin.distance,
		"on the ground road's length the moth would look the further one"
	)
	assert_eq(TowerFire.target_for(game, scene.tower), moth)


func test_a_lock_on_a_moth_is_dropped_by_a_tower_that_cannot_hit_air() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var moth := _moth_at_the_tower(scene)
	scene.tower.target_id = moth.id
	assert_null(TowerFire._locked_foe(scene.game, scene.tower))


func test_support_first_and_anti_air_work_together() -> void:
	# the 16 by 11 board's map 1, where the moth at the start of its line has the least left
	var spool := TowerFireKit.scene("spoolGuard", 1, false, TowerFireKit.landscape())
	var game: GameState = spool.game
	var goblin := TowerFireKit.foe(game, spool.near)
	var moth := _moth_at_the_tower(spool)
	var shaman := TowerFireKit.foe(game, spool.near - 0.2, "inkShaman")
	assert_eq(TowerFire.target_for(game, spool.tower), shaman, "a Spool Guard: the shaman first")
	shaman.alive = false
	assert_eq(
		TowerFire.target_for(game, spool.tower).id, moth.id, "then the foe left to walk least"
	)
	var mortar := TowerFireKit.scene("thimbleMortar", 1, false, TowerFireKit.landscape())
	var mortar_goblin := TowerFireKit.foe(mortar.game, mortar.near)
	_moth_at_the_tower(mortar)
	var mortar_shaman := TowerFireKit.foe(mortar.game, mortar.near - 0.2, "inkShaman")
	assert_eq(
		TowerFire.target_for(mortar.game, mortar.tower), mortar_shaman, "a Mortar: the shaman"
	)
	mortar_shaman.alive = false
	assert_eq(TowerFire.target_for(mortar.game, mortar.tower), mortar_goblin, "never the moth")
	assert_ne(goblin, moth)
