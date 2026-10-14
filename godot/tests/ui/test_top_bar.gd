## The stats chip: Buttons, Heartstone health and wave.
extends GutTest


func _bar() -> TopBar:
	var bar := TopBar.new()
	add_child_autofree(bar)
	return bar


func test_it_shows_the_state_of_the_game() -> void:
	var game := Game.create(7)
	game.buttons = 123
	game.heartstone_health = 14
	game.wave = 3
	var bar := _bar()
	bar.show_state(game)
	assert_eq(bar.texts(), ["Buttons 123", "Heartstone 14", "Wave 3/20"])


func test_it_follows_the_game_when_it_changes() -> void:
	var game := Game.create(7)
	var bar := _bar()
	bar.show_state(game)
	game.buttons = 5
	bar.show_state(game)
	assert_eq(bar.texts()[0], "Buttons 5")
