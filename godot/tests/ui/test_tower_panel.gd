## The panel for a selected tower: its name, level and stats, and Upgrade and Sell.
extends GutTest


func _tower(type: String, level: int, invested: int) -> Tower:
	var tower := Tower.new()
	tower.id = 7
	tower.type = type
	tower.level = level
	tower.invested = invested
	return tower


func _panel() -> TowerPanel:
	var panel := TowerPanel.new()
	add_child_autofree(panel)
	return panel


func test_it_is_hidden_until_a_tower_is_shown_and_closes() -> void:
	var panel := _panel()
	assert_false(panel.visible)
	panel.show_tower(_tower("ballista", 0, 50), 100)
	assert_true(panel.visible)
	panel.close()
	assert_false(panel.visible)


func test_it_names_the_tower_and_its_level() -> void:
	var panel := _panel()
	panel.show_tower(_tower("frostSpire", 1, 140), 0)
	assert_string_contains(panel.title_text(), "Frost Spire")
	assert_string_contains(panel.title_text(), "Level 2")


func test_it_shows_the_levels_stats_from_the_content() -> void:
	var panel := _panel()
	panel.show_tower(_tower("ballista", 1, 110), 0)
	# level 2 Ballista: damage 15, range 2.6, rate 3.6
	assert_string_contains(panel.stats_text(), "15")
	assert_string_contains(panel.stats_text(), "2.6")
	assert_string_contains(panel.stats_text(), "3.6")


func test_upgrade_shows_its_cost_and_needs_the_buttons() -> void:
	var panel := _panel()
	panel.show_tower(_tower("ballista", 0, 50), 59)
	assert_string_contains(panel.upgrade_button().text, "60")
	assert_true(panel.upgrade_button().disabled, "one Button short")
	panel.set_buttons(60)
	assert_false(panel.upgrade_button().disabled, "an exact fit")


func test_at_the_top_level_there_is_nothing_to_upgrade() -> void:
	var panel := _panel()
	panel.show_tower(_tower("ballista", 2, 220), 9999)
	assert_string_contains(panel.upgrade_button().text, "Max")
	assert_true(panel.upgrade_button().disabled)


func test_sell_shows_the_refund() -> void:
	var panel := _panel()
	panel.show_tower(_tower("catapult", 0, 90), 0)
	assert_string_contains(panel.sell_button().text, "62")
	assert_false(panel.sell_button().disabled)


func test_the_buttons_announce_the_towers_id() -> void:
	var panel := _panel()
	panel.show_tower(_tower("ballista", 0, 50), 1000)
	watch_signals(panel)
	panel.upgrade_button().pressed.emit()
	assert_signal_emitted_with_parameters(panel, "upgrade_pressed", [7])
	panel.sell_button().pressed.emit()
	assert_signal_emitted_with_parameters(panel, "sell_pressed", [7])


func test_the_buttons_are_big_enough_for_a_thumb() -> void:
	# the 1280x720 canvas scales to about 0.54 on a phone; a target stays 44 px
	var panel := _panel()
	assert_gte(panel.upgrade_button().custom_minimum_size.y * 0.54, 44.0)
	assert_gte(panel.sell_button().custom_minimum_size.y * 0.54, 44.0)
