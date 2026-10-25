## The arrows pulse, and hold still under reduced motion.
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
