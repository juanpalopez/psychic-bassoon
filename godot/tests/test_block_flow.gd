## Tapping, building and shooting on 2x2 socket blocks in the main scene.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	main.set_process(false)
	return main


func test_tapping_any_cell_of_a_block_selects_its_anchor_and_opens_the_build_menu() -> void:
	var main := await _main()
	var map: GameMap = main.game().map
	var anchor := map.sockets[0]
	for cell in [anchor, anchor + Vector2i(1, 0), anchor + Vector2i(0, 1), anchor + Vector2i(1, 1)]:
		main.select_cell(cell)
		assert_eq(main.selected_cell(), anchor, str(cell))
		assert_true((main.get_node("Hud/BuildMenu") as BuildMenu).visible, str(cell))
		assert_eq(
			(main.get_node("Hud/BuildMenu") as BuildMenu).cell, anchor, "the menu is for the block"
		)
		var highlight := main.get_node("Highlight") as CellHighlight
		assert_true(highlight.visible)
		assert_almost_eq(highlight.scale.x, 2.0, 1e-9)


func test_a_built_tower_stands_at_the_blocks_centre_and_any_cell_opens_its_panel() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var anchor := game.map.sockets[0]
	main.select_cell(anchor + Vector2i(1, 1))
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	main._process(0.05)
	assert_eq(Vector2i(game.towers[0].col, game.towers[0].row), anchor)
	var view := main.get_node("Towers").get_child(0) as TowerView
	var middle := BoardSpace.footprint_centre(anchor, 2)
	assert_almost_eq(view.position.x, middle.x, 1e-5)
	assert_almost_eq(view.position.z, middle.z, 1e-5)
	main.select_cell(anchor + Vector2i(1, 0))
	assert_true((main.get_node("Hud/TowerPanel") as TowerPanel).visible)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	var ring := main.get_node("RangeRing") as RangeRing
	assert_true(ring.visible)
	assert_almost_eq(ring.position.x, middle.x, 1e-5)
	assert_almost_eq(ring.position.z, middle.z, 1e-5)


func test_a_shot_leaves_from_over_the_blocks_centre() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	var shots := main.get_node("Shots") as ShotsView
	assert_gt(shots.visible_shots(), 0)
	var middle := BoardSpace.footprint_centre(Vector2i(scene.tower.col, scene.tower.row), 2)
	assert_almost_eq(shots.drawn_from(0).x, middle.x, 1e-5)
	assert_almost_eq(shots.drawn_from(0).z, middle.z, 1e-5)


func test_the_road_is_not_a_socket_and_open_ground_asks_for_a_socket() -> void:
	var main := await _main()
	var game: GameState = main.game()
	main.select_cell(game.map.path[3])
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	var ground := Vector2i(-1, -1)
	for row in game.map.rows:
		for col in game.map.cols:
			var cell := Vector2i(col, row)
			if (
				game.map.tiles[row][col] != GameMap.Tile.ROAD
				and game.map.socket_anchor_at(cell) == GameMap.NO_SOCKET
			):
				ground = cell
				break
		if ground != Vector2i(-1, -1):
			break
	main.select_cell(ground)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_string_contains((main.get_node("Hud/Message") as Label).text, "socket")
