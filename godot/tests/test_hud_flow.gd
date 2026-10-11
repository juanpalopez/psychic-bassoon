## The HUD in the main scene: speed, pause, game over, and the layout.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _ticks_after(speed_index: int, seconds: float) -> int:
	var main := await _main()
	# a fresh game and clock: the frame the scene ran while starting used real time
	main._start(main.game().seed)
	((main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[speed_index]).pressed.emit()
	main._process(seconds)
	return main.game().tick_count


func test_a_faster_speed_runs_proportionally_more_ticks() -> void:
	var normal := await _ticks_after(1, 0.1)
	var triple := await _ticks_after(3, 0.1)
	assert_gt(normal, 0)
	assert_eq(triple, normal * 3)


func test_pause_runs_no_ticks_and_resuming_runs_them_again() -> void:
	var main := await _main()
	var bar := main.get_node("Hud/SpeedBar") as SpeedBar
	bar.buttons()[0].pressed.emit()
	var before: int = main.game().tick_count
	main._process(0.1)
	assert_eq(main.game().tick_count, before)
	bar.buttons()[0].pressed.emit()
	main._process(0.1)
	assert_gt(main.game().tick_count, before)


func test_the_top_bar_shows_the_game() -> void:
	var main := await _main()
	main._process(0.05)
	var game: GameState = main.game()
	var texts: Array[String] = (main.get_node("Hud/TopBar") as TopBar).texts()
	assert_eq(texts[0], "Buttons %d" % game.buttons)
	assert_eq(texts[3], "Seed %d" % game.seed)


func test_the_game_over_overlay_shows_only_when_the_game_is_over() -> void:
	var main := await _main()
	var overlay := main.get_node("Hud/GameOver") as GameOverPanel
	main._process(0.05)
	assert_false(overlay.visible)
	main.game().over = true
	main._process(0.05)
	assert_true(overlay.visible)


func test_play_again_starts_a_new_game_on_the_same_seed() -> void:
	var main := await _main()
	var first: GameState = main.game()
	var map_seed := first.seed
	first.over = true
	first.kingdom_health = 0
	main._process(0.05)
	(main.get_node("Hud/GameOver") as GameOverPanel).play_again_button().pressed.emit()
	var second: GameState = main.game()
	assert_ne(second, first)
	assert_eq(second.seed, map_seed)
	assert_false(second.over)
	assert_false((main.get_node("Hud/GameOver") as GameOverPanel).visible)


func _hud_rects(width: int, height: int) -> Dictionary:
	var port := SubViewport.new()
	port.size = Vector2i(width, height)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var rects := {}
	for child in main.get_node("Hud").get_children():
		if child is Control and (child as Control).visible:
			rects[child.name] = (child as Control).get_global_rect()
	return rects


func test_the_always_visible_controls_do_not_overlap_on_wide_and_narrow_phones() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		var rects := await _hud_rects(size.x, size.y)
		var names := rects.keys()
		for i in names.size():
			for j in range(i + 1, names.size()):
				assert_false(
					(rects[names[i]] as Rect2).intersects(rects[names[j]]),
					"%s overlaps %s at %s" % [names[i], names[j], size]
				)
			var rect: Rect2 = rects[names[i]]
			assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "%s fits" % names[i])


func test_every_hud_button_is_at_least_44_px_on_a_phone() -> void:
	# a 1280x720 canvas on a 844x390 phone is scaled by 390/720
	var main := await _main()
	var scale := 390.0 / 720.0
	var buttons: Array[Node] = main.get_node("Hud").find_children("*", "Button", true, false)
	assert_gt(buttons.size(), 6)
	for node in buttons:
		var button := node as Button
		assert_gte(button.custom_minimum_size.y * scale, 44.0, button.text)


func test_an_order_while_paused_says_it_waits() -> void:
	var main := await _main()
	(main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[0].pressed.emit()
	main.select_cell(main.game().map.sockets[0])
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	assert_string_contains((main.get_node("Hud/Message") as Label).text, "Paused")
