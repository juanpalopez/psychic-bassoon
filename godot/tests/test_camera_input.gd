## The camera answers pointers: drags pan, pinches and the wheel zoom, taps
## select, and a release that a button takes cannot leave a finger stuck.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


## A tap: the button goes down and comes back up in the same place.
func _tap(main: Node, position: Vector2) -> void:
	_press(main, position, true)
	_press(main, position, false)


## The scene sees a press in `_unhandled_input` (if no button took it) and every
## release in `_input`, like the engine does.
func _deliver(main: Node, event: InputEvent) -> void:
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		main._input(event)
	else:
		main._unhandled_input(event)


func _move_to(main: Node, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	main._unhandled_input(motion)


func _press(main: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	_deliver(main, event)


func test_a_drag_pans_and_does_not_select() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	rig.canvas_height = 720.0
	rig.set_zoom(1.0)
	var game: GameState = main.game()
	var socket_screen := rig.camera().unproject_position(
		BoardSpace.cell_to_world(game.map.sockets[0].x, game.map.sockets[0].y)
	)
	_press(main, socket_screen, true)
	_move_to(main, socket_screen + Vector2(80.0, 0.0))
	_move_to(main, socket_screen + Vector2(160.0, 0.0))
	_press(main, socket_screen + Vector2(160.0, 0.0), false)
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL, "a drag is not a tap")
	assert_lt(rig.pan.x, 0.0, "the scene followed the finger to the right")


func test_the_wheel_zooms_in_and_out() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	for wheel in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP]:
		var event := InputEventMouseButton.new()
		event.button_index = wheel
		event.pressed = true
		main._unhandled_input(event)
	assert_almost_eq(rig.zoom, 2.0 * CameraRig.WHEEL_STEP, 1e-9)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	main._unhandled_input(down)
	assert_almost_eq(rig.zoom, CameraRig.WHEEL_STEP, 1e-9)


func test_a_second_finger_pinches_to_zoom() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	_press(main, Vector2(400.0, 300.0), true)
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(500.0, 300.0)
	main._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(700.0, 300.0)
	main._unhandled_input(drag)
	assert_gt(rig.zoom, 0.0, "spreading the fingers zoomed in")
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)


func test_a_tap_still_picks_the_right_socket_after_zooming_and_panning() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	rig.canvas_height = 720.0
	rig.set_zoom(0.6)
	rig.pan_by_pixels(Vector2(-120.0, 60.0))
	rig.release_pan()
	var game: GameState = main.game()
	var board := main.get_node("Board") as Board
	var camera := rig.camera()
	var size := get_viewport().get_visible_rect().size
	var tapped := 0
	for socket in game.map.sockets:
		var top := BoardSpace.cell_to_world(socket.x, socket.y)
		top.y = board.surface_height(socket)
		var screen := camera.unproject_position(top)
		if screen.x < 0.0 or screen.y < 0.0 or screen.x > size.x or screen.y > size.y:
			continue
		_tap(main, screen)
		assert_eq(main.selected_cell(), socket)
		tapped += 1
	assert_gt(tapped, 3, "several sockets were on screen to tap")


func test_a_trackpad_pan_moves_the_view_and_settles() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	rig.canvas_height = 720.0
	rig.set_zoom(1.0)
	var swipe := InputEventPanGesture.new()
	swipe.delta = Vector2(5.0, 0.0)
	main._unhandled_input(swipe)
	assert_lt(rig.pan.x, 0.0)
	for i in 120:
		rig._process(1.0 / 60.0)
	assert_lte(absf(rig.pan.x), CameraRig.pan_limit(1.0).x + 1e-6)


func test_letting_go_over_a_button_does_not_leave_a_finger_stuck() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	rig.canvas_height = 720.0
	rig.set_zoom(1.0)
	_press(main, Vector2(600.0, 300.0), true)
	_move_to(main, Vector2(300.0, 300.0))
	_move_to(main, Vector2(-1500.0, 300.0))
	# the release lands on a button: the scene sees it only in _input
	_press(main, Vector2(60.0, 100.0), false)
	# the camera is let go: the overscroll springs back inside the board
	for i in 180:
		rig._process(1.0 / 60.0)
	var limit := CameraRig.pan_limit(1.0)
	assert_lte(absf(rig.pan.x), limit.x + 1e-3, "the view settled")
	# the next touch is a clean tap, not a pinch against a ghost finger
	var game: GameState = main.game()
	var camera := rig.camera()
	var socket := game.map.sockets[3]
	var top := BoardSpace.cell_to_world(socket.x, socket.y)
	top.y = (main.get_node("Board") as Board).surface_height(socket)
	var screen := camera.unproject_position(top)
	_tap(main, screen)
	var picked: Vector2i = main.selected_cell()
	assert_ne(picked, BoardSpace.NO_CELL, "the next tap works")
