## Project checks: the project is set up the way the plan says.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func test_renderer_is_compatibility_for_web() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.web"), "gl_compatibility"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility"
	)


func test_game_is_landscape_only() -> void:
	# 0 is landscape in Godot's DisplayServer.ScreenOrientation
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0)


func test_main_scene_is_set_and_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(path, "res://main.tscn")
	var scene := load(path) as PackedScene
	assert_not_null(scene)


func test_main_scene_draws_the_board_with_a_camera() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var board := main.get_node("Board") as Board
	assert_not_null(board)
	assert_gt(board.road_count, 0)
	assert_gt(board.plot_count, 0)
	var rig := main.get_node("CameraRig") as CameraRig
	assert_not_null(rig)
	assert_not_null(rig.get_child(0) as Camera3D)
	assert_eq(main.get_node("Hud/NextSeed").get("text"), "Next seed")


func test_next_seed_button_rebuilds_the_board() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var board := main.get_node("Board") as Board
	var before := board.map.path
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(board.map_seed, 2)
	assert_ne(board.map.path, before)


func test_engine_matches_pinned_version() -> void:
	var pinned := (
		FileAccess
		. get_file_as_string(ProjectSettings.globalize_path("res://") + "../.godot-version")
		. strip_edges()
	)
	var info := Engine.get_version_info()
	var running := "%d.%d.%d-%s" % [info.major, info.minor, info.patch, info.status]
	assert_eq(running, pinned)


## A tap on a free plot opens the build menu, choosing a tower sends a build
## command, and after a tick the tower stands there and the gold is spent.
func test_a_tap_and_a_choice_builds_a_tower() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var plot := _first_plot(game)
	main.select_cell(plot)
	var menu := main.get_node("Hud/BuildMenu") as BuildMenu
	assert_true(menu.visible)
	var start_gold := game.gold
	menu.buttons()[0].pressed.emit()
	assert_false(menu.visible)
	main._process(0.05)  # long enough for one 30 Hz tick
	assert_eq(game.towers.size(), 1)
	assert_eq(Vector2i(game.towers[0].col, game.towers[0].row), plot)
	assert_lt(game.gold, start_gold)
	assert_eq(main.get_node("Towers").get_child_count(), 1)
	assert_false(
		(main.get_node("Highlight") as CellHighlight).visible, "selection clears after a build"
	)


func test_a_tap_on_the_road_shows_a_message_and_no_menu() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	main.select_cell(game.map.path[3])
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_ne((main.get_node("Hud/Message") as Label).text, "")


func test_a_tap_off_the_board_clears_the_selection() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	main.select_cell(_first_plot(game))
	main.select_cell(BoardSpace.NO_CELL)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_false((main.get_node("Highlight") as CellHighlight).visible)


func test_building_without_the_gold_shows_the_rejection() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	main.select_cell(_first_plot(game))
	game.gold = 0
	# the menu disables the buttons itself, so send the command the way a stale
	# menu could
	Game.submit(game, Command.build("ballista", main.selected_cell().x, main.selected_cell().y))
	main._process(0.05)
	assert_eq(game.towers.size(), 0)
	assert_string_contains(
		(main.get_node("Hud/Message") as Label).text,
		RejectText.of(GameEvent.RejectReason.NOT_ENOUGH_GOLD)
	)


func test_a_new_seed_starts_a_fresh_game() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	main.select_cell(_first_plot(main.game()))
	(main.get_node("Hud/BuildMenu") as BuildMenu).buttons()[0].pressed.emit()
	main._process(0.05)
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(main.game().seed, 2)
	assert_eq(main.game().towers.size(), 0)
	assert_eq(main.get_node("Towers").get_child_count(), 0)


func _first_plot(game: GameState) -> Vector2i:
	for row in game.map.tiles.size():
		for col in game.map.tiles[row].size():
			if game.map.tiles[row][col] == GameMap.Tile.PLOT:
				return Vector2i(col, row)
	return BoardSpace.NO_CELL
