## The Menu's dropdown never stands between the player and the board: a tap on the world
## closes it, and flows that start from one of its items close it first.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func test_a_tap_on_the_world_closes_the_menu_and_selects_nothing() -> void:
	var main := await _main()
	var menu_button := main.get_node("Hud/MenuButton") as Button
	menu_button.button_pressed = true
	var anchor: Vector2i = main.game().map.sockets[0]
	main._on_tap(main._socket_on_screen(anchor).get_center())
	assert_false(menu_button.button_pressed, "the dropdown closed")
	assert_false((main.get_node("Hud/NextSeed") as Control).visible)
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL, "the tap only closed the menu")


func test_how_to_play_from_the_menu_closes_it_so_the_tour_gets_the_first_tap() -> void:
	var main := await _main()
	var menu_button := main.get_node("Hud/MenuButton") as Button
	menu_button.button_pressed = true
	(main.get_node("Hud/HowToPlay") as Button).pressed.emit()
	assert_false(menu_button.button_pressed, "the dropdown closed")
	main._flow.skip()
	menu_button.button_pressed = true
	(main.get_node("Hud/TowerGuide") as Button).pressed.emit()
	assert_false(menu_button.button_pressed, "the guide closes it too")
