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
