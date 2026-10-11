## The fixed-step clock and the frame stepper. Ported from
## `src/sim/game/clock.test.ts` and `frame.test.ts`.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const SEED := 42
const TICK := Game.TICK_SECONDS


func test_tick_is_one_thirtieth_of_a_second() -> void:
	assert_eq(TICK, 1.0 / RULES.TICK_RATE)
	assert_eq(RULES.TICK_RATE, 30)


func test_no_tick_until_a_full_tick_has_elapsed() -> void:
	var clock := Clock.new()
	assert_eq(clock.advance(TICK / 2.0, 1), 0)
	assert_eq(clock.advance(TICK / 2.0, 1), 1)


func test_remainder_carries_to_the_next_frame() -> void:
	var clock := Clock.new()
	var total := 0
	for i in 90:
		total += clock.advance(0.02, 1)
	# 90 frames of 20 ms is 1.8 s, which is exactly 54 ticks
	assert_eq(total, 54)


func test_speed_runs_more_ticks_not_bigger_ticks() -> void:
	for speed in [1, 2, 3]:
		assert_eq(Clock.new().advance(TICK, speed), speed)


func test_a_slow_frame_is_clamped() -> void:
	# 0.05 s allows one whole tick of 1/30 s
	assert_eq(Clock.new().advance(5.0, 1), 1)


func test_negative_and_nan_time_runs_nothing() -> void:
	var clock := Clock.new()
	assert_eq(clock.advance(-1.0, 1), 0)
	assert_eq(clock.advance(NAN, 1), 0)
	assert_eq(clock.accumulator, 0.0)


func test_infinite_time_is_clamped_like_any_long_frame() -> void:
	# the same as the TypeScript clock: one tick, not zero
	assert_eq(Clock.new().advance(INF, 1), 1)


func test_invalid_speed_is_reported_and_runs_nothing() -> void:
	for speed in [0, -1, 4]:
		assert_eq(Clock.new().advance(0.03, speed), 0)
		assert_push_error("game speed must be 1 to 3")


func test_step_runs_the_ticks_the_clock_allows() -> void:
	var game := Game.create(SEED)
	var clock := Clock.new()
	assert_eq(Frame.step(game, clock, TICK, 1), 1)
	assert_eq(game.tick_count, 1)
	assert_eq(Frame.step(game, clock, TICK, 3), 3)
	assert_eq(game.tick_count, 4)


func test_step_stops_once_the_game_is_over() -> void:
	var game := Game.create(SEED)
	game.over = true
	assert_eq(Frame.step(game, Clock.new(), TICK, 3), 0)
	assert_eq(game.tick_count, 0)


func test_before_tick_sees_the_tick_about_to_run() -> void:
	var game := Game.create(SEED)
	var seen: Array[int] = []
	var hook := func(g: GameState) -> void: seen.append(g.tick_count)
	Frame.step(game, Clock.new(), TICK, 3, hook)
	assert_eq(seen, [0, 1, 2] as Array[int])


func test_after_tick_sees_the_tick_that_ran() -> void:
	var game := Game.create(SEED)
	var seen: Array[int] = []
	var hook := func(g: GameState) -> void: seen.append(g.tick_count)
	Frame.step(game, Clock.new(), TICK, 3, Callable(), hook)
	assert_eq(seen, [1, 2, 3] as Array[int])


func test_step_stops_exactly_at_the_tick_limit() -> void:
	var game := Game.create(SEED)
	assert_eq(Frame.step(game, Clock.new(), TICK, 3, Callable(), Callable(), 2), 2)
	assert_eq(game.tick_count, 2)


func test_speed_and_frame_rate_never_change_the_game() -> void:
	# Speed only changes how many ticks run per frame, never the tick: a run
	# driven by frames at 1x, 2x or 3x matches the tick-by-tick run.
	var ticks := 300
	var reference := _play(1.0 / 30.0, 1, ticks)
	for setup in [[1, 1.0 / 60.0], [2, 1.0 / 60.0], [3, 1.0 / 30.0], [3, 1.0 / 20.0]]:
		var game := _play(setup[1], setup[0], ticks)
		assert_eq(game.tick_count, ticks)
		assert_eq(game.gold, reference.gold, "gold at speed %d" % setup[0])
		assert_eq(game.wave, reference.wave)
		assert_eq(game.towers.size(), reference.towers.size())


## A scripted player: builds, upgrades and launches on fixed ticks.
func _play(frame_seconds: float, speed: int, ticks: int) -> GameState:
	var game := Game.create(SEED)
	var clock := Clock.new()
	var cells := game.map.sockets
	var script := {
		0: Command.build("ballista", cells[0].x, cells[0].y),
		30: Command.build("catapult", cells[5].x, cells[5].y),
		60: Command.upgrade(0),
		90: Command.launch_wave(),
		120: Command.sell(1),
		180: Command.launch_wave(),
	}
	var hook := func(g: GameState) -> void:
		if script.has(g.tick_count):
			Game.submit(g, script[g.tick_count])
	while game.tick_count < ticks and not game.over:
		Frame.step(game, clock, frame_seconds, speed, hook, Callable(), ticks)
	return game
