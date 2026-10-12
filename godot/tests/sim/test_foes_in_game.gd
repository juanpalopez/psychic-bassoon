## Foes walking the routes: the wave runner releases them, they walk, leak into
## the Heartstone, and the wave ends. Ported from the prototype's spawner and mover
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


func test_the_first_foe_appears_on_the_tick_the_spawn_delay_runs_out() -> void:
	var game := _launched()
	# the launching tick already took one tick off the 0.2 s delay; count the
	# ticks with the same float arithmetic, written out here
	var timer: float = WAVES.FIRST_SPAWN_DELAY
	var expected := 0
	while timer > 0.0:
		timer -= Game.TICK_SECONDS
		expected += 1
	assert_eq(expected, 7, "repeated 1/30 s steps leave 0.2 a hair above 0 after 6")
	var spawned_at := -1
	while spawned_at < 0 and game.tick_count < 40:
		Game.tick(game)
		if not _events_of(game, GameEvent.Kind.FOE_SPAWNED).is_empty():
			spawned_at = game.tick_count
	assert_eq(spawned_at, expected)
	assert_eq(game.foes[0].type, "scrapGoblin")


func test_a_foe_starts_with_its_wave_stats_and_walks_on_its_spawn_tick() -> void:
	var game := _launched()
	while game.foes.is_empty():
		Game.tick(game)
	var foe := game.foes[0]
	var stats := FoeStats.for_wave("scrapGoblin", 1)
	assert_eq(foe.hp, float(stats.hp))
	assert_eq(foe.max_hp, float(stats.hp))
	assert_eq(foe.speed, stats.speed)
	assert_eq(foe.reward, stats.reward)
	assert_eq(foe.armor, stats.armor)
	assert_eq(foe.leak, 1)
	assert_true(foe.alive)
	# spawners run before the foes move, so a foe walks one tick on the tick it spawns
	assert_eq(foe.distance, foe.speed * Game.TICK_SECONDS)
	var at := game.routes[foe.route].position_at(foe.distance)
	assert_eq(foe.x, at.x)
	assert_eq(foe.y, at.y)


func test_foes_come_out_in_order_on_the_exact_ticks_the_gaps_give() -> void:
	var game := _launched()
	var queue: Array[SpawnOrder] = []
	for order in game.spawners[0].queue:
		queue.append(order)
	# the expected tick of each release, from the same float arithmetic written out
	var timer: float = WAVES.FIRST_SPAWN_DELAY
	var tick := 0
	var expected: Array[int] = []
	var index := 0
	while index < queue.size():
		tick += 1
		timer -= Game.TICK_SECONDS
		while timer <= 0.0 and index < queue.size():
			expected.append(tick)
			timer += queue[index].gap
			index += 1
	var seen: Array[String] = []
	var ticks_at: Array[int] = []
	while seen.size() < queue.size() and game.tick_count < 5000:
		Game.tick(game)
		for event in _events_of(game, GameEvent.Kind.FOE_SPAWNED):
			seen.append(event.foe_type)
			ticks_at.append(game.tick_count)
	for i in queue.size():
		assert_eq(seen[i], queue[i].type, "foe %d" % i)
	assert_eq(ticks_at, expected)


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


func test_a_cleared_wave_pays_its_bonus_once() -> void:
	var game := _launched()
	game.heartstone_health = 1000
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
	game.heartstone_health = 1000
	_until(game, func() -> bool: return game.spawners.is_empty())
	assert_gt(game.foes.size(), 0, "some foes are still walking when the last one is out")
	assert_true(game.running)


func test_calling_the_next_wave_early_pays_the_early_bonus() -> void:
	var game := _launched()
	game.heartstone_health = 1000
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
		var candidate := Game.create(map_seed, 9, 13, true, 1)
		if candidate.routes.size() == 2:
			game = candidate
			break
	assert_not_null(game, "a map with a detour exists")
	game.heartstone_health = 100000
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


func test_with_one_route_the_route_stream_is_not_touched() -> void:
	var game: GameState = null
	for map_seed in range(1, 80):
		var candidate := Game.create(map_seed, 9, 13, true, 1)
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
		game.heartstone_health = 100000
		GameTestKit.run(game, [Command.launch_wave()])
		_tick(game, 400)
	assert_eq(GameTestKit.snapshot(a), GameTestKit.snapshot(b))
	assert_gt(a.foes.size(), 0)


func test_the_route_each_foe_takes_is_the_next_draw_of_the_route_stream() -> void:
	var game: GameState = null
	var draws: Array[int] = []
	for map_seed in range(1, 80):
		var candidate := Game.create(map_seed, 9, 13, true, 1)
		if candidate.routes.size() != 2:
			continue
		var stream := Rng.derive(map_seed, Streams.ROUTES)
		var picks: Array[int] = []
		for i in 7:
			picks.append(stream.next_int(2))
		if picks.has(0) and picks.has(1):
			game = candidate
			draws = picks
			break
	assert_not_null(game, "a map with a detour whose first 7 draws use both routes")
	GameTestKit.run(game, [Command.launch_wave()])
	_until(game, func() -> bool: return game.spawners.is_empty())
	assert_eq(game.foes.size(), 7)
	for i in 7:
		assert_eq(game.foes[i].route, draws[i], "foe %d" % i)


func test_several_foes_with_no_gap_come_out_in_one_tick() -> void:
	var game := Game.create(SEED)
	var spawner := Spawner.new()
	spawner.wave = 1
	spawner.timer = 0.0
	for i in 3:
		spawner.queue.append(SpawnOrder.of("scrapGoblin", 0.0))
	game.spawners.append(spawner)
	game.running = true
	game.wave = 1
	Game.tick(game)
	assert_eq(game.foes.size(), 3)
	assert_eq(game.spawners.size(), 0)


func test_calling_a_wave_early_leaves_one_clear_for_the_later_wave() -> void:
	# wave 1's foes still walk when wave 2 is called, so they count toward wave 2's
	# clear: wave 1 never gets its own bonus (the prototype's rule)
	var game := _launched()
	game.heartstone_health = 100000
	_until(game, func() -> bool: return game.spawners.is_empty())
	GameTestKit.run(game, [Command.launch_wave()])
	var clears: Array[GameEvent] = []
	for i in 20000:
		Game.tick(game)
		clears.append_array(_events_of(game, GameEvent.Kind.WAVE_CLEARED))
		if not game.running:
			break
	assert_eq(clears.size(), 1)
	assert_eq(clears[0].wave, 2)
	# 15 + 2 * 2
	assert_eq(clears[0].bonus, 19)
