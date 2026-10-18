## The HUD in the main scene: speed, pause, game over, and the layout.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")
const RULES := preload("res://content/game_rules.gd")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _ticks_after(speed_index: int, seconds: float) -> int:
	var main := await _main()
	# a fresh game and clock: the frame the scene ran while starting used real time
	main._start(main.game().seed)
	# the speed button cycles, so reach a speed by pressing it until it shows that speed
	var bar := main.get_node("Hud/SpeedBar") as SpeedBar
	for press in GameSpeed.SPEEDS.size():
		if bar.buttons()[1].text == "%dx" % speed_index:
			break
		bar.buttons()[1].pressed.emit()
		main._process(0.0)
	assert_eq(bar.buttons()[1].text, "%dx" % speed_index)
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
	assert_eq(texts.size(), 3, "the seed is not on the HUD any more")


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
	if shown == "GameOver+Menu":
		(main.get_node("Hud/MenuButton") as Button).button_pressed = true
		(main.get_node("Hud/GameOver") as GameOverPanel).show_for(1)
	elif shown == "Menu":
		(main.get_node("Hud/MenuButton") as Button).button_pressed = true
	elif shown == "Message":
		var message := main.get_node("Hud/Message") as Label
		message.text = "That is road: build on a socket"
		message.visible = true
	elif shown == "TowerPanel":
		var tower := Tower.new()
		tower.type = "thimbleMortar"
		(main.get_node("Hud/TowerPanel") as TowerPanel).show_tower(tower, 100)
	elif shown == "TowerPanel spec choice" or shown == "TowerPanel ability":
		var tower := Tower.new()
		tower.type = "spoolGuard"
		tower.level = 2
		if shown == "TowerPanel ability":
			tower.spec = "crossbowBallista"
		(main.get_node("Hud/TowerPanel") as TowerPanel).show_tower(tower, 1000)
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
		for shown in [
			"",
			"GameOver",
			"BuildMenu",
			"TowerPanel",
			"TowerPanel spec choice",
			"TowerPanel ability",
			"Message",
			"Menu",
			"GameOver+Menu"
		]:
			var rects := await _hud_rects(size.x, size.y, shown)
			var names := rects.keys()
			for i in names.size():
				var rect: Rect2 = rects[names[i]]
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
	for shown in [
		"",
		"GameOver",
		"BuildMenu",
		"TowerPanel",
		"TowerPanel spec choice",
		"TowerPanel ability",
		"Menu"
	]:
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
		elif shown == "TowerPanel":
			var tower := Tower.new()
			tower.type = "thimbleMortar"
			(main.get_node("Hud/TowerPanel") as TowerPanel).show_tower(tower, 100)
		elif shown == "TowerPanel spec choice" or shown == "TowerPanel ability":
			var tower := Tower.new()
			tower.type = "spoolGuard"
			tower.level = 2
			if shown == "TowerPanel ability":
				tower.spec = "crossbowBallista"
			(main.get_node("Hud/TowerPanel") as TowerPanel).show_tower(tower, 1000)
		elif shown == "Menu":
			(main.get_node("Hud/MenuButton") as Button).button_pressed = true
		await get_tree().process_frame
		var checked := 0
		for node in main.get_node("Hud").find_children("*", "Button", true, false):
			var button := node as Button
			if button.is_visible_in_tree():
				checked += 1
				assert_gte(button.get_global_rect().size.y * scale, 44.0, button.text)
				assert_gte(button.get_global_rect().size.x * scale, 44.0, button.text)
		# Menu, Pause, speed and Start wave; a panel or the open Menu adds its own buttons
		var expected := {
			"": 4,
			"GameOver": 5,
			"BuildMenu": 9,
			"TowerPanel": 6,
			"TowerPanel spec choice": 3,
			"TowerPanel ability": 3,
			"Menu": 6
		}
		assert_gte(checked, int(expected[shown]), shown)


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


func test_the_tower_panel_is_a_low_strip_not_a_block_over_the_map() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1558, 720)]:
		var rects := await _hud_rects(size.x, size.y, "TowerPanel")
		var rect: Rect2 = rects["TowerPanel"]
		assert_lte(rect.size.y, 140.0, "TowerPanel is %s tall at %s" % [rect.size.y, size])
		assert_gte(rect.end.y, float(size.y) - 40.0, "TowerPanel sits along the bottom")


