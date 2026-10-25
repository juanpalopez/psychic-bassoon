## The arrows pulse, and hold still under reduced motion; the minimap fits the board and takes
## a tap as a request for the camera.
extends GutTest


func test_the_pulse_swings_and_holds_still_under_reduced_motion() -> void:
	var arrows := EdgeIndicators.new()
	add_child_autofree(arrows)
	arrows.reduced_motion = false
	arrows._process(0.1)
	assert_ne(arrows.pulse(), 1.0)
	arrows.reduced_motion = true
	arrows._process(0.1)
	assert_eq(arrows.pulse(), 1.0)


func test_the_arrows_hold_still_until_the_reduce_motion_setting_exists() -> void:
	var arrows := EdgeIndicators.new()
	add_child_autofree(arrows)
	assert_true(arrows.reduced_motion)
	assert_false(arrows.is_processing())
	assert_eq(arrows.pulse(), 1.0)


func test_the_free_room_stays_clear_of_the_hud_rows() -> void:
	var arrows := EdgeIndicators.new()
	add_child_autofree(arrows)
	var room := arrows.room(Vector2(1280.0, 720.0))
	assert_eq(room.position.y, HudLayout.TOP_CLEAR)
	assert_eq(room.end.y, 720.0 - HudLayout.BOTTOM_CLEAR)


func test_a_tap_on_the_minimap_asks_for_that_spot() -> void:
	var game := Game.create(7)
	var minimap := Minimap.new()
	add_child_autofree(minimap)
	minimap.bind(game)
	assert_gte(minimap.size.x, 44.0)
	assert_gte(minimap.size.y, 44.0)
	watch_signals(minimap)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = minimap.size / 2.0
	minimap._gui_input(tap)
	assert_signal_emitted_with_parameters(minimap, "jump_requested", [Vector2.ZERO])


func test_the_minimap_redraws_at_most_once_per_refresh_interval() -> void:
	var minimap := Minimap.new()
	add_child_autofree(minimap)
	minimap.bind(Game.create(7))
	minimap.refresh(Vector2.ZERO, 0.01)
	assert_gt(minimap._since, 0.0)
	minimap.refresh(Vector2.ZERO, 1.0)
	assert_eq(minimap._since, 0.0)
