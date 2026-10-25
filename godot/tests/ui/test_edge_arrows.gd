## An arrow for something off screen sits on the free part of the screen's edge, pointing at it.
extends GutTest

const CANVAS := Vector2(1000.0, 600.0)
const ROOM := Rect2(50.0, 100.0, 900.0, 400.0)


func test_a_target_on_screen_gets_no_arrow() -> void:
	assert_null(EdgeArrows.spot(Vector2(300.0, 200.0), false, CANVAS, ROOM))


func test_a_target_to_the_right_gets_an_arrow_on_the_right_edge_pointing_right() -> void:
	var spot := EdgeArrows.spot(Vector2(1500.0, 300.0), false, CANVAS, ROOM)
	assert_almost_eq(spot.position.x, ROOM.end.x, 0.001)
	assert_almost_eq(spot.position.y, 300.0, 0.001)
	assert_almost_eq(spot.angle, 0.0, 0.001)


func test_a_target_above_stops_at_the_top_of_the_free_room_not_the_screen() -> void:
	var spot := EdgeArrows.spot(Vector2(500.0, -400.0), false, CANVAS, ROOM)
	assert_almost_eq(spot.position.y, ROOM.position.y, 0.001)
	assert_almost_eq(spot.position.x, 500.0, 0.001)
	assert_almost_eq(spot.angle, -PI / 2.0, 0.001)


func test_a_diagonal_target_lies_on_the_line_to_it_inside_the_room() -> void:
	var spot := EdgeArrows.spot(Vector2(2000.0, 1500.0), false, CANVAS, ROOM)
	assert_true(ROOM.grow(0.001).has_point(spot.position))
	var way := Vector2(1500.0, 1200.0).normalized()
	assert_almost_eq((spot.position - CANVAS / 2.0).normalized().dot(way), 1.0, 0.0001)


func test_a_target_behind_the_camera_points_the_other_way_even_when_it_draws_on_screen() -> void:
	var spot := EdgeArrows.spot(Vector2(700.0, 300.0), true, CANVAS, ROOM)
	assert_almost_eq(spot.position.x, ROOM.position.x, 0.001)
	assert_almost_eq(absf(spot.angle), PI, 0.001)


func test_a_target_in_the_exact_middle_still_gets_a_defined_arrow_when_behind() -> void:
	var spot := EdgeArrows.spot(CANVAS / 2.0, true, CANVAS, ROOM)
	assert_true(ROOM.grow(0.001).has_point(spot.position))
