## The Cardboard Golem splits into Scrap Goblins when it is destroyed (GDD): four
## of them, on its route, a little behind where it fell. Nothing splits when a foe
## leaks, and no random number is drawn.
extends GutTest

const FOES := preload("res://content/foes.gd")


func _golem(game: GameState, wave: int = 10, along: float = 12.0) -> Foe:
	var golem := FoeSpawner.spawn(game, "cardboardGolem", wave, 0)
	golem.speed = 0.0
	golem.distance = along
	var at := game.routes[0].position_at(along)
	golem.x = at.x
	golem.y = at.y
	game.events = []
	return golem


func _kill(game: GameState, foe: Foe) -> void:
	foe.hp = 1.0
	Damage.apply(game, foe, 5.0, Damage.Kind.TRUE)


func _goblins(game: GameState) -> Array[Foe]:
	var found: Array[Foe] = []
	for foe in game.foes:
		if foe.type == "scrapGoblin" and foe.alive:
			found.append(foe)
	return found


func test_the_content_says_how_many_and_how_far_apart() -> void:
	var def: Dictionary = FOES.DEFS.cardboardGolem
	assert_eq(def.splits_into, "scrapGoblin")
	assert_eq(def.split_count, 4)
	assert_gt(def.split_spacing, 0.0)
	assert_false(FOES.DEFS.scrapGoblin.has("splits_into"))
	assert_false(FOES.DEFS.corrugatedOrc.has("splits_into"))


func test_every_foe_that_splits_says_how_many_and_how_far_apart() -> void:
	for id in FOES.FOE_IDS:
		var def: Dictionary = FOES.DEFS[id]
		if def.has("splits_into"):
			assert_true(FOES.DEFS.has(def.splits_into), "%s splits into a known foe" % id)
			assert_gt(int(def.get("split_count", 0)), 0, "%s needs split_count" % id)
			assert_gt(float(def.get("split_spacing", 0.0)), 0.0, "%s needs split_spacing" % id)


func test_a_foe_knows_the_wave_it_came_in() -> void:
	var game := Game.create_on_strip_valley(1)
	assert_eq(FoeSpawner.spawn(game, "scrapGoblin", 7, 0).wave, 7)


func test_a_destroyed_golem_leaves_four_goblins() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game)
	_kill(game, golem)
	assert_false(golem.alive)
	assert_eq(_goblins(game).size(), 4)


func test_the_goblins_stand_on_the_golems_route_a_little_apart_behind_it() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game, 10, 12.0)
	_kill(game, golem)
	var spacing: float = FOES.DEFS.cardboardGolem.split_spacing
	var goblins := _goblins(game)
	for i in goblins.size():
		assert_eq(goblins[i].route, golem.route)
		assert_almost_eq(goblins[i].distance, 12.0 - float(i) * spacing, 1e-9, "goblin %d" % i)
		var at := game.routes[0].position_at(goblins[i].distance)
		assert_eq([goblins[i].x, goblins[i].y], [at.x, at.y])


func test_a_golem_near_the_start_does_not_put_goblins_before_the_start() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game, 10, 0.5)
	_kill(game, golem)
	for goblin in _goblins(game):
		assert_gte(goblin.distance, 0.0)


func test_the_goblins_have_the_strength_of_the_golems_wave() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game, 20, 12.0)
	game.wave = 30
	_kill(game, golem)
	var expected := FoeStats.for_wave("scrapGoblin", 20)
	for goblin in _goblins(game):
		assert_eq(goblin.max_hp, float(expected.hp))
		assert_eq(goblin.speed, expected.speed)
		assert_eq(goblin.reward, expected.reward)
		assert_eq(goblin.wave, 20)


