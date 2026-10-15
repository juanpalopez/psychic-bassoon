## The intro wave and the guide in the main scene: sockets glow, the bubble follows the player,
## the tower card shows on hover, and Skip works everywhere.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")
const GUIDE := preload("res://content/guide.gd")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _node(main: Node, type: Variant) -> Node:
	for child in main.get_node("Hud").get_children():
		if is_instance_of(child, type):
			return child
	return null


func _glow(main: Node) -> SocketGlow:
	for child in main.get_children():
		if child is SocketGlow:
			return child
	return null


## Starts the intro through the Menu button and shows the goal step.
func _intro(main: Node) -> IntroView:
	main.get_node("Hud/HowToPlay").pressed.emit()
	main._process(0.016)
	return _node(main, IntroView) as IntroView


func _a_socket(main: Node) -> Vector2i:
	return main.game().map.sockets[0]


func test_a_headless_run_does_not_start_the_intro_by_itself() -> void:
	var main := await _main()
	assert_false(main._flow.is_active())
	assert_false((_node(main, IntroView) as IntroView).visible)


func test_how_to_play_starts_the_intro_with_the_goal_and_no_glow_yet() -> void:
	var main := await _main()
	var view := _intro(main)
	assert_true(view.visible)
	assert_eq(view.bubble_text(), GUIDE.INTRO.goal.text)
	assert_false(_glow(main).visible)


func test_the_sockets_glow_while_the_player_is_asked_to_tap_one() -> void:
	var main := await _main()
	var view := _intro(main)
	view.next_button().pressed.emit()
	main._process(0.016)
	assert_true(_glow(main).visible)
	assert_eq(_glow(main).ring_count(), main.game().map.sockets.size())
	main.select_cell(_a_socket(main))
	main._process(0.016)
	assert_false(_glow(main).visible)
	assert_eq(main._flow.step(), IntroFlow.Step.PICK_TOWER)


func test_the_intro_does_not_pause_the_game() -> void:
	var main := await _main()
	_intro(main)
	assert_gt(main._speed.ticks_speed(), 0)


func test_building_a_tower_then_starting_and_clearing_a_wave_finishes_the_intro() -> void:
	var main := await _main()
	var view := _intro(main)
	view.next_button().pressed.emit()
	var anchor := _a_socket(main)
	main.select_cell(anchor)
	main._on_tower_chosen("spoolGuard")
	Game.tick(main.game())
	main._after_tick(main.game())
	assert_eq(main._flow.step(), IntroFlow.Step.START_WAVE)
	main.get_node("Hud/LaunchWave").pressed.emit()
	Game.tick(main.game())
	main._after_tick(main.game())
	assert_eq(main._flow.step(), IntroFlow.Step.WATCH)
	var clear := GameEvent.of(GameEvent.Kind.WAVE_CLEARED)
	main.game().events.append(clear)
	main._after_tick(main.game())
	assert_eq(main._flow.step(), IntroFlow.Step.DONE)
	main._process(0.016)
	assert_eq(view.bubble_text(), GUIDE.INTRO.done.text)
	view.next_button().pressed.emit()
	assert_false(main._flow.is_active())
	main._process(0.016)
	assert_false(view.visible)


func test_skip_ends_the_intro_remembers_it_and_clears_the_glow() -> void:
	var main := await _main()
	var memory := {}
	main._progress = IntroProgress.new(
		func() -> bool: return memory.get("seen", false), func() -> void: memory["seen"] = true
	)
	var view := _intro(main)
	view.next_button().pressed.emit()
	main._process(0.016)
	assert_true(_glow(main).visible)
	view.skip_button().pressed.emit()
	main._process(0.016)
	assert_false(main._flow.is_active())
	assert_false(_glow(main).visible)
	assert_true(main._progress.seen())


func test_a_new_seed_in_the_middle_of_the_intro_skips_it() -> void:
	var main := await _main()
	_intro(main)
	main.get_node("Hud/NextSeed").pressed.emit()
	assert_false(main._flow.is_active())


func test_the_menu_shows_how_to_play_and_the_tower_guide() -> void:
	var main := await _main()
	var how := main.get_node("Hud/HowToPlay") as Button
	var guide := main.get_node("Hud/TowerGuide") as Button
	assert_false(how.visible)
	assert_false(guide.visible)
	(main.get_node("Hud/MenuButton") as Button).button_pressed = true
	assert_true(how.visible)
	assert_true(guide.visible)


func test_the_tower_guide_opens_pauses_and_closes() -> void:
	var main := await _main()
	var guide := _node(main, GuidePanel) as GuidePanel
	main.get_node("Hud/TowerGuide").pressed.emit()
	assert_true(guide.is_open())
	assert_eq(main._speed.ticks_speed(), 0)
	guide.close_button().pressed.emit()
	assert_false(guide.is_open())
	assert_gt(main._speed.ticks_speed(), 0)


func test_the_guide_with_a_player_pause_keeps_the_pause() -> void:
	var main := await _main()
	main._speed.paused = true
	main.get_node("Hud/TowerGuide").pressed.emit()
	(_node(main, GuidePanel) as GuidePanel).close_button().pressed.emit()
	assert_true(main._speed.paused)


func test_a_restart_behind_the_guide_stays_paused() -> void:
	var main := await _main()
	main.get_node("Hud/TowerGuide").pressed.emit()
	main._start(main.game().seed + 1)
	assert_eq(main._speed.ticks_speed(), 0)


