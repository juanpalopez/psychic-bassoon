## The tour and the guide in the main scene: opened from the Menu, they pause the game.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


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


func test_a_headless_run_does_not_open_the_tour_by_itself() -> void:
	var main := await _main()
	assert_false((_node(main, Tour) as Tour).is_open())


func test_the_menu_shows_how_to_play_and_the_tower_guide() -> void:
	var main := await _main()
	var how := main.get_node("Hud/HowToPlay") as Button
	var guide := main.get_node("Hud/TowerGuide") as Button
	assert_false(how.visible)
	assert_false(guide.visible)
	(main.get_node("Hud/MenuButton") as Button).button_pressed = true
	assert_true(how.visible)
	assert_true(guide.visible)


func test_how_to_play_opens_the_tour_and_pauses_until_it_finishes() -> void:
	var main := await _main()
	var tour := _node(main, Tour) as Tour
	main.get_node("Hud/HowToPlay").pressed.emit()
	assert_true(tour.is_open())
	assert_eq(main._speed.ticks_speed(), 0, "the game waits behind the tour")
	tour.skip_button().pressed.emit()
	assert_gt(main._speed.ticks_speed(), 0, "and carries on after it")


func test_a_game_the_player_paused_stays_paused_after_the_tour() -> void:
	var main := await _main()
	main._speed.paused = true
	main.get_node("Hud/HowToPlay").pressed.emit()
	(_node(main, Tour) as Tour).skip_button().pressed.emit()
	assert_true(main._speed.paused)


func test_finishing_the_tour_remembers_it() -> void:
	var main := await _main()
	var memory := {}
	main._progress = TourProgress.new(
		func() -> bool: return memory.get("seen", false), func() -> void: memory["seen"] = true
	)
	main.get_node("Hud/HowToPlay").pressed.emit()
	assert_false(main._progress.seen())
	(_node(main, Tour) as Tour).skip_button().pressed.emit()
	assert_true(main._progress.seen())


func test_the_tower_guide_opens_pauses_and_closes() -> void:
	var main := await _main()
	var guide := _node(main, GuidePanel) as GuidePanel
	main.get_node("Hud/TowerGuide").pressed.emit()
	assert_true(guide.is_open())
	assert_eq(main._speed.ticks_speed(), 0)
	guide.close_button().pressed.emit()
	assert_false(guide.is_open())
	assert_gt(main._speed.ticks_speed(), 0)


func test_every_tour_target_is_a_control_in_the_hud() -> void:
	var main := await _main()
	for step in preload("res://content/guide.gd").TOUR_STEPS:
		if step.target != "":
			assert_true(main.get_node("Hud").get_node_or_null(step.target) is Control, step.target)
