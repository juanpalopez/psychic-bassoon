## Project checks: the project is set up the way the plan says.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func test_renderer_is_forward_plus_with_mobile_for_phones() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"), "mobile")


## Native builds only (the web build was dropped, #318), and the Apple team id stays out
## of the repo: `scripts/ios-run.sh` writes it into the preset only while it exports.
func test_export_presets_are_native_and_carry_no_team_id() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var platforms: Array[String] = []
	var ios := ""
	for section in presets.get_sections():
		if section.ends_with(".options"):
			continue
		var platform := str(presets.get_value(section, "platform"))
		platforms.append(platform)
		if platform == "iOS":
			ios = section
	platforms.sort()
	assert_eq(platforms, ["Linux", "Windows Desktop", "iOS", "macOS"] as Array[String])
	var options := ios + ".options"
	assert_eq(presets.get_value(options, "application/app_store_team_id"), "")
	assert_true(presets.get_value(options, "application/export_project_only"))


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
	assert_gt(board.socket_count, 0)
	assert_eq(board.builds, 1, "the diorama is built once, for the game's own map")
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
## command, and after a tick the tower stands there and the Buttons are spent.
func test_a_tap_and_a_choice_builds_a_tower() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var plot := _first_socket(game)
	main.select_cell(plot)
	var menu := main.get_node("Hud/BuildMenu") as BuildMenu
	assert_true(menu.visible)
	var start_buttons := game.buttons
	menu.tower_buttons()[0].pressed.emit()
	assert_false(menu.visible)
	main._process(0.05)  # long enough for one 30 Hz tick
	assert_eq(game.towers.size(), 1)
	assert_eq(Vector2i(game.towers[0].col, game.towers[0].row), plot)
	assert_lt(game.buttons, start_buttons)
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


func test_a_tap_on_plain_ground_says_to_use_a_socket() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var ground := Vector2i(-1, -1)
	for row in game.map.tiles.size():
		for col in game.map.tiles[row].size():
			var cell := Vector2i(col, row)
			if game.map.tiles[row][col] == GameMap.Tile.PLOT and not game.map.is_socket(cell):
				ground = cell
	main.select_cell(ground)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_eq(
		(main.get_node("Hud/Message") as Label).text,
		RejectText.of(GameEvent.RejectReason.NOT_A_SOCKET)
	)


func test_a_built_tower_stands_on_its_socket() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var socket := _first_socket(game)
	main.select_cell(socket)
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	main._process(0.05)
	var view := main.get_node("Towers").get_child(0) as TowerView
	var top := (main.get_node("Board") as Board).surface_height(socket)
	assert_almost_eq(view.position.y, top, 1e-5)


func test_a_tap_off_the_board_clears_the_selection() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	main.select_cell(_first_socket(game))
	main.select_cell(BoardSpace.NO_CELL)
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_false((main.get_node("Highlight") as CellHighlight).visible)


func test_building_without_the_buttons_shows_the_rejection() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	main.select_cell(_first_socket(game))
	game.buttons = 0
	# the menu disables the buttons itself, so send the command the way a stale
	# menu could
	Game.submit(game, Command.build("spoolGuard", main.selected_cell().x, main.selected_cell().y))
	main._process(0.05)
	assert_eq(game.towers.size(), 0)
	assert_string_contains(
		(main.get_node("Hud/Message") as Label).text,
		RejectText.of(GameEvent.RejectReason.NOT_ENOUGH_BUTTONS)
	)


func test_a_new_seed_starts_a_fresh_game() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	main.select_cell(_first_socket(main.game()))
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	main._process(0.05)
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(main.game().seed, 2)
	assert_eq(main.game().towers.size(), 0)
	assert_eq(main.get_node("Towers").get_child_count(), 0)


func test_a_tap_on_a_raised_socket_selects_that_socket() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var board := main.get_node("Board") as Board
	var camera := (main.get_node("CameraRig") as CameraRig).camera()
	for socket in game.map.sockets:
		var top := BoardSpace.cell_to_world(socket.x, socket.y)
		top.y = board.surface_height(socket)
		_tap(main, camera.unproject_position(top))
		# a socket drawn under 44 pt is flown to first and selected when the camera arrives
		for i in 3:
			(main.get_node("CameraRig") as CameraRig)._process(CameraRig.FLY_SECONDS)
		assert_eq(main.selected_cell(), socket, "level %d" % game.map.elevation_at(socket))


func test_a_tap_off_the_board_says_where_to_tap() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	_tap(main, Vector2(-500.0, -500.0))
	assert_eq((main.get_node("Hud/Message") as Label).text, "Tap a socket")
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)


func test_after_game_over_a_plot_does_not_open_the_menu() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	game.over = true
	main.select_cell(_first_socket(game))
	assert_false((main.get_node("Hud/BuildMenu") as BuildMenu).visible)
	assert_eq(
		(main.get_node("Hud/Message") as Label).text,
		RejectText.of(GameEvent.RejectReason.GAME_OVER)
	)


## A tap: the button goes down and comes back up in the same place.
func _tap(main: Node, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		_deliver(main, event)


## The scene sees a press in `_unhandled_input` (if no button took it) and every
## release in `_input`, like the engine does.
func _deliver(main: Node, event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		main._input(event)
	else:
		main._unhandled_input(event)


func _first_socket(game: GameState) -> Vector2i:
	return game.map.sockets[0]
