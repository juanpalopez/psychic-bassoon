## The game over overlay and its Play again button.
extends GutTest


func _panel() -> GameOverPanel:
	var panel := GameOverPanel.new()
	add_child_autofree(panel)
	return panel


func test_it_is_hidden_until_shown() -> void:
	assert_false(_panel().visible)


func test_it_says_the_heartstone_fell_and_on_which_wave() -> void:
	var panel := _panel()
	panel.show_for(6)
	assert_true(panel.visible)
	assert_string_contains(panel.title_text(), "fallen")
	assert_string_contains(panel.detail_text(), "wave 6")


func test_play_again_is_announced_and_is_big_enough() -> void:
	var panel := _panel()
	watch_signals(panel)
	panel.play_again_button().pressed.emit()
	assert_signal_emitted(panel, "play_again")
	assert_gte(panel.play_again_button().custom_minimum_size.y * 0.54, 44.0)


func test_it_can_be_hidden_again() -> void:
	var panel := _panel()
	panel.show_for(1)
	panel.close()
	assert_false(panel.visible)


func test_a_win_says_so_and_names_the_wave() -> void:
	var panel := _panel()
	panel.show_won(20)
	assert_true(panel.visible)
	assert_string_contains(panel.title_text(), "holds")
	assert_string_contains(panel.detail_text(), "wave 20")


func test_a_loss_after_a_win_says_the_heartstone_fell_again() -> void:
	var panel := _panel()
	panel.show_won(20)
	panel.show_for(6)
	assert_string_contains(panel.title_text(), "fallen")
