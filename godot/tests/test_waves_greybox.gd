## The scene plays waves: a launch button, foes drawn on the board, the wave and
## the kingdom's health on screen, and the game-over state.
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


func test_the_hud_shows_the_wave_the_kingdoms_health_and_the_buttons() -> void:
	var main := await _main()
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	_frames(main, 1.0)
	var text := (main.get_node("Hud/Info") as Label).text
	assert_string_contains(text, "Wave 1")
	assert_string_contains(text, "Kingdom %d" % main.game().kingdom_health)
	assert_string_contains(text, "Buttons %d" % main.game().buttons)


func test_the_button_is_disabled_while_foes_are_still_coming_then_offers_an_early_call() -> void:
	var main := await _main()
	var launch := main.get_node("Hud/LaunchWave") as Button
	launch.pressed.emit()
	_frames(main, 0.5)
	assert_true(launch.disabled)
	var game: GameState = main.game()
	game.kingdom_health = 100000
	while not game.spawners.is_empty():
		_frames(main, 0.5)
	assert_false(launch.disabled)
	# 10 + 1 * 2
	assert_string_contains(launch.text, "Call wave 2 early (+12)")


func test_a_foe_that_gets_through_costs_the_kingdom_health() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var start := game.kingdom_health
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	while game.kingdom_health == start and game.tick_count < 4000:
		_frames(main, 1.0)
	assert_lt(game.kingdom_health, start)


func test_game_over_is_shown_and_the_button_stops_working() -> void:
	var main := await _main()
	var game: GameState = main.game()
	game.kingdom_health = 1
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	while not game.over and game.tick_count < 4000:
		_frames(main, 1.0)
	assert_true(game.over)
	_frames(main, 0.2)
	assert_string_contains((main.get_node("Hud/Info") as Label).text, "GAME OVER")
	assert_true((main.get_node("Hud/LaunchWave") as Button).disabled)


func test_a_new_seed_clears_the_foes_and_resets_the_button() -> void:
	var main := await _main()
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	_frames(main, 3.0)
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(main.game().foes.size(), 0)
	assert_eq((main.get_node("Foes") as FoesView).visible_count("scrapGoblin"), 0)
	assert_string_contains((main.get_node("Hud/LaunchWave") as Button).text, "Start wave 1")


func test_the_info_line_is_short_enough_for_a_phone_even_at_game_over() -> void:
	var main := await _main()
	var game: GameState = main.game()
	game.over = true
	game.wave = 99
	game.kingdom_health = 20
	game.buttons = 99999
	main._process(0.05)
	var text := (main.get_node("Hud/Info") as Label).text
	# about 16 px per character at font 32 in a 1080 px label: stay under 60
	assert_lt(text.length(), 66)
	assert_true((main.get_node("Hud/Info") as Label).clip_text)
