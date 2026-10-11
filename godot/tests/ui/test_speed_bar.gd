## The pause button and the 1x, 2x, 3x buttons.
extends GutTest


func _bar() -> SpeedBar:
	var bar := SpeedBar.new()
	add_child_autofree(bar)
	return bar


func test_it_has_pause_then_three_speeds_labelled() -> void:
	var bar := _bar()
	var labels: Array[String] = []
	for button in bar.buttons():
		labels.append(button.text)
	assert_eq(labels, ["Pause", "1x", "2x", "3x"])


func test_pressing_a_speed_announces_it() -> void:
	var bar := _bar()
	watch_signals(bar)
	bar.buttons()[3].pressed.emit()
	assert_signal_emitted_with_parameters(bar, "speed_chosen", [3])
	bar.buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(bar, "speed_chosen", [1])


func test_pressing_pause_announces_it() -> void:
	var bar := _bar()
	watch_signals(bar)
	bar.buttons()[0].pressed.emit()
	assert_signal_emitted(bar, "pause_toggled")


func test_the_active_speed_is_marked() -> void:
	var bar := _bar()
	var speed := GameSpeed.new()
	speed.choose(2)
	bar.show_speed(speed)
	assert_eq(bar.active_labels(), ["2x"])
	speed.toggle_pause()
	bar.show_speed(speed)
	assert_eq(bar.active_labels(), ["Pause"])


func test_the_buttons_are_big_enough_for_a_thumb() -> void:
	for button in _bar().buttons():
		assert_gte(button.custom_minimum_size.y * 0.54, 44.0)
		assert_gte(button.custom_minimum_size.x * 0.54, 44.0)
