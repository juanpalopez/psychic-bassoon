## The Guard Tent: it raises two guards at a post on the road, built, upgraded and
## sold like any tower.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func test_the_guard_tent_is_content_with_three_levels() -> void:
	var def: Dictionary = TOWERS.DEFS.guardTent
	assert_eq(def.name, "Guard Tent")
	assert_true(def.guards)
	assert_eq(def.cost, [55, 65, 110])
	assert_eq(def.guard_hp, [120, 200, 320])
	assert_eq(def.guard_armor, [0, 2, 4])
	assert_eq(def.guard_damage, [16, 28, 48])
	assert_eq(def.respawn, [6, 5, 4])
	assert_eq(def.guard_count, 2)


func test_a_new_tent_raises_two_guards_at_full_health() -> void:
	var game := Game.create(1)
	game.buttons = 500
	var anchor := game.map.sockets[0]
	var events := GameTestKit.run(game, [Command.build("guardTent", anchor.x, anchor.y)])
	assert_eq(game.guards.size(), 2)
	for guard in game.guards:
		assert_eq(guard.hp, 120.0)
		assert_eq(guard.max_hp, 120.0)
		assert_true(guard.alive)
		assert_eq(guard.tent_id, game.towers[0].id)
	assert_eq(game.buttons, 445)
	var raised := 0
	for event in events:
		if event.kind == GameEvent.Kind.GUARD_RAISED:
			raised += 1
	assert_eq(raised, 2)


func test_other_towers_raise_no_guards() -> void:
	var game := Game.create(1)
	var anchor := game.map.sockets[0]
	GameTestKit.run(game, [Command.build("spoolGuard", anchor.x, anchor.y)])
	assert_eq(game.guards.size(), 0)


func test_the_two_guards_stand_half_a_cell_apart_on_the_road_nearest_the_tent() -> void:
	for map_seed in [1, 7, 42]:
		var game := GuardKit.game_with_tent(map_seed)
		var a: Guard = game.guards[0]
		var b: Guard = game.guards[1]
		assert_almost_eq(b.post - a.post, 0.5, 1e-9, "seed %d" % map_seed)
		var tent := GuardKit.tent(game)
		var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
		var at := game.routes[0].position_at(GuardKit.post(game))
		var best := 1.0e9
		var along := 0.0
		while along < game.routes[0].total:
			var p := game.routes[0].position_at(along)
			best = minf(best, centre.distance_to(Vector2(p.x, p.y)))
			along += 0.01
		assert_lt(centre.distance_to(Vector2(at.x, at.y)), best + 0.06, "seed %d" % map_seed)


func test_upgrading_the_tent_makes_the_guards_tougher_and_heals_the_gain() -> void:
	var game := GuardKit.game_with_tent()
	game.guards[0].hp = 30.0
	GameTestKit.run(game, [Command.upgrade(GuardKit.tent(game).id)])
	assert_eq(game.guards[0].max_hp, 200.0)
	# 30 hp plus the 80 the level adds, plus a tick of regeneration (1.5 hp a second)
	assert_almost_eq(game.guards[0].hp, 110.0, 0.1)
	assert_eq(game.guards[1].hp, 200.0)
	assert_eq(game.guards[0].armor, 2)
	assert_eq(game.guards[0].damage, 28.0)


func test_selling_the_tent_removes_its_guards_and_frees_the_foe_they_held() -> void:
	var game := GuardKit.game_with_tent()
	var orc := GuardKit.foe_before_post(game, "corrugatedOrc", 0.3)
	GuardKit.tick(game, 3)
	assert_ne(orc.engaged_guard_id, -1, "the orc is held")
	GameTestKit.run(game, [Command.sell(GuardKit.tent(game).id)])
	assert_eq(game.guards.size(), 0)
	assert_eq(orc.engaged_guard_id, -1)


func test_a_tent_that_dies_with_the_game_state_is_plain_data() -> void:
	var game := GuardKit.game_with_tent()
	var snap := GameTestKit.snapshot(game)
	assert_eq(snap.guards.size(), 2)
	assert_true(JSON.stringify(snap).length() > 0)


func test_when_two_road_points_tie_the_post_is_the_one_nearer_the_heartstone() -> void:
	var tied := _tied_socket(1)
	assert_ne(tied, Vector2i(-1, -1), "seed 1 has a tent socket with two equally near road points")
	var game := Game.create(1)
	game.buttons = 500
	GameTestKit.run(game, [Command.build("guardTent", tied.x, tied.y)])
	var middle := GuardKit.post(game)
	assert_almost_eq(middle, _last_nearest_along(game, tied), 1e-9)
	assert_gt(_last_nearest_along(game, tied) - _first_nearest_along(game, tied), 0.5)


## A socket of the seed's map with two exactly equally near road points.
func _tied_socket(map_seed: int) -> Vector2i:
	var game := Game.create(map_seed)
	for anchor in game.map.sockets:
		if _first_nearest_along(game, anchor) != _last_nearest_along(game, anchor):
			return anchor
	return Vector2i(-1, -1)


func _first_nearest_along(game: GameState, anchor: Vector2i) -> float:
	return _nearest_alongs(game, anchor)[0]


func _last_nearest_along(game: GameState, anchor: Vector2i) -> float:
	var all := _nearest_alongs(game, anchor)
	return all[all.size() - 1]


## Every point (0.05 apart, found by index) at the least distance from the block.
func _nearest_alongs(game: GameState, anchor: Vector2i) -> Array[float]:
	var route := game.routes[0]
	var centre := game.map.socket_centre(anchor)
	var best := INF
	var found: Array[float] = []
	for i in int(floor(route.total / 0.05)) + 1:
		var at := route.position_at(float(i) * 0.05)
		var squared := (at.x - centre.x) * (at.x - centre.x) + (at.y - centre.y) * (at.y - centre.y)
		if squared < best:
			best = squared
			found = [float(i) * 0.05]
		elif squared == best:
			found.append(float(i) * 0.05)
	return found
