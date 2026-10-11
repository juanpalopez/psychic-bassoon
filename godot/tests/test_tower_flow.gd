## Selecting, upgrading and selling a built tower in the main scene.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _first_socket(game: GameState) -> Vector2i:
	return game.map.sockets[0]


func _build_first_tower(main: Node, game: GameState) -> Vector2i:
	var socket := _first_socket(game)
	main.select_cell(socket)
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	main._process(0.05)
	return socket


func test_tapping_a_built_tower_opens_its_panel_and_ring_not_the_build_menu() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _build_first_tower(main, game)
	main.select_cell(socket)
	var panel := main.get_node("Hud/TowerPanel") as TowerPanel
	var ring := main.get_node("RangeRing") as RangeRing
	assert_true(panel.visible)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_true(ring.visible)
	assert_almost_eq(ring.radius(), TowerInfo.effective_range(game.map, game.towers[0]), 1e-5)


func test_upgrading_from_the_panel_sends_a_command_and_the_ring_follows() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _build_first_tower(main, game)
	main.select_cell(socket)
	var ring := main.get_node("RangeRing") as RangeRing
	var before := ring.radius()
	game.buttons = 1000
	(main.get_node("Hud/TowerPanel") as TowerPanel).upgrade_button().pressed.emit()
	main._process(0.05)
	assert_eq(game.towers[0].level, 1)
	assert_gt(ring.radius(), before)
	assert_true((main.get_node("Hud/TowerPanel") as TowerPanel).visible)


func test_selling_from_the_panel_removes_the_tower_and_closes_panel_and_ring() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _build_first_tower(main, game)
	main.select_cell(socket)
	var before: int = game.buttons
	(main.get_node("Hud/TowerPanel") as TowerPanel).sell_button().pressed.emit()
	main._process(0.05)
	assert_eq(game.towers.size(), 0)
	assert_eq(game.buttons, before + 35)
	assert_false((main.get_node("Hud/TowerPanel") as TowerPanel).visible)
	assert_false((main.get_node("RangeRing") as RangeRing).visible)


func test_tapping_elsewhere_closes_the_panel_and_ring() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _build_first_tower(main, game)
	main.select_cell(socket)
	main.select_cell(BoardSpace.NO_CELL)
	assert_false((main.get_node("Hud/TowerPanel") as TowerPanel).visible)
	assert_false((main.get_node("RangeRing") as RangeRing).visible)


func test_the_panel_range_is_the_rings_range() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _build_first_tower(main, game)
	main.select_cell(socket)
	var reach := TowerInfo.effective_range(game.map, game.towers[0])
	assert_string_contains(
		(main.get_node("Hud/TowerPanel") as TowerPanel).stats_text(), "Range %s" % reach
	)