## Tapping each socket opens the build menu beside it, clear of the corner controls, on 40
## maps at the base size and a few on a phone.
func test_the_build_menu_opens_next_to_the_socket_and_off_the_corner_controls() -> void:
	var cases := []
	for map_seed in range(1, 41):
		cases.append([Vector2i(1280, 720), map_seed])
	for map_seed in [1, 2, 3, 5, 8]:
		cases.append([Vector2i(1558, 720), map_seed])
	for case in cases:
		var size: Vector2i = case[0]
		var port := SubViewport.new()
		port.size = size
		add_child_autofree(port)
		var main := MAIN_SCENE.instantiate()
		port.add_child(main)
		main.set_process(false)
		await get_tree().process_frame
		main._start(case[1])
		var hud := main.get_node("Hud")
		var menu := hud.get_node("BuildMenu") as BuildMenu
		var menu_button := hud.get_node("MenuButton") as Button
		for anchor in main.game().map.sockets:
			# the Menu's dropdown is open when the player taps the board
			menu_button.button_pressed = true
			main.select_cell(anchor)
			await get_tree().process_frame
			assert_true(menu.visible)
			assert_false((hud.get_node("NextSeed") as Control).visible, "the dropdown closed")
			var rect := menu.get_global_rect()
			assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(rect), "on screen")
			for other in ["TopBar", "SpeedBar", "MenuButton", "LaunchWave", "AutoWave"]:
				var other_rect := (hud.get_node(other) as Control).get_global_rect()
				assert_false(
					rect.intersects(other_rect),
					"menu for %s over %s on seed %d at %s" % [anchor, other, case[1], size]
				)
			var socket: Rect2 = main._socket_on_screen(anchor)
			assert_false(
				rect.intersects(socket),
				"the menu covers the socket %s on seed %d at %s" % [anchor, case[1], size]
			)
			var gap := maxf(rect.position.y - socket.end.y, socket.position.y - rect.end.y)
			# a socket under the top row has its menu just below that row
			var most := maxf(2.0 * BuildMenu.SOCKET_GAP, BuildMenu.TOP_RESERVE - socket.end.y)
			assert_lte(gap, most + 1.0, "next to %s" % anchor)


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


func test_a_speed_press_while_paused_resumes_at_that_speed() -> void:
	var main := await _main()
	var bar := main.get_node("Hud/SpeedBar") as SpeedBar
	bar.buttons()[0].pressed.emit()
	assert_eq(main._speed.ticks_speed(), 0)
	bar.buttons()[1].pressed.emit()
	assert_eq(main._speed.ticks_speed(), 2, "choosing a speed resumes")


func test_auto_start_counts_down_on_the_button_and_then_starts_the_wave() -> void:
	var main := await _main()
	main._start(main.game().seed)
	var auto := main.get_node("Hud/AutoWave") as Button
	var launch := main.get_node("Hud/LaunchWave") as Button
	auto.button_pressed = true
	main._process(0.05)
	assert_string_contains(launch.text, "Start wave 1", "wave 1 waits for the player")
	# as if wave 1 had been played and cleared
	main.game().wave = 1
	main._process(0.05)
	assert_string_contains(launch.text, "Wave 2 in 3")
	for frame in 70:
		main._process(0.05)
	assert_eq(main.game().wave, 2, "the countdown started wave 2")


func test_auto_start_holds_while_paused() -> void:
	var main := await _main()
	main._start(main.game().seed)
	main.game().wave = 1
	(main.get_node("Hud/AutoWave") as Button).button_pressed = true
	(main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[0].pressed.emit()
	for frame in 100:
		main._process(0.05)
	var launch := main.get_node("Hud/LaunchWave") as Button
	assert_string_contains(launch.text, "Wave 2 in 3", "the countdown held")
	(main.get_node("Hud/SpeedBar") as SpeedBar).buttons()[0].pressed.emit()
	for frame in 70:
		main._process(0.05)
	assert_eq(main.game().wave, 2, "unpaused, the countdown runs out")


func test_a_tap_during_the_countdown_launches_the_wave_once() -> void:
	var main := await _main()
	main._start(main.game().seed)
	main.game().wave = 1
	(main.get_node("Hud/AutoWave") as Button).button_pressed = true
	# one frame before the countdown runs out: the tap and the countdown must not both launch
	for frame in int(RULES.AUTO_WAVE_SECONDS / 0.05) - 1:
		main._process(0.05)
	(main.get_node("Hud/LaunchWave") as Button).pressed.emit()
	for frame in 80:
		main._process(0.05)
	assert_eq(main.game().wave, 2, "one wave, not two")
	assert_false((main.get_node("Hud/Message") as Label).visible, "no refused second launch")


func test_a_long_frame_counts_no_more_game_time_than_the_clock_runs() -> void:
	var main := await _main()
	main._start(main.game().seed)
	main.game().wave = 1
	(main.get_node("Hud/AutoWave") as Button).button_pressed = true
	main._process(0.05)
	main._process(5.0)
	main._process(0.05)
	assert_eq(main.game().wave, 1, "a 5 s hitch is not 5 s of countdown")
	assert_string_contains((main.get_node("Hud/LaunchWave") as Button).text, "Wave 2 in 3")
