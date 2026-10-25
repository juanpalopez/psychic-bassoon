## The minimap in the game: a jump of the camera closes what a selected socket opened.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func test_a_jump_clears_the_selected_socket_and_closes_the_build_bar() -> void:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	await get_tree().process_frame
	main.select_cell(main.game().map.sockets[0])
	assert_ne(main.selected_cell(), BoardSpace.NO_CELL)
	main._on_minimap_jump(Vector2.ZERO)
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)
	assert_false((main.get_node("Hud/BuildMenu") as Control).visible)
	assert_false((main.get_node("Hud/TowerPanel") as Control).visible)
