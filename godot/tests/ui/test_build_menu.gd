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


func test_it_opens_above_the_socket_when_there_is_room() -> void:
	var port := Vector2(1280.0, 720.0)
	var socket := Rect2(600.0, 400.0, 80.0, 60.0)
	var at := BuildMenu.placement(socket, Vector2(660.0, 200.0), port)
	assert_eq(at.y, socket.position.y - BuildMenu.SOCKET_GAP - 200.0, "above")
	assert_eq(at.x + 330.0, socket.get_center().x, "centred on the socket")


func test_a_socket_near_the_top_gets_the_menu_below_it() -> void:
	var port := Vector2(1280.0, 720.0)
	var socket := Rect2(600.0, 150.0, 80.0, 60.0)
	var at := BuildMenu.placement(socket, Vector2(660.0, 200.0), port)
	assert_eq(at.y, socket.end.y + BuildMenu.SOCKET_GAP)


func test_a_socket_in_the_middle_band_gets_the_menu_beside_it() -> void:
	var port := Vector2(1280.0, 720.0)
	var menu_size := Vector2(660.0, 210.0)
	# too low for the menu above it, too high for the menu below it
	var right_side := Rect2(1000.0, 320.0, 90.0, 90.0)
	var on_left := Rect2(BuildMenu.placement(right_side, menu_size, port), menu_size)
	assert_lte(on_left.end.x, right_side.position.x, "to the left of a socket on the right")
	var left_side := Rect2(100.0, 320.0, 90.0, 90.0)
	var on_right := Rect2(BuildMenu.placement(left_side, menu_size, port), menu_size)
	assert_gte(on_right.position.x, left_side.end.x, "to the right of a socket on the left")
	assert_lte(on_right.end.x, port.x - BuildMenu.EDGE_MARGIN, "and off the right edge")
	for rect in [on_left, on_right]:
		assert_gte(rect.position.y, BuildMenu.TOP_RESERVE)
		assert_lte(rect.end.y, port.y - BuildMenu.BOTTOM_RESERVE)


func test_a_centre_socket_with_no_room_anywhere_gets_the_compact_menu() -> void:
	var menu := _menu()
	menu.theme = load("res://ui/hud_theme.tres")
	menu.open_for(Vector2i(1, 1), 1000)
	var port := Vector2(1280.0, 720.0)
	# fills the middle: the full menu fits neither above, below, nor beside it
	var socket := Rect2(500.0, 300.0, 140.0, 170.0)
	menu.place_near(socket, port)
	assert_true(menu.compact)
	var rect := Rect2(menu.position, menu.size)
	assert_false(rect.intersects(socket), "never over the socket")
	assert_gte(rect.position.y, BuildMenu.TOP_RESERVE)
	assert_lte(rect.end.y, port.y - BuildMenu.BOTTOM_RESERVE)
	assert_eq(menu.tower_buttons()[0].text, str(TOWERS.DEFS[TOWERS.TOWER_IDS[0]].cost[0]))
	menu.place_near(Rect2(600.0, 500.0, 80.0, 60.0), port)
	assert_false(menu.compact, "the full menu comes back where it fits")


func test_the_last_resort_is_never_over_the_socket() -> void:
	var port := Vector2(1280.0, 720.0)
	var menu_size := Vector2(600.0, 140.0)
	var huge := Rect2(400.0, 200.0, 480.0, 300.0)
	var rect := Rect2(BuildMenu.placement(huge, menu_size, port), menu_size)
	assert_false(rect.intersects(huge))
	assert_true(Rect2(Vector2.ZERO, port).encloses(rect))


func test_the_menu_stays_on_screen_and_clear_of_the_corner_rows() -> void:
	var port := Vector2(1280.0, 720.0)
	var menu_size := Vector2(660.0, 200.0)
	for socket in [
		Rect2(0.0, 600.0, 60.0, 60.0),
		Rect2(1240.0, 120.0, 60.0, 60.0),
		Rect2(640.0, 0.0, 60.0, 60.0)
	]:
		var rect := Rect2(BuildMenu.placement(socket, menu_size, port), menu_size)
		assert_gte(rect.position.x, BuildMenu.EDGE_MARGIN, str(socket))
		assert_lte(rect.end.x, port.x - BuildMenu.EDGE_MARGIN, str(socket))
		assert_gte(rect.position.y, BuildMenu.TOP_RESERVE, str(socket))
		assert_lte(rect.end.y, port.y - BuildMenu.BOTTOM_RESERVE, str(socket))
