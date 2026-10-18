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


func _first_shot_kind(type: String) -> ShotsView.Kind:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene(type, 1, false, game)
	TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	var shots := main.get_node("Shots") as ShotsView
	assert_gt(shots.visible_shots(), 0, type)
	return shots.shot_kind(0)


func test_the_mortar_lobs_a_pellet() -> void:
	assert_eq(await _first_shot_kind("thimbleMortar"), ShotsView.Kind.PELLET)


func test_the_spool_guard_throws_a_dart() -> void:
	assert_eq(await _first_shot_kind("spoolGuard"), ShotsView.Kind.DART)


func test_at_3x_a_shot_ages_in_game_time() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	var foe := TowerFireKit.foe(game, scene.near, "cardboardGolem")
	main._process(0.05)
	foe.hp = foe.max_hp
	game.towers[0].cooldown = 100.0
	(main.get_node("Hud/SpeedBar") as SpeedBar).speed_chosen.emit(3)
	# a dart lives at most 7 frames of game time: 0.2 s of real time at 3x
	for i in 4:
		main._process(0.05)
	assert_eq((main.get_node("Shots") as ShotsView).visible_shots(), 0)


func test_a_foes_bar_shows_its_hit_when_the_dart_lands() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	var foe := TowerFireKit.foe(game, scene.near, "cardboardGolem")
	var foes := main.get_node("Foes") as FoesView
	main._process(0.05)
	game.towers[0].cooldown = 100.0
	assert_lt(foe.hp, foe.max_hp, "the sim has hit it")
	assert_eq(foes.bar_count(), 0, "the dart is still flying, so no bar yet")
	for i in 6:
		main._process(0.05)
	assert_eq(foes.bar_count(), 1, "the dart has landed")


func test_a_killed_foe_stands_until_the_dart_lands() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var scene := TowerFireKit.scene("spoolGuard", 1, false, game)
	var foe := TowerFireKit.foe(game, scene.near)
	foe.hp = 1.0
	var foes := main.get_node("Foes") as FoesView
	# a frame with no tick, so the foe has been drawn once before it is shot
	main._process(0.0)
	main._process(0.05)
	assert_true(game.foes.is_empty(), "the sim has killed it")
	assert_eq(foes.visible_count(foe.type), 1, "it still stands")
	for i in 6:
		main._process(0.05)
	assert_eq(foes.visible_count(foe.type), 0, "it fell as the dart landed")
