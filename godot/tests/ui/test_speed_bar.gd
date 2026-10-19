## Pause, and the one button that cycles the speed 1x, 2x, 3x.
extends GutTest


func _bar() -> SpeedBar:
	var bar := SpeedBar.new()
	add_child_autofree(bar)
	return bar


func test_it_has_pause_and_a_speed_button_showing_1x() -> void:
	var labels: Array[String] = []
	for button in _bar().buttons():
		labels.append(button.text)
	assert_eq(labels, ["Pause", "1x"])


func test_pressing_the_speed_button_asks_for_the_next_speed_and_wraps() -> void:
	var bar := _bar()
	var speed := GameSpeed.new()
	watch_signals(bar)
	bar.buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(bar, "speed_chosen", [2])
	speed.choose(2)
	bar.show_speed(speed)
	bar.buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(bar, "speed_chosen", [3])
	speed.choose(3)
	bar.show_speed(speed)
	assert_eq(bar.next_speed(), 1, "after the last speed comes the first")


func test_pressing_pause_announces_it() -> void:
	var bar := _bar()
	watch_signals(bar)
	bar.buttons()[0].pressed.emit()
	assert_signal_emitted(bar, "pause_toggled")


func test_the_speed_button_shows_the_speed_and_pause_is_marked() -> void:
	var bar := _bar()
	var speed := GameSpeed.new()
	speed.choose(2)
	bar.show_speed(speed)
	assert_eq(bar.buttons()[1].text, "2x")
	assert_eq(bar.active_labels(), ["2x"])
	speed.toggle_pause()
	bar.show_speed(speed)
	assert_eq(bar.active_labels(), ["Pause"])


func test_the_buttons_are_big_enough_for_a_thumb() -> void:
	for button in _bar().buttons():
		assert_gte(button.custom_minimum_size.y * 0.54, 44.0)
		assert_gte(button.custom_minimum_size.x * 0.54, 44.0)


func test_the_paused_caption_fits_the_square() -> void:
	var bar := _bar()
	var speed := GameSpeed.new()
	speed.toggle_pause()
	bar.show_speed(speed)
	var pause := bar.buttons()[0]
	# headless font metrics differ from the game's, so also cap the caption at the length of
	# "Pause": "Resume" made the square 97 px wide in the HUD font
	assert_lte(pause.text.length(), "Pause".length(), "short caption: %s" % pause.text)
	assert_lte(pause.get_combined_minimum_size().x, HudLayout.ROW)
