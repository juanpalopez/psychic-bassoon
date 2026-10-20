## The build menu: one button per tower, with its cost.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


func _menu() -> BuildMenu:
	var menu := BuildMenu.new()
	add_child_autofree(menu)
	return menu


func test_one_button_per_tower_with_its_name_and_cost() -> void:
	var menu := _menu()
	var tower_buttons := menu.tower_buttons()
	assert_eq(tower_buttons.size(), TOWERS.TOWER_IDS.size())
	for i in TOWERS.TOWER_IDS.size():
		var id: String = TOWERS.TOWER_IDS[i]
		assert_string_contains(tower_buttons[i].text, TOWERS.DEFS[id].name)
		assert_string_contains(tower_buttons[i].text, str(TOWERS.DEFS[id].cost[0]))


func test_it_is_hidden_until_opened_and_hides_when_closed() -> void:
	var menu := _menu()
	assert_false(menu.visible)
	menu.open_for(Vector2i(1, 1), 1000)
	assert_true(menu.visible)
	menu.close()
	assert_false(menu.visible)


func test_a_button_is_disabled_when_the_buttons_are_short() -> void:
	var menu := _menu()
	menu.open_for(Vector2i(1, 1), 60)
	var tower_buttons := menu.tower_buttons()
	for i in TOWERS.TOWER_IDS.size():
		var cost: int = TOWERS.DEFS[TOWERS.TOWER_IDS[i]].cost[0]
		assert_eq(tower_buttons[i].disabled, cost > 60, TOWERS.TOWER_IDS[i])
	menu.set_buttons(1000)
	for button in tower_buttons:
		assert_false(button.disabled)


func test_pressing_a_button_announces_the_tower_and_closes() -> void:
	var menu := _menu()
	menu.open_for(Vector2i(2, 3), 1000)
	watch_signals(menu)
	menu.tower_buttons()[1].pressed.emit()
	assert_signal_emitted_with_parameters(menu, "tower_chosen", [TOWERS.TOWER_IDS[1]])
	assert_false(menu.visible)


func test_buttons_are_big_enough_for_a_thumb() -> void:
	# the project scales its 1280x720 base down to about 0.54 on a phone, and a
	# tap target must stay at least 44 px
	var menu := _menu()
	for button in menu.tower_buttons():
		assert_gte(button.custom_minimum_size.y * 0.54, 44.0)


func test_every_rejection_has_a_message() -> void:
	for reason in GameEvent.RejectReason.values():
		assert_ne(RejectText.of(reason), "", str(reason))


func test_hovering_a_tower_asks_for_its_card_and_leaving_clears_it() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.open_for(Vector2i(1, 1), 500)
	menu.tower_buttons()[1].mouse_entered.emit()
	assert_signal_emitted_with_parameters(menu, "info_requested", [TOWERS.TOWER_IDS[1]])
	menu.tower_buttons()[1].mouse_exited.emit()
	assert_signal_emitted(menu, "info_cleared")


func test_a_tap_still_chooses_the_tower() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.open_for(Vector2i(1, 1), 500)
	menu.tower_buttons()[0].button_down.emit()
	menu.tower_buttons()[0].button_up.emit()
	menu.tower_buttons()[0].pressed.emit()
	assert_signal_emitted_with_parameters(menu, "tower_chosen", [TOWERS.TOWER_IDS[0]])


func test_a_press_and_hold_shows_the_card_and_does_not_choose() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.open_for(Vector2i(1, 1), 500)
	menu.tower_buttons()[2].button_down.emit()
	menu.hold_elapsed()
	assert_signal_emitted_with_parameters(menu, "info_requested", [TOWERS.TOWER_IDS[2]])
	menu.tower_buttons()[2].button_up.emit()
	menu.tower_buttons()[2].pressed.emit()
	assert_signal_not_emitted(menu, "tower_chosen")
	assert_signal_emitted(menu, "info_cleared", "the look ends when the finger lets go")
	assert_true(menu.visible, "the menu stays open after a look")
	# the next plain tap chooses
	menu.tower_buttons()[2].button_down.emit()
	menu.tower_buttons()[2].button_up.emit()
	menu.tower_buttons()[2].pressed.emit()
	assert_signal_emitted_with_parameters(menu, "tower_chosen", [TOWERS.TOWER_IDS[2]])


func test_closing_the_menu_in_the_middle_of_a_press_cancels_the_hold() -> void:
	var menu := _menu()
	watch_signals(menu)
	menu.open_for(Vector2i(1, 1), 500)
	menu.tower_buttons()[0].button_down.emit()
	menu.close()
	menu.hold_elapsed()
	assert_signal_not_emitted(menu, "info_requested")


func test_the_hold_timer_is_wired_to_the_hold_time() -> void:
	var menu := _menu()
	var timers := menu.find_children("*", "Timer", false, false)
	assert_eq(timers.size(), 1)
	assert_eq((timers[0] as Timer).wait_time, BuildMenu.HOLD_SECONDS)
	assert_true((timers[0] as Timer).one_shot)


func test_close_asks_to_drop_the_selection_and_hides_the_bar() -> void:
	var menu := _menu()
	menu.open_for(Vector2i(2, 3), 1000)
	watch_signals(menu)
	menu.close_button().pressed.emit()
	assert_signal_emitted(menu, "closed")
	assert_false(menu.visible)


func test_close_is_a_square_as_tall_as_the_row() -> void:
	var close := _menu().close_button()
	assert_eq(close.custom_minimum_size, Vector2(HudLayout.ROW, HudLayout.ROW))


func test_tokens_are_one_row_tall_and_share_the_width() -> void:
	for button in _menu().tower_buttons():
		assert_eq(button.custom_minimum_size.y, HudLayout.ROW)
		assert_eq(button.size_flags_horizontal, Control.SIZE_EXPAND_FILL)


func test_a_socket_clear_of_both_rows_needs_no_room() -> void:
	var port := Vector2(1280.0, 720.0)
	assert_false(BuildMenu.needs_room(Rect2(600.0, 300.0, 80.0, 60.0), port))
	# touching the edge of the bottom row's band is still clear
	var bottom := port.y - HudLayout.BOTTOM_CLEAR
	assert_false(BuildMenu.needs_room(Rect2(600.0, bottom - 60.0, 80.0, 60.0), port))
	assert_false(BuildMenu.needs_room(Rect2(600.0, HudLayout.TOP_CLEAR, 80.0, 60.0), port))


func test_a_socket_under_the_bar_or_the_top_row_needs_room() -> void:
	var port := Vector2(1558.0, 720.0)
	var bottom := port.y - HudLayout.BOTTOM_CLEAR
	assert_true(
		BuildMenu.needs_room(Rect2(700.0, bottom - 50.0, 80.0, 60.0), port), "under the bar"
	)
	assert_true(BuildMenu.needs_room(Rect2(700.0, HudLayout.TOP_CLEAR - 5.0, 80.0, 60.0), port))
	assert_true(BuildMenu.needs_room(Rect2(-90.0, 300.0, 80.0, 60.0), port), "off the left")
	assert_true(BuildMenu.needs_room(Rect2(1500.0, 300.0, 80.0, 60.0), port), "off the right")
