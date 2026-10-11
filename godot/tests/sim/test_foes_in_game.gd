## Foes walking the routes: the wave runner releases them, they walk, leak into
## the kingdom, and the wave ends. Ported from the prototype's spawner and mover
## with the GDD's names.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const WAVES := preload("res://content/waves.gd")
const SEED := 42


func _launched(map_seed: int = SEED) -> GameState:
	var game := Game.create(map_seed)
	GameTestKit.run(game, [Command.launch_wave()])
	return game


func _tick(game: GameState, count: int) -> void:
	for i in count:
		Game.tick(game)


## Runs until `condition` holds or `limit` ticks pass; returns the ticks run.
func _until(game: GameState, condition: Callable, limit: int = 20000) -> int:
	var ran := 0
	while ran < limit and not condition.call():
		Game.tick(game)
		ran += 1
	return ran


func _events_of(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	var out: Array[GameEvent] = []
	for event in game.events:
		if event.kind == kind:
			out.append(event)
	return out


func test_launching_a_wave_queues_its_foes() -> void:
	var game := _launched()
	assert_eq(game.spawners.size(), 1)
	assert_eq(game.spawners[0].wave, 1)
	assert_eq(game.spawners[0].queue.size(), 7, "wave 1 holds 7 foes")


func test_the_first_foe_appears_after_the_first_spawn_delay() -> void:
	var game := _launched()
	# 0.2 s is 6 ticks of 1/30 s; the wave was queued in the launching tick
	_tick(game, 4)
	assert_eq(game.foes.size(), 0, "not yet")
	var ticks := _until(game, func() -> bool: return game.foes.size() > 0, 20)
	assert_lte(ticks, 4, "it came by the 8th tick")
	assert_eq(game.foes[0].type, "scrapGoblin")


func test_a_foe_starts_on_the_spawn_point_with_its_wave_stats() -> void:
	var game := _launched()
	_until(game, func() -> bool: return game.foes.size() > 0, 40)
	var foe := game.foes[0]
	var stats := FoeStats.for_wave("scrapGoblin", 1)
	assert_eq(foe.hp, stats.hp)
	assert_eq(foe.max_hp, stats.hp)
	assert_eq(foe.speed, stats.speed)
	assert_eq(foe.reward, stats.reward)
	assert_eq(foe.armor, stats.armor)
	assert_eq(foe.leak, 1)
	assert_true(foe.alive)
	# on the spawn point it has walked at most one tick
	var route := game.routes[foe.route]
	var start := route.position_at(0.0)
	assert_almost_eq(foe.x, start.x, 0.1)
	assert_almost_eq(foe.y, start.y, 0.1)


func test_foes_come_out_in_order_with_the_waves_gaps() -> void:
	var game := _launched()
	var queue: Array[SpawnOrder] = []
	for order in game.spawners[0].queue:
		queue.append(order)
	var seen: Array[String] = []
	var ticks_at: Array[int] = []
	var guard := 0
	while seen.size() < queue.size() and guard < 5000:
		Game.tick(game)
		guard += 1
		for event in _events_of(game, GameEvent.Kind.FOE_SPAWNED):
			seen.append(event.foe_type)
			ticks_at.append(game.tick_count)
	assert_eq(seen.size(), queue.size())
	for i in queue.size():
		assert_eq(seen[i], queue[i].type, "foe %d" % i)
	# a gap of 0.54 s is 16 ticks, give or take one for the tick it lands in
	for i in range(1, ticks_at.size()):
		var expected := queue[i - 1].gap * 30.0
		assert_almost_eq(float(ticks_at[i] - ticks_at[i - 1]), expected, 1.01, "gap %d" % i)


func test_the_wave_is_done_releasing_when_the_spawner_empties() -> void:
	var game := _launched()
	_until(game, func() -> bool: return game.spawners.is_empty())
	assert_eq(game.spawners.size(), 0)


func test_foes_walk_the_route_at_their_speed() -> void:
	var game := _launched()
	_until(game, func() -> bool: return game.foes.size() > 0, 40)
	var foe := game.foes[0]
	var before := foe.distance
	var guard := Game.TICK_SECONDS
	_tick(game, 30)
	# one second of walking, a little less if a slow applied (none yet)
	assert_almost_eq(foe.distance - before, foe.speed * 30.0 * guard, 1e-9)
	var at := game.routes[foe.route].position_at(foe.distance)
	assert_almost_eq(foe.x, at.x, 1e-9)
	assert_almost_eq(foe.y, at.y, 1e-9)


func test_a_foe_that_reaches_the_end_leaks_and_leaves() -> void:
	var game := _launched()
	var start_health := game.kingdom_health
	_until(game, func() -> bool: return game.kingdom_health < start_health)
	assert_lt(game.kingdom_health, start_health)
	# the goblin that got through cost 1
	assert_eq(game.kingdom_health, start_health - 1)


func test_a_leak_is_an_event_and_the_foe_is_gone() -> void:
	var game := _launched()
	var found := false
	for i in 20000:
		Game.tick(game)
		var leaks := _events_of(game, GameEvent.Kind.FOE_LEAKED)
		if not leaks.is_empty():
			found = true
			assert_eq(leaks[0].leak, 1)
			for foe in game.foes:
				assert_ne(foe.id, leaks[0].foe_id, "the leaked foe is removed")
			break
	assert_true(found)


func test_the_game_ends_when_the_kingdom_has_no_health_left() -> void:
	var game := _launched()
	game.kingdom_health = 1
	_until(game, func() -> bool: return game.over)
	assert_true(game.over)
	assert_eq(game.kingdom_health, 0, "health stops at 0")
	var over := false
	for i in 3:
		Game.tick(game)
	# the event came on the tick it happened; commands are now turned away
	var command := Command.launch_wave()
	var events := GameTestKit.run(game, [command])
	assert_eq(events[0].reason, GameEvent.RejectReason.GAME_OVER)
	assert_false(over)


func test_game_over_is_announced_once_with_the_wave() -> void:
	var game := _launched()
	game.kingdom_health = 1
	var announced := 0
	for i in 20000:
		Game.tick(game)
		for event in _events_of(game, GameEvent.Kind.GAME_OVER):
			announced += 1
			assert_eq(event.wave, 1)
		if game.over:
			break
	_tick(game, 5)
	assert_eq(announced, 1)


func test_nothing_moves_once_the_game_is_over() -> void:
	var game := _launched()
	game.kingdom_health = 1
	_until(game, func() -> bool: return game.over)
	var distances: Array[float] = []
	for foe in game.foes:
		distances.append(foe.distance)
	_tick(game, 10)
	for i in game.foes.size():
		assert_eq(game.foes[i].distance, distances[i])


func test_a_cleared_wave_pays_its_bonus_once() -> void:
	var game := _launched()
	game.kingdom_health = 1000
	var before := game.buttons
	var bonus := 0
	var cleared := 0
	for i in 20000:
		Game.tick(game)
		for event in _events_of(game, GameEvent.Kind.WAVE_CLEARED):
			cleared += 1
			bonus = event.bonus
			assert_eq(event.wave, 1)
		if not game.running:
			break
	_tick(game, 30)
	assert_eq(cleared, 1)
	# 15 + 1 * 2
	assert_eq(bonus, 17)
	assert_eq(game.buttons, before + 17)
	assert_false(game.running)


func test_the_wave_is_not_cleared_while_foes_are_still_on_the_board() -> void:
	var game := _launched()
	game.kingdom_health = 1000
	_until(game, func() -> bool: return game.spawners.is_empty())
	assert_gt(game.foes.size(), 0, "some foes are still walking when the last one is out")
	assert_true(game.running)


func test_calling_the_next_wave_early_pays_the_early_bonus() -> void:
	var game := _launched()
	game.kingdom_health = 1000
	_until(game, func() -> bool: return game.spawners.is_empty())
	var before := game.buttons
	var events := GameTestKit.run(game, [Command.launch_wave()])
	var launched := _events_of(game, GameEvent.Kind.WAVE_LAUNCHED)
	assert_eq(launched.size(), 1)
	# 10 + 1 * 2 (the wave number before the call)
	assert_eq(launched[0].early_bonus, 12)
	assert_eq(game.buttons, before + 12)
	assert_eq(game.wave, 2)
	assert_eq(events.size() > 0, true)


func test_a_wave_cannot_be_called_while_foes_are_still_being_released() -> void:
	var game := _launched()
	_tick(game, 2)
	var command := Command.launch_wave()
	var events := GameTestKit.run(game, [command])
	assert_eq(events.size(), 1)
	assert_eq(events[0].reason, GameEvent.RejectReason.WAVE_IN_PROGRESS)
	assert_eq(game.wave, 1)


func test_with_two_routes_foes_use_both_and_one_draw_per_foe() -> void:
	# find a seed whose map has a detour
	var game: GameState = null
	for map_seed in range(1, 40):
		var candidate := Game.create(map_seed)
		if candidate.routes.size() == 2:
			game = candidate
			break
	assert_not_null(game, "a map with a detour exists")
	game.kingdom_health = 100000
	GameTestKit.run(game, [Command.launch_wave()])
	var state_before := game.route_rng.state
	_until(game, func() -> bool: return game.spawners.is_empty())
	var used := {}
	for foe in game.foes:
		used[foe.route] = true
	# 7 foes in wave 1 drew 7 route numbers
	var expected := Rng.derive(game.seed, Streams.ROUTES)
	for i in 7:
		expected.next_int(2)
	assert_eq(game.route_rng.state, expected.state)
	assert_ne(game.route_rng.state, state_before)


func test_with_one_route_the_route_stream_is_not_touched() -> void:
	var game: GameState = null
	for map_seed in range(1, 80):
		var candidate := Game.create(map_seed)
		if candidate.routes.size() == 1:
			game = candidate
			break
	assert_not_null(game, "a map without a detour exists")
	GameTestKit.run(game, [Command.launch_wave()])
	var state := game.route_rng.state
	_until(game, func() -> bool: return game.spawners.is_empty())
	assert_eq(game.route_rng.state, state)


func test_the_same_seed_and_commands_give_the_same_game() -> void:
	var a := Game.create(7)
	var b := Game.create(7)
	for game in [a, b]:
		game.kingdom_health = 100000
		GameTestKit.run(game, [Command.launch_wave()])
		_tick(game, 400)
	assert_eq(GameTestKit.snapshot(a), GameTestKit.snapshot(b))
	assert_gt(a.foes.size(), 0)
