## A run is won when wave `WIN_WAVE` is cleared: the clear bonus is paid, a
## GAME_WON event is reported once, and then nothing else runs, like game over.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const PROFILES := preload("res://content/bot_profiles.gd")


## A game one clear away from `wave`: it is running that wave with nothing left
## to fight, so the next tick settles it.
func _about_to_clear(wave: int) -> GameState:
	var game := Game.create_on_strip_valley(1)
	game.wave = wave
	game.running = true
	return game


func _kinds(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in game.events:
		if event.kind == kind:
			found.append(event)
	return found


func test_the_win_wave_is_in_the_content() -> void:
	assert_eq(RULES.WIN_WAVE, 20)


func test_a_new_game_is_not_won() -> void:
	assert_false(Game.create_on_strip_valley(1).won)


func test_clearing_the_win_wave_wins_once_and_pays_its_bonus() -> void:
	var game := _about_to_clear(RULES.WIN_WAVE)
	var before := game.buttons
	Game.tick(game)
	assert_true(game.won)
	assert_false(game.over)
	assert_eq(game.buttons, before + RULES.WAVE_CLEAR_BASE + 20 * RULES.WAVE_CLEAR_PER_WAVE)
	var won := _kinds(game, GameEvent.Kind.GAME_WON)
	assert_eq(won.size(), 1)
	assert_eq(won[0].wave, RULES.WIN_WAVE)
	assert_eq(_kinds(game, GameEvent.Kind.WAVE_CLEARED).size(), 1, "the wave is cleared first")
	Game.tick(game)
	assert_eq(_kinds(game, GameEvent.Kind.GAME_WON).size(), 0, "reported once")


func test_clearing_an_earlier_wave_does_not_win() -> void:
	for wave in [1, 10, RULES.WIN_WAVE - 1]:
		var game := _about_to_clear(wave)
		Game.tick(game)
		assert_false(game.won, "wave %d" % wave)
		assert_eq(_kinds(game, GameEvent.Kind.GAME_WON).size(), 0)


func test_a_won_game_runs_nothing_more() -> void:
	var game := _about_to_clear(RULES.WIN_WAVE)
	Game.tick(game)
	assert_true(game.won)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	var at := foe.distance
	var ticks := game.tick_count
	for i in 30:
		Game.tick(game)
	assert_eq(foe.distance, at, "foes stop walking")
	assert_eq(game.heartstone_health, RULES.START_HEARTSTONE_HEALTH)
	assert_eq(game.tick_count, ticks + 30, "the tick count still runs")
	assert_eq(game.events.size(), 0, "no shots, spawns or other events")


func test_a_won_game_refuses_commands() -> void:
	var game := _about_to_clear(RULES.WIN_WAVE)
	Game.tick(game)
	var buttons := game.buttons
	var anchor := game.map.sockets[0]
	Game.submit(game, Command.build("spoolGuard", anchor.x, anchor.y))
	Game.submit(game, Command.launch_wave())
	Game.tick(game)
	assert_eq(game.towers.size(), 0)
	assert_eq(game.buttons, buttons)
	var refused := _kinds(game, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(refused.size(), 2)
	assert_eq(refused[0].reason, GameEvent.RejectReason.GAME_WON)


func test_the_frame_stepper_stops_when_the_game_is_won() -> void:
	var game := _about_to_clear(RULES.WIN_WAVE)
	var clock := Clock.new()
	var ran := Frame.step(game, clock, 0.5, 1)
	assert_true(game.won)
	assert_lt(ran, 15, "it stopped on the winning tick, not after the frame's 15 ticks")
	assert_eq(Frame.step(game, clock, 0.5, 1), 0, "and runs nothing afterwards")


func test_a_game_cannot_be_lost_and_won() -> void:
	# the last foe of wave 20 leaks and takes the last Heartstone health: the run is
	# lost, and the wave does not settle into a win on the same tick
	var game := _about_to_clear(RULES.WIN_WAVE)
	game.heartstone_health = 1
	var foe := FoeSpawner.spawn(game, "scrapGoblin", RULES.WIN_WAVE, 0)
	foe.distance = 1.0e9
	Game.tick(game)
	assert_true(game.over)
	assert_false(game.won)
	assert_eq(_kinds(game, GameEvent.Kind.GAME_WON).size(), 0)
	assert_eq(_kinds(game, GameEvent.Kind.WAVE_CLEARED).size(), 0)


func test_no_wave_can_be_launched_after_the_win_wave() -> void:
	var game := _about_to_clear(RULES.WIN_WAVE)
	game.spawners = []
	var before := game.buttons
	Game.submit(game, Command.launch_wave())
	Game.tick(game)
	assert_eq(game.wave, RULES.WIN_WAVE)
	assert_eq(
		game.buttons, before + RULES.WAVE_CLEAR_BASE + RULES.WIN_WAVE * RULES.WAVE_CLEAR_PER_WAVE
	)
	var refused := _kinds(game, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(refused.size(), 1)
	assert_eq(refused[0].reason, GameEvent.RejectReason.FINAL_WAVE)
	assert_true(game.won, "and the wave settles into the win")


func test_the_scripted_bot_wins_a_20_wave_run() -> void:
	# seed 5 on the layout valley (#458, foes at half pace) with the spool-only profile, 20 Heartstone
	# health left; the mix clears wave 20 on none of seeds 1 to 12 inside the bot's thirty minutes
	var result := BotRunner.play(5, PROFILES.PROFILES.spoolOnly, 20)
	assert_eq(result.waves_cleared, 20)
	assert_true(result.won)
	assert_false(result.over)


func test_the_win_replays_identically() -> void:
	var a := BotRunner.play(3, PROFILES.PROFILES.spoolOnly, 20)
	var b := BotRunner.play(3, PROFILES.PROFILES.spoolOnly, 20)
	assert_eq(a, b)
