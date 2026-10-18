## In the main scene a tower's shot shows up as a dart or a pellet in flight, and a beam
## lasts as long as its lock.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	main.set_process(false)
	return main


func test_a_tower_firing_draws_a_shot_at_the_foe() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	var foe := TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	var shots := main.get_node("Shots") as ShotsView
	assert_gt(shots.visible_shots(), 0)
	assert_eq(shots.drawn_to(0), ShotsView.body_point(foe.x, foe.y))


func test_a_shot_fades_out_over_the_next_frames() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	var foe := TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	foe.hp = foe.max_hp
	game.towers[0].cooldown = 100.0
	for i in 12:
		main._process(0.05)
	assert_eq((main.get_node("Shots") as ShotsView).visible_shots(), 0)


func test_a_beam_is_drawn_while_the_tower_is_locked() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("prismSpire", 1, false, game)
	TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	assert_eq((main.get_node("Shots") as ShotsView).visible_beams(), 1)


func test_nothing_is_drawn_while_paused_even_as_frames_pass() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	var shots := main.get_node("Shots") as ShotsView
	var shown := shots.visible_shots()
	assert_gt(shown, 0)
	(main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[0].pressed.emit()
	for i in 12:
		main._process(0.05)
	assert_eq(shots.visible_shots(), shown, "the frame is frozen")
