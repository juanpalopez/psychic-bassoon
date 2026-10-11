## Pointer events become taps, drags and pinches. Pure logic: no nodes.
extends GutTest

var _taps: Array[Vector2] = []
var _pans: Array[Vector2] = []
var _zooms: Array[float] = []


func _tracker() -> Gestures:
	_taps.clear()
	_pans.clear()
	_zooms.clear()
	var gestures := Gestures.new()
	gestures.tapped.connect(func(at: Vector2) -> void: _taps.append(at))
	gestures.panned.connect(func(by: Vector2) -> void: _pans.append(by))
	gestures.pinched.connect(func(factor: float, _centre: Vector2) -> void: _zooms.append(factor))
	return gestures


func _total(vectors: Array[Vector2]) -> Vector2:
	var sum := Vector2.ZERO
	for v in vectors:
		sum += v
	return sum


func test_a_press_and_release_in_place_is_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.release(0, Vector2(100, 100))
	assert_eq(_taps, [Vector2(100, 100)] as Array[Vector2])
	assert_eq(_pans.size(), 0)


func test_a_small_wobble_is_still_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.move(0, Vector2(105, 103))
	g.release(0, Vector2(105, 103))
	assert_eq(_taps.size(), 1)
	assert_eq(_pans.size(), 0)


func test_a_drag_past_the_threshold_pans_and_is_not_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.move(0, Vector2(160, 100))
	g.move(0, Vector2(200, 130))
	g.release(0, Vector2(200, 130))
	assert_eq(_taps.size(), 0)
	# every pixel of the drag is passed on, none lost at the threshold
	assert_eq(_total(_pans), Vector2(100, 30))


func test_once_dragging_stays_dragging_even_if_it_returns_to_the_start() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.move(0, Vector2(200, 100))
	g.move(0, Vector2(100, 100))
	g.release(0, Vector2(100, 100))
	assert_eq(_taps.size(), 0)


func test_two_fingers_spreading_pinch_with_a_factor_above_one() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.move(1, Vector2(300, 100))
	assert_eq(_zooms.size(), 1)
	assert_almost_eq(_zooms[0], 2.0, 1e-6)
	assert_eq(_taps.size(), 0)


func test_two_fingers_closing_pinch_with_a_factor_below_one() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(300, 100))
	g.move(1, Vector2(200, 100))
	assert_almost_eq(_zooms[0], 0.5, 1e-6)


func test_two_fingers_moving_together_pan_and_do_not_zoom() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.move(0, Vector2(100, 150))
	g.move(1, Vector2(200, 150))
	assert_almost_eq(_total(_pans).y, 50.0, 1e-6)
	assert_almost_eq(_total(_pans).x, 0.0, 1e-6)
	var product := 1.0
	for factor in _zooms:
		product *= factor
	assert_almost_eq(product, 1.0, 1e-6)


func test_lifting_one_finger_after_a_pinch_is_not_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.release(1, Vector2(200, 100))
	g.release(0, Vector2(100, 100))
	assert_eq(_taps.size(), 0)


func test_the_finger_left_after_a_pinch_keeps_panning_from_where_it_is() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.release(1, Vector2(200, 100))
	g.move(0, Vector2(130, 100))
	assert_eq(_total(_pans), Vector2(30, 0))


func test_a_new_touch_after_everything_is_lifted_can_tap_again() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.release(1, Vector2(200, 100))
	g.release(0, Vector2(100, 100))
	g.press(0, Vector2(50, 60))
	g.release(0, Vector2(50, 60))
	assert_eq(_taps, [Vector2(50, 60)] as Array[Vector2])


func test_a_move_from_a_pointer_that_never_pressed_is_ignored() -> void:
	var g := _tracker()
	g.move(0, Vector2(10, 10))
	g.release(0, Vector2(10, 10))
	assert_eq(_taps.size(), 0)
	assert_eq(_pans.size(), 0)


func test_cancel_drops_the_gesture_without_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.cancel()
	g.release(0, Vector2(100, 100))
	assert_eq(_taps.size(), 0)


func test_ended_fires_when_the_last_finger_lifts() -> void:
	var g := _tracker()
	var ended: Array[bool] = []
	g.ended.connect(func() -> void: ended.append(true))
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.release(1, Vector2(200, 100))
	assert_eq(ended.size(), 0)
	g.release(0, Vector2(100, 100))
	assert_eq(ended.size(), 1)


func test_cancel_tells_the_camera_the_fingers_are_gone() -> void:
	var g := _tracker()
	var ended: Array[bool] = []
	g.ended.connect(func() -> void: ended.append(true))
	g.press(0, Vector2(100, 100))
	g.move(0, Vector2(300, 100))
	g.cancel()
	assert_eq(ended.size(), 1)
	g.cancel()
	assert_eq(ended.size(), 1, "nothing was in progress the second time")


func test_after_a_third_finger_lifts_the_pinch_starts_from_the_new_pair() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.press(1, Vector2(200, 100))
	g.press(2, Vector2(900, 900))
	g.release(2, Vector2(900, 900))
	var before := _zooms.size()
	g.move(1, Vector2(200, 100))
	# the pair did not change, so a move in place must not jump the zoom
	assert_eq(_zooms.size(), before + 1)
	assert_almost_eq(_zooms[_zooms.size() - 1], 1.0, 1e-6)


func test_a_wobble_of_twenty_pixels_or_less_is_a_tap() -> void:
	var g := _tracker()
	g.press(0, Vector2(100, 100))
	g.move(0, Vector2(118, 100))
	g.release(0, Vector2(118, 100))
	assert_eq(_taps.size(), 1)
