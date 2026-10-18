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


## A finger going down or up the way the engine delivers it: the touch event goes
## to `_input` and (if no button took it) to `_unhandled_input`; the first finger
## also arrives as an emulated mouse press or release.
func _finger(main: Node, index: int, position: Vector2, pressed: bool, mouse: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	touch.position = position
	main._input(touch)
	if pressed:
		main._unhandled_input(touch)
	if mouse:
		_press(main, position, pressed)


func _move_to(main: Node, position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	main._unhandled_input(motion)


## A tap on a socket drawn under 44 pt flies the camera in first and selects it on arrival.
func _land(main: Node) -> void:
	var rig := main.get_node("CameraRig") as CameraRig
	for i in 3:
		rig._process(CameraRig.FLY_SECONDS)


## Puts a socket in the middle of the screen at the closest zoom, where a tap selects it at once.
func _close_on(main: Node, socket: Vector2i) -> void:
	var game: GameState = main.game()
	var rig := main.get_node("CameraRig") as CameraRig
	rig.show_point(BoardSpace.footprint_centre(socket, game.map.footprint), 1.0)


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
	var start := rig.zoom
	assert_gte(start, CameraRig.START_MIN_ZOOM, "a run starts on the spawn side, not the overview")
	for wheel in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_UP]:
		var event := InputEventMouseButton.new()
		event.button_index = wheel
		event.pressed = true
		main._unhandled_input(event)
	assert_almost_eq(rig.zoom, start + 2.0 * CameraRig.WHEEL_STEP, 1e-9)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	main._unhandled_input(down)
	assert_almost_eq(rig.zoom, start + CameraRig.WHEEL_STEP, 1e-9)


func test_a_second_finger_pinches_to_zoom() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	_finger(main, 0, Vector2(400.0, 300.0), true, true)
	_finger(main, 1, Vector2(500.0, 300.0), true, false)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(700.0, 300.0)
	main._unhandled_input(drag)
	assert_gt(rig.zoom, 0.0, "spreading the fingers zoomed in")
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)


func test_a_tap_with_a_first_finger_that_is_not_index_0_selects_the_socket() -> void:
	# Safari numbers its touches from wherever it left off, so the first finger can be 7
	for index in [0, 1, 7]:
		var main := MAIN_SCENE.instantiate()
		add_child_autofree(main)
		await get_tree().process_frame
		var game: GameState = main.game()
		var camera := (main.get_node("CameraRig") as CameraRig).camera()
		var socket: Vector2i = game.map.sockets[0]
		_close_on(main, socket)
		var at := BoardSpace.footprint_centre(socket, game.map.footprint)
		var position := camera.unproject_position(at)
		_finger(main, index, position, true, true)
		_finger(main, index, position, false, true)
		assert_eq(main.selected_cell(), socket, "a tap with finger index %d" % index)


func test_a_finger_a_button_took_still_counts_so_another_finger_can_tap_the_board() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var game: GameState = main.game()
	var camera := (main.get_node("CameraRig") as CameraRig).camera()
	var socket: Vector2i = game.map.sockets[0]
	_close_on(main, socket)
	var position := camera.unproject_position(
		BoardSpace.footprint_centre(socket, game.map.footprint)
	)
	# the first finger lands on a button: the engine takes it as the mouse, the board
	# only sees it in `_input` (a button swallowed it before `_unhandled_input`)
	var on_button := InputEventScreenTouch.new()
	on_button.index = 3
	on_button.pressed = true
	on_button.position = Vector2(50.0, 50.0)
	main._input(on_button)
	# a second finger taps the socket: it is not the mouse, so only its touch events tell
	_finger(main, 4, position, true, false)
	_finger(main, 4, position, false, false)
	assert_eq(main.selected_cell(), socket, "the second finger's tap selects the socket")


func test_the_mouse_finger_lifting_leaves_the_extra_finger_a_pointer_the_next_finger_pinches_with(
) -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	_finger(main, 6, Vector2(400.0, 300.0), true, true)
	_finger(main, 8, Vector2(500.0, 300.0), true, false)
	# the first (mouse) finger lifts, the extra one stays down, a new finger lands
	_finger(main, 6, Vector2(400.0, 300.0), false, true)
	_finger(main, 9, Vector2(450.0, 300.0), true, true)
	var before := rig.zoom
	var drag := InputEventScreenDrag.new()
	drag.index = 8
	drag.position = Vector2(800.0, 300.0)
	main._unhandled_input(drag)
	assert_ne(rig.zoom, before, "the two fingers on the board still pinch")
	assert_eq(main.selected_cell(), BoardSpace.NO_CELL)


func test_a_pinch_with_odd_finger_indexes_still_zooms_and_never_selects() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var rig := main.get_node("CameraRig") as CameraRig
	_finger(main, 5, Vector2(400.0, 300.0), true, true)
	_finger(main, 2, Vector2(500.0, 300.0), true, false)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(700.0, 300.0)
	main._unhandled_input(drag)
	assert_gt(rig.zoom, 0.0, "spreading the fingers zoomed in")
	_finger(main, 2, Vector2(700.0, 300.0), false, false)
	_finger(main, 5, Vector2(400.0, 300.0), false, true)
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
		_land(main)
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
	assert_lte(rig.pan.x, rig.pan_range().end.x + 1e-6)
	assert_gte(rig.pan.x, rig.pan_range().position.x - 1e-6)


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
	var range := rig.pan_range()
	assert_gte(rig.pan.x, range.position.x - 1e-3, "the view settled")
	assert_lte(rig.pan.x, range.end.x + 1e-3, "the view settled")
	# the next touch is a clean tap, not a pinch against a ghost finger
	var game: GameState = main.game()
	var camera := rig.camera()
	var socket := game.map.sockets[3]
	var top := BoardSpace.cell_to_world(socket.x, socket.y)
	top.y = (main.get_node("Board") as Board).surface_height(socket)
	var screen := camera.unproject_position(top)
	_tap(main, screen)
	_land(main)
	var picked: Vector2i = main.selected_cell()
	assert_ne(picked, BoardSpace.NO_CELL, "the next tap works")
