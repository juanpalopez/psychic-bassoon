## The scene plays waves: a launch button, foes drawn on the board, the wave and
## the Heartstone's health on screen, and the game-over state.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _frames(main: Node, seconds: float) -> void:
	for i in int(seconds * 20.0):
		main._process(0.05)


func test_the_launch_button_starts_wave_1_and_foes_appear_on_the_board() -> void:
	var main := await _main()
	var launch := main.get_node("Hud/LaunchWave") as Button
	assert_string_contains(launch.text, "Start wave 1")
	launch.pressed.emit()
	_frames(main, 4.0)
	var game: GameState = main.game()
	assert_eq(game.wave, 1)
	assert_gt(game.foes.size(), 0)
	var view := main.get_node("Foes") as FoesView
	assert_eq(view.visible_count("scrapGoblin"), game.foes.size())


func test_the_hud_shows_the_wave_the_heartstones_health_and_the_buttons() -> void:
	var main := await _main()
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	_frames(main, 1.0)
	var text := " ".join((main.get_node("Hud/TopBar") as TopBar).texts())
	assert_string_contains(text, "Wave 1/20")
	assert_string_contains(text, "Heartstone %d" % main.game().heartstone_health)
	assert_string_contains(text, "Buttons %d" % main.game().buttons)


func test_the_button_is_disabled_while_foes_are_still_coming_then_offers_an_early_call() -> void:
	var main := await _main()
	var launch := main.get_node("Hud/LaunchWave") as Button
	launch.pressed.emit()
	_frames(main, 0.5)
	assert_true(launch.disabled)
	assert_false(launch.visible, "the button steps aside while foes come out")
	var game: GameState = main.game()
	game.heartstone_health = 100000
	while not game.spawners.is_empty():
		_frames(main, 0.5)
	assert_false(launch.disabled)
	assert_true(launch.visible, "and comes back for the early call")
	# 10 + 1 * 2
	assert_string_contains(launch.text, "Call wave 2 early (+12)")


func test_a_foe_that_gets_through_costs_the_heartstone_health() -> void:
	var main := await _main()
	var game: GameState = main.game()
	# the Knight would hold the foes at the Heartstone
	game.hero = null
	var start := game.heartstone_health
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	while game.heartstone_health == start and game.tick_count < 4000:
		_frames(main, 1.0)
	assert_lt(game.heartstone_health, start)


func test_game_over_is_shown_and_the_button_stops_working() -> void:
	var main := await _main()
	var game: GameState = main.game()
	# the Knight would hold the foes at the Heartstone
	game.hero = null
	game.heartstone_health = 1
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	while not game.over and game.tick_count < 4000:
		_frames(main, 1.0)
	assert_true(game.over)
	_frames(main, 0.2)
	assert_true((main.get_node("Hud/GameOver") as GameOverPanel).visible)
	assert_true((main.get_node("Hud/LaunchWave") as Button).disabled)


func test_a_new_seed_clears_the_foes_and_resets_the_button() -> void:
	var main := await _main()
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	_frames(main, 3.0)
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(main.game().foes.size(), 0)
	assert_eq((main.get_node("Foes") as FoesView).visible_count("scrapGoblin"), 0)
	assert_string_contains((main.get_node("Hud/LaunchWave") as Button).text, "Start wave 1")
	assert_true((main.get_node("Hud/LaunchWave") as Button).visible)


func test_the_top_bar_fits_beside_the_speed_buttons_even_at_game_over() -> void:
	var main := await _main()
	var game: GameState = main.game()
	game.over = true
	# the wave counter never goes past the win wave in a real game
	game.wave = 20
	game.heartstone_health = 20
	# more Buttons than a run ever holds (the Spool Guard strategy ends with 2,500)
	game.buttons = 9999
	main._process(0.05)
	var text := " ".join((main.get_node("Hud/TopBar") as TopBar).texts())
	# the bar has 1280 - 20 - 500 px before it would run under the speed buttons
	var bar := main.get_node("Hud/TopBar") as TopBar
	assert_lt(bar.get_combined_minimum_size().x, 760.0, text)


func test_restarting_in_the_middle_of_a_wave_brings_the_button_back() -> void:
	var main := await _main()
	var launch := main.get_node("Hud/LaunchWave") as Button
	launch.pressed.emit()
	_frames(main, 0.5)
	assert_false(launch.visible)
	main._start(main.game().seed)
	assert_true(launch.visible)
	assert_string_contains(launch.text, "Start wave 1")