func test_the_goblins_are_reported_after_the_kill_and_take_the_next_ids() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game)
	var next := game.next_id
	_kill(game, golem)
	var kinds: Array[int] = []
	for event in game.events:
		kinds.append(event.kind)
	var spawned := GameEvent.Kind.FOE_SPAWNED
	assert_eq(kinds, [GameEvent.Kind.FOE_KILLED, spawned, spawned, spawned, spawned])
	for i in 4:
		assert_eq(game.events[1 + i].foe_id, next + i)
		assert_eq(game.events[1 + i].foe_type, "scrapGoblin")
		assert_eq(game.events[1 + i].wave, 10)


func test_the_kill_pays_the_golems_reward_once() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game)
	var before := game.buttons
	_kill(game, golem)
	assert_eq(game.buttons, before + golem.reward)
	_kill(game, golem)
	assert_eq(game.buttons, before + golem.reward, "a fallen golem does not split or pay twice")
	assert_eq(_goblins(game).size(), 4)


## A guard for the future: a leaking foe never goes through `Damage`, so nothing
## splits on the leak path today.
func test_a_golem_that_leaks_splits_nothing() -> void:
	var game := Game.create_on_strip_valley(1)
	var golem := _golem(game, 10, game.routes[0].total - 0.01)
	golem.speed = 1.0
	Game.tick(game)
	assert_false(golem.alive)
	assert_eq(_goblins(game).size(), 0)
	for foe in game.foes:
		assert_ne(foe.type, "scrapGoblin")


func test_other_foes_split_nothing() -> void:
	var game := Game.create_on_strip_valley(1)
	for type in ["scrapGoblin", "corrugatedOrc"]:
		var foe := FoeSpawner.spawn(game, type, 5, 0)
		var before := game.foes.size()
		foe.hp = 1.0
		Damage.apply(game, foe, 5.0, Damage.Kind.TRUE)
		assert_eq(game.foes.size(), before, type)


func test_the_wave_is_not_cleared_while_the_goblins_live() -> void:
	var game := Game.create_on_strip_valley(1)
	game.running = true
	game.wave = 10
	var golem := _golem(game)
	_kill(game, golem)
	Game.tick(game)
	for event in game.events:
		assert_ne(event.kind, GameEvent.Kind.WAVE_CLEARED)
	assert_true(game.running)
	for goblin in _goblins(game):
		goblin.hp = 1.0
		Damage.apply(game, goblin, 5.0, Damage.Kind.TRUE)
	Game.tick(game)
	assert_false(game.running, "the wave is over once the goblins are gone")


func test_a_split_draws_no_random_numbers_even_with_two_routes() -> void:
	var game := Game.create(1, 9, 13, true, 1)
	assert_gt(game.routes.size(), 1)
	var golem := FoeSpawner.spawn(game, "cardboardGolem", 10, 1)
	golem.speed = 0.0
	var waves := game.rng.state
	var routes := game.route_rng.state
	_kill(game, golem)
	assert_eq(game.rng.state, waves)
	assert_eq(game.route_rng.state, routes)
	for goblin in _goblins(game):
		assert_eq(goblin.route, 1, "they keep the golem's route")


func test_a_mortar_shell_that_kills_the_golem_does_not_hit_the_goblins_it_makes() -> void:
	var game := Game.create_on_strip_valley(1)
	var scene := TowerFireKit.scene("thimbleMortar", 1, false, game)
	var golem := _golem(game, 10, scene.near)
	golem.hp = 1.0
	var orc := FoeSpawner.spawn(game, "corrugatedOrc", 10, 0)
	orc.speed = 0.0
	orc.distance = scene.near - 0.1
	var at := game.routes[0].position_at(orc.distance)
	orc.x = at.x
	orc.y = at.y
	scene.tower.cooldown = 0.0
	TowerFire.step(game)
	assert_false(golem.alive, "the shell killed the golem")
	assert_lt(orc.hp, orc.max_hp, "and hurt the orc beside it")
	var goblins := _goblins(game)
	assert_eq(goblins.size(), 4)
	for goblin in goblins:
		assert_eq(goblin.hp, goblin.max_hp, "the new goblins were not in the blast")
