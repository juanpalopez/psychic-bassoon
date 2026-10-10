## The game aggregate: creation, the tick, and the four commands. Ported from
## `src/sim/game/game.test.ts`.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const MAP_RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEED := 42
const FIXTURE := "res://../fixtures/prng.json"

const REASON := GameEvent.RejectReason


func test_create_starts_with_prototype_gold_lives_and_tick_zero() -> void:
	var game := Game.create(SEED)
	assert_eq(game.seed, SEED)
	assert_eq(game.tick_count, 0)
	assert_eq(game.gold, RULES.START_GOLD)
	assert_eq(game.lives, RULES.START_LIVES)
	assert_eq(game.wave, 0)
	assert_false(game.running)
	assert_false(game.over)
	assert_eq(game.towers.size(), 0)


func test_create_builds_the_map_and_every_route() -> void:
	var game := Game.create(SEED)
	var map := MapGen.generate(SEED)
	assert_eq(game.map.path, map.path)
	assert_eq(game.routes.size(), map.routes.size())
	assert_eq(game.route, game.routes[0])
	assert_almost_eq(game.route.total, 0.95 + float(map.path.size() - 1), 1e-9)


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
	assert_eq(a.map.routes, b.map.routes)
	assert_eq(a.rng.state, b.rng.state)
	assert_eq(a.gold, b.gold)


func test_tick_advances_the_counter_by_one() -> void:
	var game := Game.create(SEED)
	Game.tick(game)
	Game.tick(game)
	assert_eq(game.tick_count, 2)


func test_tick_changes_nothing_else_without_commands() -> void:
	var game := Game.create(SEED)
	var gold := game.gold
	var lives := game.lives
	Game.tick(game)
	assert_eq(game.gold, gold)
	assert_eq(game.lives, lives)
	assert_eq(game.towers.size(), 0)
	assert_eq(game.events.size(), 0)


func test_commands_run_in_submission_order() -> void:
	var game := Game.create(SEED)
	var cell := GameTestKit.plot(game)
	GameTestKit.run(
		game, [GameTestKit.build_at("ballista", cell), GameTestKit.build_at("catapult", cell)]
	)
	assert_eq(game.towers.size(), 1)
	assert_eq(game.towers[0].type, "ballista")


func test_queue_is_empty_after_each_tick() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [Command.launch_wave()])
	assert_eq(game.pending.size(), 0)


func test_commands_do_not_run_before_the_tick() -> void:
	var game := Game.create(SEED)
	Game.submit(game, GameTestKit.build_at("ballista", GameTestKit.plot(game)))
	assert_eq(game.towers.size(), 0)
	assert_eq(game.gold, RULES.START_GOLD)


func test_events_last_one_tick_only() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [GameTestKit.build_at("ballista", GameTestKit.plot(game))])
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
