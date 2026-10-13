## Building a Guard Tent in the main scene: the menu offers it, its guards stand on
## the road, and the panel shows and upgrades it.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _build_tent(main: Node, game: GameState) -> void:
	var menu := main.get_node("Hud/BuildMenu") as BuildMenu
	main.select_cell(game.map.sockets[0])
	var index := menu.tower_buttons().size() - 1
	assert_eq(menu.tower_buttons()[index].text, "Guard Tent  70")
	menu.tower_buttons()[index].pressed.emit()
	main._process(0.05)


func test_the_menu_offers_the_guard_tent_and_building_it_raises_two_guards_on_the_road() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	_build_tent(main, game)
	assert_eq(game.towers[0].type, "guardTent")
	assert_eq(game.guards.size(), 2)
	main._process(0.05)
	var guards := main.get_node("Guards") as GuardsView
	assert_eq(guards.guard_count(), 2)
	for guard in game.guards:
		assert_true(guards.is_shown(guard.id))


func test_the_panel_shows_the_tents_guards_and_upgrades_them() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	_build_tent(main, game)
	main.select_cell(game.map.sockets[0])
	var panel := main.get_node("Hud/TowerPanel") as TowerPanel
	assert_true(panel.visible)
	assert_string_contains(panel.stats_text(), "Guards 60 hp")
	game.buttons = 1000
	panel.upgrade_button().pressed.emit()
	main._process(0.05)
	assert_eq(game.guards[0].max_hp, 100.0)
	assert_string_contains(panel.stats_text(), "Guards 100 hp")


func test_selling_the_tent_takes_its_guards_off_the_road() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	_build_tent(main, game)
	main.select_cell(game.map.sockets[0])
	(main.get_node("Hud/TowerPanel") as TowerPanel).sell_button().pressed.emit()
	main._process(0.05)
	main._process(0.05)
	assert_eq(game.guards.size(), 0)
	assert_eq((main.get_node("Guards") as GuardsView).guard_count(), 0)
