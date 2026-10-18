## The 44 pt rule in the game (#328): at the overview a tap on a socket or a tower flies the
## camera in to it before anything opens, and building, upgrading and selling happen only where
## the socket is drawn at least 44 pt.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


## The game on the 844x390 pt phone: its 1558x720 canvas, 390/720 of a point per pixel.
func _main() -> Node:
	var port := SubViewport.new()
	port.size = Vector2i(1558, 720)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	main.points_per_pixel = 390.0 / 720.0
	port.add_child(main)
	await get_tree().process_frame
	return main


func _size(main: Node) -> Vector2:
	return main.get_viewport().get_visible_rect().size


func _rig(main: Node) -> CameraRig:
	return main.get_node("CameraRig") as CameraRig


func _menu(main: Node) -> BuildMenu:
	return main.get_node("Hud/BuildMenu") as BuildMenu


func _panel(main: Node) -> TowerPanel:
	return main.get_node("Hud/TowerPanel") as TowerPanel


func _top(main: Node, anchor: Vector2i) -> Vector3:
	var game: GameState = main.game()
	var top := BoardSpace.footprint_centre(anchor, game.map.footprint)
	top.y = (main.get_node("Board") as Board).surface_height(anchor)
	return top


func _tap(main: Node, position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		if pressed:
			main._unhandled_input(event)
		else:
			main._input(event)


func _tap_socket(main: Node, anchor: Vector2i) -> void:
	_tap(main, _rig(main).camera().unproject_position(_top(main, anchor)))


func _overview(main: Node) -> void:
	_rig(main).set_zoom(0.0)
	_rig(main).show_point(Vector3.ZERO, 0.0)


## A free socket that the overview draws under 44 pt (on the phone, all of them).
func _small_socket(main: Node) -> Vector2i:
	var game: GameState = main.game()
	for anchor in game.map.sockets:
		if not main.socket_tappable(anchor):
			return anchor
	return GameMap.NO_SOCKET


func _land(main: Node) -> void:
	for i in 3:
		_rig(main)._process(CameraRig.FLY_SECONDS)


func test_a_run_starts_on_the_spawn_side() -> void:
	var main: Node = await _main()
	var rig := _rig(main)
	var game: GameState = main.game()
	assert_gte(rig.zoom, CameraRig.START_MIN_ZOOM, "not the overview")
	var spawn := BoardSpace.cell_to_world(game.map.path[0].x, game.map.path[0].y)
	var size := _size(main)
	var at := rig.camera().unproject_position(spawn)
	assert_true(Rect2(Vector2.ZERO, size).has_point(at), "the spawn is on screen: %s" % at)
	assert_lt(at.x, size.x / 2.0, "on the left half")


func test_next_seed_starts_the_new_map_on_its_spawn_side_too() -> void:
	var main: Node = await _main()
	_overview(main)
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_gte(_rig(main).zoom, CameraRig.START_MIN_ZOOM)


func test_the_overview_is_too_small_to_build_on() -> void:
	var main: Node = await _main()
	_overview(main)
	assert_ne(_small_socket(main), GameMap.NO_SOCKET, "the overview draws sockets under 44 pt")


func test_a_tap_at_the_overview_flies_in_to_the_socket_and_then_opens_the_menu() -> void:
	var main: Node = await _main()
	_overview(main)
	var anchor := _small_socket(main)
	_tap_socket(main, anchor)
	var rig := _rig(main)
	assert_true(rig.flying(), "the camera flies in")
	assert_false(_menu(main).visible, "nothing opens before the camera arrives")
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)
	_land(main)
	assert_false(rig.flying())
	assert_true(main.socket_tappable(anchor), "the socket is drawn at least 44 pt")
	assert_eq(main.selected_cell(), anchor)
	assert_true(_menu(main).visible, "the build menu opens on arrival")
	var screen := rig.camera().unproject_position(_top(main, anchor))
	var size := _size(main)
	assert_true(Rect2(size * 0.25, size * 0.5).has_point(screen), "centred: %s" % screen)


func test_a_drag_during_the_flight_takes_the_camera_back_and_opens_nothing() -> void:
	var main: Node = await _main()
	_overview(main)
	var anchor := _small_socket(main)
	_tap_socket(main, anchor)
	var rig := _rig(main)
	rig._process(CameraRig.FLY_SECONDS / 3.0)
	var drag := InputEventMouseButton.new()
	drag.button_index = MOUSE_BUTTON_LEFT
	drag.pressed = true
	drag.position = Vector2(600.0, 300.0)
	main._unhandled_input(drag)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = Vector2(500.0, 300.0)
	main._unhandled_input(motion)
	assert_false(rig.flying(), "the drag ended the flight")
	_land(main)
	assert_false(_menu(main).visible)
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)


func test_a_tap_on_a_tower_at_the_overview_flies_in_before_the_panel_opens() -> void:
	var main: Node = await _main()
	var game: GameState = main.game()
	var anchor: Vector2i = game.map.sockets[0]
	main.select_cell(anchor)
	_menu(main).tower_buttons()[0].pressed.emit()
	main._process(0.05)
	assert_eq(game.towers.size(), 1, "a tower stands on the socket")
	_overview(main)
	assert_false(main.socket_tappable(anchor), "the overview draws it under 44 pt")
	_tap_socket(main, anchor)
	assert_null(_panel(main).tower(), "no panel before the camera arrives")
	_land(main)
	assert_not_null(_panel(main).tower(), "the tower panel opens on arrival")


func test_a_tap_where_the_socket_is_big_enough_opens_the_menu_at_once() -> void:
	var main: Node = await _main()
	var game: GameState = main.game()
	var anchor: Vector2i = game.map.sockets[0]
	_rig(main).show_point(_top(main, anchor), 1.0)
	_tap_socket(main, anchor)
	assert_false(_rig(main).flying())
	assert_true(_menu(main).visible)
	assert_eq(main.selected_cell(), anchor)


func test_zooming_out_past_44_points_closes_the_build_menu() -> void:
	var main: Node = await _main()
	var game: GameState = main.game()
	var anchor: Vector2i = game.map.sockets[0]
	_rig(main).show_point(_top(main, anchor), 1.0)
	_tap_socket(main, anchor)
	assert_true(_menu(main).visible)
	# a little zoom out keeps it open while the socket is still big
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	main._unhandled_input(wheel)
	main._process(0.0)
	assert_true(main.socket_tappable(anchor))
	assert_true(_menu(main).visible, "still big enough")
	# all the way out: too small to build on
	_rig(main).zoom_steps(-100.0)
	main._process(0.0)
	assert_false(main.socket_tappable(anchor))
	assert_false(_menu(main).visible, "the menu closed")
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)
