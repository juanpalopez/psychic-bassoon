## Foes that get through: the leak, the Heartstone's health and game over.
extends GutTest

const SEED := 42


func _launched(map_seed: int = SEED) -> GameState:
	var game := Game.create(map_seed)
	GameTestKit.run(game, [Command.launch_wave()])
	return game


func _tick(game: GameState, count: int) -> void:
	for i in count:
		Game.tick(game)


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


func test_a_foe_that_reaches_the_end_leaks_and_leaves() -> void:
	var game := _launched()
	var start_health := game.heartstone_health
	_until(game, func() -> bool: return game.heartstone_health < start_health)
	assert_lt(game.heartstone_health, start_health)
	# the goblin that got through cost 1
	assert_eq(game.heartstone_health, start_health - 1)


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


func test_the_game_ends_when_the_heartstone_has_no_health_left() -> void:
	var game := _launched()
	game.heartstone_health = 1
	_until(game, func() -> bool: return game.over)
	assert_true(game.over)
	assert_eq(game.heartstone_health, 0)
	# commands are now turned away
	var events := GameTestKit.run(game, [Command.launch_wave()])
	assert_eq(events[0].reason, GameEvent.RejectReason.GAME_OVER)


func test_game_over_is_announced_once_with_the_wave() -> void:
	var game := _launched()
	game.heartstone_health = 1
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
	game.heartstone_health = 1
	_until(game, func() -> bool: return game.over)
	var distances: Array[float] = []
	for foe in game.foes:
		distances.append(foe.distance)
	_tick(game, 10)
	for i in game.foes.size():
		assert_eq(game.foes[i].distance, distances[i])


func test_a_big_leak_takes_what_is_left_and_health_stops_at_zero() -> void:
	var game := Game.create(SEED)
	game.heartstone_health = 1
	var orc := FoeSpawner.spawn(game, "corrugatedOrc", 1, 0)
	orc.distance = game.routes[0].total - 0.001
	Game.tick(game)
	var leaks := _events_of(game, GameEvent.Kind.FOE_LEAKED)
	assert_eq(leaks.size(), 1)
	# an orc leaks 2, the Heartstone had 1: it ends at 0, not -1
	assert_eq(leaks[0].leak, 2)
	assert_eq(leaks[0].foe_type, "corrugatedOrc")
	assert_eq(game.heartstone_health, 0)
	assert_true(game.over)


func test_a_leak_takes_the_foes_own_leak_from_the_health() -> void:
	var game := Game.create(SEED)
	var start := game.heartstone_health
	var golem := FoeSpawner.spawn(game, "cardboardGolem", 10, 0)
	golem.distance = game.routes[0].total - 0.001
	Game.tick(game)
	assert_eq(game.heartstone_health, start - 6)
