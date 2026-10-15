## The fps overlay: hidden until shown, refreshed on a timer, never taking a tap.
extends GutTest


func _overlay() -> FpsOverlay:
	var overlay := FpsOverlay.new()
	add_child_autofree(overlay)
	return overlay


func test_it_is_hidden_until_enabled() -> void:
	var overlay := _overlay()
	assert_false(overlay.visible)
	overlay.enable(func() -> int: return 12)
	assert_true(overlay.visible)


func test_it_shows_the_foe_count_it_is_given() -> void:
	var overlay := _overlay()
	overlay.enable(func() -> int: return 80)
	overlay.refresh()
	assert_string_contains(overlay.text, "80 foes")


func test_it_refreshes_only_when_its_interval_has_passed() -> void:
	var overlay := _overlay()
	var counter := [0]
	overlay.enable(
		func() -> int:
			counter[0] += 1
			return counter[0]
	)
	overlay.advance(0.0)
	var first: int = counter[0]
	overlay.advance(FpsOverlay.INTERVAL * 0.4)
	assert_eq(counter[0], first, "not yet")
	overlay.advance(FpsOverlay.INTERVAL * 0.7)
	assert_eq(counter[0], first + 1, "now")


func test_it_never_takes_a_tap() -> void:
	assert_eq(_overlay().mouse_filter, Control.MOUSE_FILTER_IGNORE)
