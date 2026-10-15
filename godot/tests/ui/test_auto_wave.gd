## Auto start: with the switch on, a cleared wave is followed by the next one after a short
## countdown, without a tap. It never calls a wave early (that bonus stays a choice).
extends GutTest

const RULES := preload("res://content/game_rules.gd")


func _idle_game() -> GameState:
	var game := Game.create(7)
	game.wave = 3
	return game


func test_it_does_nothing_while_switched_off() -> void:
	var auto := AutoWave.new()
	assert_false(auto.advance(_idle_game(), RULES.AUTO_WAVE_SECONDS * 2.0))
	assert_false(auto.counting())


func test_it_counts_down_between_waves_and_then_asks_for_the_next() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var game := _idle_game()
	assert_false(auto.advance(game, 0.5))
	assert_true(auto.counting())
	assert_eq(auto.seconds_left(), int(ceil(RULES.AUTO_WAVE_SECONDS - 0.5)))
	assert_true(auto.advance(game, RULES.AUTO_WAVE_SECONDS), "the countdown ran out")
	assert_false(auto.counting(), "one launch per countdown")


func test_it_never_calls_a_wave_early() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var game := _idle_game()
	game.running = true
	assert_false(auto.advance(game, RULES.AUTO_WAVE_SECONDS * 2.0))
	assert_false(auto.counting())


func test_it_waits_for_the_foes_still_coming_out() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var game := _idle_game()
	game.spawners.append(Spawner.new())
	assert_false(auto.advance(game, RULES.AUTO_WAVE_SECONDS * 2.0))


func test_it_stops_when_the_run_ends_or_after_the_last_wave() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var over := _idle_game()
	over.over = true
	assert_false(auto.advance(over, RULES.AUTO_WAVE_SECONDS * 2.0))
	var won := _idle_game()
	won.won = true
	assert_false(auto.advance(won, RULES.AUTO_WAVE_SECONDS * 2.0))
	var last := _idle_game()
	last.wave = RULES.WIN_WAVE
	assert_false(auto.advance(last, RULES.AUTO_WAVE_SECONDS * 2.0))


func test_a_paused_game_holds_the_countdown() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var game := _idle_game()
	auto.advance(game, 1.0)
	var left := auto.seconds_left()
	auto.advance(game, 0.0)
	assert_eq(auto.seconds_left(), left)


func test_switching_off_cancels_the_countdown() -> void:
	var auto := AutoWave.new()
	auto.enabled = true
	var game := _idle_game()
	auto.advance(game, 1.0)
	auto.enabled = false
	assert_false(auto.advance(game, RULES.AUTO_WAVE_SECONDS))
	assert_false(auto.counting())
