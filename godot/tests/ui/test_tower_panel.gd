## The panel for a selected tower: its name, level and stats, and Upgrade and Sell.
extends GutTest

const TOWERS := preload("res://content/towers.gd")
const SPECS := preload("res://content/specs.gd")


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
	panel.show_tower(_tower("spoolGuard", 0, 50), 100)
	assert_true(panel.visible)
	panel.close()
	assert_false(panel.visible)


func test_it_names_the_tower_and_its_level() -> void:
	var panel := _panel()
	panel.show_tower(_tower("prismSpire", 1, 210), 0)
	assert_string_contains(panel.title_text(), "Prism Spire")
	assert_string_contains(panel.title_text(), "Level 2")


func test_it_shows_the_levels_stats_from_the_content() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 1, 110), 0)
	# level 2 Spool Guard: its damage, range and rate from the content
	var def: Dictionary = TOWERS.DEFS.spoolGuard
	assert_string_contains(panel.stats_text(), str(def.damage[1]))
	assert_string_contains(panel.stats_text(), str(def.range[1]))
	assert_string_contains(panel.stats_text(), str(def.rate[1]))


func test_a_beam_tower_shows_damage_per_second_and_no_rate() -> void:
	var panel := _panel()
	panel.show_tower(_tower("prismSpire", 1, 210), 0)
	# level 2 Prism Spire: its damage per second and range from the content
	var def: Dictionary = TOWERS.DEFS.prismSpire
	assert_string_contains(panel.stats_text(), "%d/s" % def.damage[1])
	assert_string_contains(panel.stats_text(), str(def.range[1]))
	assert_false(panel.stats_text().contains("Rate"))


func test_the_range_shown_is_the_one_given_so_it_matches_the_ring() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 1, 110), 0, 2.99)
	assert_string_contains(panel.stats_text(), "Range 2.99")
	panel.set_reach(3.45)
	assert_string_contains(panel.stats_text(), "Range 3.45")


func test_upgrade_shows_its_cost_and_needs_the_buttons() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 0, 50), 59)
	assert_string_contains(panel.upgrade_button().text, "60")
	assert_true(panel.upgrade_button().disabled, "one Button short")
	panel.set_buttons(60)
	assert_false(panel.upgrade_button().disabled, "an exact fit")


func test_at_the_top_level_there_is_nothing_to_upgrade() -> void:
	var panel := _panel()
	panel.show_tower(_tower("thimbleMortar", 2, 220), 9999)
	assert_string_contains(panel.upgrade_button().text, "Max")
	assert_true(panel.upgrade_button().disabled)


func test_sell_shows_the_refund() -> void:
	var panel := _panel()
	panel.show_tower(_tower("thimbleMortar", 0, 90), 0)
	assert_string_contains(panel.sell_button().text, "62")
	assert_false(panel.sell_button().disabled)


func test_the_buttons_announce_the_towers_id() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 0, 50), 1000)
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


func test_at_the_top_level_a_tower_with_specs_offers_them_instead_of_upgrade() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 2, 220), 9999)
	assert_false(panel.upgrade_button().visible)
	assert_false(panel.ability_button().visible)
	var specs: Array = SPECS.for_tower("spoolGuard")
	assert_eq(panel.spec_buttons().size(), specs.size())
	assert_string_contains(panel.spec_buttons()[0].text, specs[0].name)
	assert_string_contains(panel.spec_buttons()[0].text, str(specs[0].cost))
	assert_false(panel.spec_buttons()[0].disabled)
	panel.set_buttons(int(specs[0].cost) - 1)
	assert_true(panel.spec_buttons()[0].disabled, "one Button short")


func test_a_spec_button_announces_the_tower_and_the_spec() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 2, 220), 9999)
	watch_signals(panel)
	panel.spec_buttons()[0].pressed.emit()
	assert_signal_emitted_with_parameters(
		panel, "spec_pressed", [7, SPECS.for_tower("spoolGuard")[0].id]
	)


func test_a_chosen_spec_shows_the_ability_with_its_cooldown() -> void:
	var panel := _panel()
	var tower := _tower("spoolGuard", 2, 360)
	tower.spec = SPECS.for_tower("spoolGuard")[0].id
	panel.show_tower(tower, 0)
	assert_false(panel.upgrade_button().visible)
	assert_true(panel.ability_button().visible)
	assert_string_contains(panel.stats_text(), "Crossbow Ballista")
	assert_string_contains(panel.ability_button().text, "Ready")
	assert_false(panel.ability_button().disabled)
	tower.ability_cooldown = 4.2
	panel.refresh()
	assert_string_contains(panel.ability_button().text, "5 s")
	assert_true(panel.ability_button().disabled)
	tower.ability_cooldown = 0.0
	panel.refresh()
	watch_signals(panel)
	panel.ability_button().pressed.emit()
	assert_signal_emitted_with_parameters(panel, "ability_pressed", [7])


func test_the_new_buttons_are_big_enough_for_a_thumb() -> void:
	var panel := _panel()
	panel.show_tower(_tower("spoolGuard", 2, 220), 9999)
	assert_gte(panel.spec_buttons()[0].custom_minimum_size.y * 0.54, 44.0)
	assert_gte(panel.ability_button().custom_minimum_size.y * 0.54, 44.0)