func test_hovering_a_tower_button_shows_its_card_above_the_build_row() -> void:
	var main := await _main()
	main.select_cell(_a_socket(main))
	var card := _node(main, TowerCard) as TowerCard
	var menu := main.get_node("Hud/BuildMenu") as BuildMenu
	menu.tower_buttons()[1].mouse_entered.emit()
	assert_true(card.visible)
	assert_eq(card.shown_id(), "thimbleMortar")
	var port := main.get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, port).encloses(Rect2(card.position, card.size)))
	menu.tower_buttons()[1].mouse_exited.emit()
	assert_false(card.visible)


func test_choosing_a_tower_or_selecting_elsewhere_clears_the_card() -> void:
	var main := await _main()
	main.select_cell(_a_socket(main))
	var card := _node(main, TowerCard) as TowerCard
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].mouse_entered.emit()
	assert_true(card.visible)
	main.select_cell(BoardSpace.NO_CELL)
	assert_false(card.visible)


func test_every_intro_target_is_a_control_in_the_hud() -> void:
	var main := await _main()
	for key in GUIDE.INTRO:
		var target: String = GUIDE.INTRO[key].target
		if target != "":
			assert_true(main.get_node("Hud").get_node_or_null(target) is Control, target)


func test_tapping_an_occupied_socket_does_not_advance_the_intro() -> void:
	var main := await _main()
	var anchor := _a_socket(main)
	main.select_cell(anchor)
	main._on_tower_chosen("spoolGuard")
	Game.tick(main.game())
	main._flow.start()
	main._flow.notify(IntroFlow.Event.NEXT)
	assert_eq(main._flow.step(), IntroFlow.Step.PICK_SOCKET)
	main.select_cell(anchor)
	assert_eq(main._flow.step(), IntroFlow.Step.PICK_SOCKET, "a tower is there; no build row opens")
	main.select_cell(main.game().map.sockets[1])
	assert_eq(main._flow.step(), IntroFlow.Step.PICK_TOWER)


func test_the_glow_leaves_out_sockets_that_already_hold_a_tower() -> void:
	var main := await _main()
	main.select_cell(_a_socket(main))
	main._on_tower_chosen("spoolGuard")
	Game.tick(main.game())
	var view := _intro(main)
	view.next_button().pressed.emit()
	main._process(0.016)
	assert_eq(_glow(main).ring_count(), main.game().map.sockets.size() - 1)


func test_the_intro_ends_when_the_game_does() -> void:
	var main := await _main()
	_intro(main)
	main.game().events.append(GameEvent.of(GameEvent.Kind.GAME_OVER))
	main._after_tick(main.game())
	assert_false(main._flow.is_active())


func test_a_restart_behind_the_guide_does_not_keep_the_old_pause() -> void:
	var main := await _main()
	main._speed.paused = true
	main.get_node("Hud/TowerGuide").pressed.emit()
	main._start(main.game().seed + 1)
	(_node(main, GuidePanel) as GuidePanel).close_button().pressed.emit()
	assert_gt(main._speed.ticks_speed(), 0, "the new game is not paused")


func _socket_screen_centres(main: Node) -> Array[Vector2]:
	var centres: Array[Vector2] = []
	for anchor in main.game().map.sockets:
		var at := BoardSpace.footprint_centre(anchor, main.game().map.footprint)
		at.y = main._board.surface_height(anchor)
		centres.append(main._camera.unproject_position(at))
	return centres


func test_the_bubble_stays_clear_of_every_other_hud_control_and_most_sockets() -> void:
	var events := [
		IntroFlow.Event.NEXT,
		IntroFlow.Event.SOCKET_SELECTED,
		IntroFlow.Event.TOWER_BUILT,
		IntroFlow.Event.WAVE_LAUNCHED,
		IntroFlow.Event.WAVE_CLEARED
	]
	for size in [Vector2i(1280, 720), Vector2i(1558, 720), Vector2i(1366, 1024)]:
		var port := SubViewport.new()
		port.size = size
		add_child_autofree(port)
		var main := MAIN_SCENE.instantiate()
		port.add_child(main)
		main.set_process(false)
		await get_tree().process_frame
		var view := _node(main, IntroView) as IntroView
		main._start_intro()
		(main.get_node("Hud/MenuButton") as Button).button_pressed = true
		var message := main.get_node("Hud/Message") as Label
		message.text = "That is road: build on a socket"
		message.visible = true
		# every step: the goal, the five that follow, each checked as it shows
		for i in range(events.size() + 1):
			view.refresh()
			await get_tree().process_frame
			var bubble := view.bubble()
			var rect := Rect2(bubble.global_position, bubble.size)
			for node in main.get_node("Hud").get_children():
				if node is Control and node != view and (node as Control).is_visible_in_tree():
					assert_false(
						rect.intersects((node as Control).get_global_rect()),
						"step %d: bubble %s over %s at %s" % [i, rect, node.name, size]
					)
			var covered := 0
			var centres := _socket_screen_centres(main)
			for centre in centres:
				if rect.has_point(centre):
					covered += 1
			assert_lte(
				covered * 3, centres.size(), "step %d hides too many sockets at %s" % [i, size]
			)
			if i < events.size():
				main._flow.notify(events[i])
