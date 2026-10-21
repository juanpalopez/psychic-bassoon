## The game aggregate: creation, the tick, and the four commands. Ported from
## `web-three-final:src/sim/game/game.test.ts`.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const MAP_RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEED := 42
const FIXTURE := "res://../fixtures/prng.json"

const REASON := GameEvent.RejectReason


func test_create_starts_with_prototype_buttons_heartstone_health_and_tick_zero() -> void:
	var game := Game.create(SEED)
	assert_eq(game.seed, SEED)
	assert_eq(game.tick_count, 0)
	assert_eq(game.buttons, RULES.START_BUTTONS)
	assert_eq(game.heartstone_health, RULES.START_HEARTSTONE_HEALTH)
	assert_eq(game.wave, 0)
	assert_false(game.running)
	assert_false(game.over)
	assert_eq(game.towers.size(), 0)


func test_create_builds_the_map_and_every_route() -> void:
	var game := Game.create(SEED)
	var map := MapGen.generate_valley(SEED)
	assert_eq(game.map.path, map.path)
	assert_eq(game.routes.size(), map.routes.size())
	assert_eq(game.route, game.routes[0])
	# the valley board walks the curve through the road's corners, which is shorter than the
	# grid path (#321)
	assert_eq(game.route.total, Route.build_curved(map.path).total)
	assert_lt(game.route.total, 0.95 + float(map.path.size() - 1))


func test_create_uses_the_waves_and_routes_streams_from_the_fixture() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURE))
	for entry in JSON.parse_string(text):
		var game := Game.create(int(entry.seed))
		for derived in entry.derived:
			if int(derived.stream) == Streams.WAVES:
				assert_eq(game.rng.state, int(derived.state), "waves stream, seed %d" % entry.seed)
			if int(derived.stream) == Streams.ROUTES:
				assert_eq(
					game.route_rng.state, int(derived.state), "routes stream, seed %d" % entry.seed
				)


func test_same_seed_gives_the_same_game() -> void:
	var a := Game.create(SEED)
	var b := Game.create(SEED)
	assert_eq(GameTestKit.snapshot(a), GameTestKit.snapshot(b))
	var other := Game.create(SEED + 1)
	assert_ne(GameTestKit.snapshot(a), GameTestKit.snapshot(other))


func test_state_survives_json() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(
		game, [Command.build("spoolGuard", GameTestKit.socket(game).x, GameTestKit.socket(game).y)]
	)
	var snapshot := GameTestKit.snapshot(game)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	assert_eq(parsed.towers[0][1], "spoolGuard")
	assert_eq(int(parsed.buttons), game.buttons)
	assert_eq(int(parsed.rngState), game.rng.state)
	assert_eq(parsed.routes.size(), game.map.routes.size())


func test_tick_advances_the_counter_by_one() -> void:
	var game := Game.create(SEED)
	Game.tick(game)
	Game.tick(game)
	assert_eq(game.tick_count, 2)


func test_tick_changes_nothing_else_without_commands() -> void:
	var game := Game.create(SEED)
	var buttons := game.buttons
	var heartstone_health := game.heartstone_health
	Game.tick(game)
	assert_eq(game.buttons, buttons)
	assert_eq(game.heartstone_health, heartstone_health)
	assert_eq(game.towers.size(), 0)
	assert_eq(game.events.size(), 0)


func test_commands_run_in_submission_order() -> void:
	var game := Game.create(SEED)
	var cell := GameTestKit.socket(game)
	GameTestKit.run(
		game,
		[GameTestKit.build_at("spoolGuard", cell), GameTestKit.build_at("thimbleMortar", cell)]
	)
	assert_eq(game.towers.size(), 1)
	assert_eq(game.towers[0].type, "spoolGuard")


func test_queue_is_empty_after_each_tick() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [Command.launch_wave()])
	assert_eq(game.pending.size(), 0)


func test_commands_do_not_run_before_the_tick() -> void:
	var game := Game.create(SEED)
	Game.submit(game, GameTestKit.build_at("spoolGuard", GameTestKit.socket(game)))
	assert_eq(game.towers.size(), 0)
	assert_eq(game.buttons, RULES.START_BUTTONS)


func test_events_last_one_tick_only() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [GameTestKit.build_at("spoolGuard", GameTestKit.socket(game))])
	assert_eq(game.events.size(), 1)
	Game.tick(game)
	assert_eq(game.events.size(), 0)


func test_commands_are_rejected_once_the_game_is_over() -> void:
	var game := Game.create(SEED)
	game.over = true
	var command := Command.launch_wave()
	var events := GameTestKit.run(game, [command])
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(events[0].reason, REASON.GAME_OVER)
	assert_eq(game.wave, 0)
