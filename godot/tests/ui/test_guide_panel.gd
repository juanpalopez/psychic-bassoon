## The tower guide: one entry per tower, with a Close button.
extends GutTest

const TOWERS := preload("res://content/towers.gd")
const GUIDE := preload("res://content/guide.gd")


func _panel() -> GuidePanel:
	var panel := GuidePanel.new()
	add_child_autofree(panel)
	return panel


func test_it_is_hidden_until_opened() -> void:
	var panel := _panel()
	assert_false(panel.visible)
	panel.open()
	assert_true(panel.visible)
	assert_true(panel.is_open())


func test_it_has_one_entry_per_tower_in_order() -> void:
	var panel := _panel()
	assert_eq(panel.entry_count(), TOWERS.TOWER_IDS.size())
	for i in TOWERS.TOWER_IDS.size():
		var id: String = TOWERS.TOWER_IDS[i]
		assert_string_contains(panel.entry_text(i), TOWERS.DEFS[id].name)
		assert_string_contains(panel.entry_text(i), GUIDE.TOWERS[id].tip)
		assert_string_contains(panel.entry_text(i), GuideText.stats(TOWERS.DEFS[id]))


func test_close_hides_it_and_announces() -> void:
	var panel := _panel()
	watch_signals(panel)
	panel.open()
	panel.close_button().pressed.emit()
	assert_false(panel.visible)
	assert_signal_emitted(panel, "closed")


func test_the_close_button_is_big_enough_for_a_thumb() -> void:
	var button := _panel().close_button()
	assert_gte(button.custom_minimum_size.y * 0.54, 44.0)
	assert_gte(button.custom_minimum_size.x * 0.54, 44.0)


func test_it_covers_the_viewport_with_the_card_in_the_middle() -> void:
	var panel := _panel()
	panel.open()
	assert_eq(panel.size, panel.get_viewport_rect().size)
	var middle := panel.get_viewport_rect().size / 2.0
	var card := panel.card()
	assert_almost_eq(card.position.x + card.size.x / 2.0, middle.x, 1.0)
	assert_almost_eq(card.position.y + card.size.y / 2.0, middle.y, 1.0)


func test_it_catches_taps_meant_for_the_game_underneath() -> void:
	assert_eq(_panel().mouse_filter, Control.MOUSE_FILTER_STOP)
