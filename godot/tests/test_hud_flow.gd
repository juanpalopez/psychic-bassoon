## The HUD in the main scene: speed, pause, game over, and the layout.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")
## The web shell's Full screen button, in canvas pixels at its largest: about
## 104x52 CSS px, drawn on an 844x390 phone where a canvas pixel is 0.54 px.
const WEB_BUTTON := Vector2(200.0, 100.0)


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
	first.heartstone_health = 0
	main._process(0.05)
	(main.get_node("Hud/GameOver") as GameOverPanel).play_again_button().pressed.emit()
	var second: GameState = main.game()
	assert_ne(second, first)
	assert_eq(second.seed, map_seed)
	assert_false(second.over)
	assert_false((main.get_node("Hud/GameOver") as GameOverPanel).visible)


## Lays the HUD out in a viewport of the canvas size. `shown` is the one panel
## that opens on demand (or "") to be forced visible with the always-visible
## controls; returns each visible control's global rect by node name.
func _hud_rects(width: int, height: int, shown: String = "") -> Dictionary:
	var port := SubViewport.new()
	port.size = Vector2i(width, height)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	# the scene closes the overlay on a frame when the game is not over
	main.set_process(false)
	await get_tree().process_frame
	if shown == "Menu":
		(main.get_node("Hud/MenuButton") as Button).button_pressed = true
	elif shown == "Message":
		var message := main.get_node("Hud/Message") as Label
		message.text = "Unknown tower and a rather long sentence to be sure it fits"
		message.visible = true
	elif shown == "TowerPanel":
		var tower := Tower.new()
		tower.type = "thimbleMortar"
		(main.get_node("Hud/TowerPanel") as TowerPanel).show_tower(tower, 100)
	elif shown != "":
		var panel := main.get_node("Hud/" + shown) as Control
		if panel is GameOverPanel:
			(panel as GameOverPanel).show_for(1)
		else:
			panel.visible = true
	await get_tree().process_frame
	var rects := {}
	for child in main.get_node("Hud").get_children():
		if child is Control and (child as Control).visible:
			rects[child.name] = (child as Control).get_global_rect()
	return rects


func test_no_hud_controls_overlap_on_wide_and_narrow_phones() -> void:
	# 1558x720 is an 844x390 phone: expand stretch widens the 1280x720 canvas
	for size in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		for shown in ["", "GameOver", "BuildMenu", "TowerPanel", "Message", "Menu"]:
			var rects := await _hud_rects(size.x, size.y, shown)
			var names := rects.keys()
			# the web page's Full screen button floats over the top-right corner
			var web_button := Rect2(float(size.x) - WEB_BUTTON.x, 0.0, WEB_BUTTON.x, WEB_BUTTON.y)
			for i in names.size():
				var rect: Rect2 = rects[names[i]]
				assert_false(
					rect.intersects(web_button), "%s under the Full screen button" % names[i]
				)
				assert_true(
					Rect2(Vector2.ZERO, Vector2(size)).encloses(rect),
					"%s fits at %s" % [names[i], size]
				)
				for j in range(i + 1, names.size()):
					assert_false(
						rect.intersects(rects[names[j]]),
						"%s overlaps %s at %s with %s" % [names[i], names[j], size, shown]
					)


func test_every_visible_hud_button_is_at_least_44_px_on_a_844x390_phone() -> void:
	# the 1558x720 canvas is drawn at 390/720 of its size on that phone
	var scale := 390.0 / 720.0
	for shown in ["", "GameOver", "BuildMenu"]:
		var port := SubViewport.new()
		port.size = Vector2i(1558, 720)
		add_child_autofree(port)
		var main := MAIN_SCENE.instantiate()
		port.add_child(main)
		main.set_process(false)
		await get_tree().process_frame
		if shown == "GameOver":
			(main.get_node("Hud/GameOver") as GameOverPanel).show_for(1)
		elif shown == "BuildMenu":
			(main.get_node("Hud/BuildMenu") as Control).visible = true
		await get_tree().process_frame
		var checked := 0
		for node in main.get_node("Hud").find_children("*", "Button", true, false):
			var button := node as Button
			if button.is_visible_in_tree():
				checked += 1
				assert_gte(button.get_global_rect().size.y * scale, 44.0, button.text)
				assert_gte(button.get_global_rect().size.x * scale, 44.0, button.text)
		assert_gt(checked, 5, shown)


func test_a_new_game_starts_running_at_normal_speed() -> void:
	var main := await _main()
	var bar := main.get_node("Hud/SpeedBar") as SpeedBar
	bar.buttons()[0].pressed.emit()
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	main._process(0.1)
	assert_gt(main.game().tick_count, 0, "not frozen")
	assert_eq(bar.active_labels(), ["1x"])


func test_an_order_while_paused_says_it_waits() -> void:
	var main := await _main()
	(main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[0].pressed.emit()
	main.select_cell(main.game().map.sockets[0])
	(main.get_node("Hud/BuildMenu") as BuildMenu).tower_buttons()[0].pressed.emit()
	assert_string_contains((main.get_node("Hud/Message") as Label).text, "Paused")


func test_a_won_game_shows_the_victory_overlay_and_play_again_starts_afresh() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var overlay := main.get_node("Hud/GameOver") as GameOverPanel
	game.wave = 20
	game.won = true
	main._process(0.05)
	assert_true(overlay.visible)
	assert_string_contains(overlay.title_text(), "holds")
	assert_string_contains((main.get_node("Hud/LaunchWave") as Button).text, "won")
	assert_true((main.get_node("Hud/LaunchWave") as Button).disabled)
	overlay.play_again_button().pressed.emit()
	assert_false(main.game().won)
	assert_false(overlay.visible)


func test_the_build_menu_is_a_low_strip_not_a_block_over_the_map() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		for panel in ["BuildMenu", "TowerPanel"]:
			var rects := await _hud_rects(size.x, size.y, panel)
			var rect: Rect2 = rects[panel]
			assert_lte(rect.size.y, 140.0, "%s is %s tall at %s" % [panel, rect.size.y, size])
			assert_gte(rect.end.y, float(size.y) - 40.0, "%s sits along the bottom" % panel)


func test_the_menu_button_shows_next_seed_and_sound() -> void:
	var main := await _main()
	var next_seed := main.get_node("Hud/NextSeed") as Button
	var sound := main.get_node("Hud/Sound") as Button
	assert_false(next_seed.visible)
	assert_false(sound.visible)
	(main.get_node("Hud/MenuButton") as Button).button_pressed = true
	assert_true(next_seed.visible)
	assert_true(sound.visible)
	(main.get_node("Hud/MenuButton") as Button).button_pressed = false
	assert_false(next_seed.visible)
