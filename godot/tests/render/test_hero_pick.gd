## What a tap means with a hero on the board (#335).
extends GutTest

const TAP_PIXELS := 100.0


func test_a_tap_within_half_the_tap_target_hits_the_hero() -> void:
	var hero := Vector2(400.0, 300.0)
	assert_true(HeroPick.hits_hero(Vector2(400.0, 300.0), hero, TAP_PIXELS))
	assert_true(HeroPick.hits_hero(Vector2(449.0, 300.0), hero, TAP_PIXELS))
	assert_false(HeroPick.hits_hero(Vector2(451.0, 300.0), hero, TAP_PIXELS))


func test_a_tap_on_the_hero_selects_it_and_a_second_lets_it_go() -> void:
	assert_eq(HeroPick.resolve(true, false, false), HeroPick.Action.SELECT)
	assert_eq(HeroPick.resolve(true, true, true), HeroPick.Action.DESELECT)


func test_a_selected_hero_walks_to_a_walkable_tap_and_lets_go_on_any_other() -> void:
	assert_eq(HeroPick.resolve(false, true, true), HeroPick.Action.MOVE)
	assert_eq(HeroPick.resolve(false, true, false), HeroPick.Action.DESELECT)


func test_without_a_selected_hero_a_tap_is_not_the_heros() -> void:
	assert_eq(HeroPick.resolve(false, false, true), HeroPick.Action.NONE)
	assert_eq(HeroPick.resolve(false, false, false), HeroPick.Action.NONE)
