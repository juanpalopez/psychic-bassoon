## The Thimble Mortar's actives and pools: who they reach (never a flyer), how Frostbite joins
## them, how a pool's slow gets along with other slows, and the zone events.
extends GutTest

const SPECS := preload("res://content/specs.gd")
const RULES := preload("res://content/game_rules.gd")

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


func _moth_at(game: GameState, foe: Foe) -> Foe:
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.hp = 1.0e9
	moth.max_hp = 1.0e9
	moth.x = foe.x
	moth.y = foe.y
	return moth


func test_confetti_burst_does_not_touch_a_flyer_in_the_blast() -> void:
	var scene := _scene(GLITTER)
	var game := scene.game
	var target := _tough(game, scene.near)
	var moth := _moth_at(game, target)
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_lt(target.hp, target.max_hp)
	assert_eq(moth.hp, moth.max_hp, "a mortar cannot hurt a flyer, even with its active")
	assert_eq(moth.blind, 0.0)


func test_pva_deluge_does_not_slow_a_flyer_in_the_area() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var target := _tough(game, scene.near)
	var moth := _moth_at(game, target)
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_gt(target.slow, 0.0)
	assert_eq(moth.slow, 0.0)


func test_frostbite_adds_to_confetti_burst_damage_on_a_frozen_foe() -> void:
	var scene := _scene(GLITTER)
	var game := scene.game
	var spire := Tower.new()
	spire.id = 905
	spire.type = "prismSpire"
	spire.level = 2
	spire.spec = "cryoOrigamiSpire"
	spire.col = scene.tower.col
	spire.row = scene.tower.row
	game.towers.append(spire)
	var bonus: float = SPECS.find("prismSpire", "cryoOrigamiSpire").passive.bonus
	var active: Dictionary = SPECS.find("thimbleMortar", GLITTER).active
	var cold := _tough(game, scene.near)
	cold.freeze_timer = 3.0
	# fired directly, so the spire's own beam adds nothing in a tick
	assert_true(Specs._confetti_burst(game, scene.tower, active))
	# the frozen target stood still; its armor off the 60, then the bonus
	assert_almost_eq(
		cold.max_hp - cold.hp, (float(active.damage) - float(cold.armor)) * (1.0 + bonus), 1e-3
	)


func test_a_pool_leaves_a_longer_slow_alone_and_never_shortens_it() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var target := _tough(game, scene.near)
	target.speed = 0.0
	scene.tower.cooldown = 0.0
	Game.tick(game)
	scene.tower.cooldown = 1000.0
	# a slow as strong as the pool's with a long timer, applied after the pool opened
	Status.apply_slow(target, 0.35, 6.0)
	Game.tick(game)
	Game.tick(game)
	assert_gt(target.slow_timer, RULES.POOL_REFRESH_SECONDS, "the long slow was not cut down")


func test_zone_events_carry_the_zone_id_and_kind_and_pair_up() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var target := _tough(game, scene.near)
	target.speed = 0.0
	scene.tower.cooldown = 0.0
	Game.tick(game)
	var opened := TowerFireKit.kinds(game, GameEvent.Kind.ZONE_OPENED)
	assert_eq(opened.size(), 1)
	assert_eq(opened[0].zone_kind, "pool")
	assert_eq(opened[0].zone_id, game.zones[0].id)
	scene.tower.cooldown = 1000.0
	var closed: Array[GameEvent] = []
	for i in 140:
		Game.tick(game)
		closed.append_array(TowerFireKit.kinds(game, GameEvent.Kind.ZONE_CLOSED))
	assert_eq(closed.size(), 1)
	assert_eq(closed[0].zone_id, opened[0].zone_id)
	assert_eq(closed[0].zone_kind, "pool")


func test_a_foe_exactly_on_a_pools_edge_is_slowed() -> void:
	var scene := _scene(GLUE)
	var game := scene.game
	var target := _tough(game, scene.near)
	target.speed = 0.0
	Zones.open_pool(game, scene.tower, target, 1.0, 0.35, 4.0)
	var edge := _tough(game, scene.near)
	edge.speed = 0.0
	edge.x = target.x + 1.0
	edge.y = target.y
	Zones.step(game)
	assert_gt(edge.slow, 0.0)
