## The tour: a card of steps with Back, Next and Skip over a dimmed screen.
extends GutTest

const GUIDE := preload("res://content/guide.gd")


func _tour() -> Tour:
	var tour := Tour.new()
	add_child_autofree(tour)
	return tour


func test_it_is_hidden_until_started() -> void:
	var tour := _tour()
	assert_false(tour.visible)
	assert_false(tour.is_open())


func test_starting_shows_the_first_step() -> void:
	var tour := _tour()
	tour.start()
	assert_true(tour.is_open())
	assert_eq(tour.step_index(), 0)
	assert_eq(tour.title_text(), GUIDE.TOUR_STEPS[0].title)
	assert_eq(tour.body_text(), GUIDE.TOUR_STEPS[0].text)
	assert_string_contains(tour.counter_text(), "1")


func test_next_and_back_move_through_the_steps() -> void:
	var tour := _tour()
	tour.start()
	tour.next()
	assert_eq(tour.step_index(), 1)
	assert_eq(tour.title_text(), GUIDE.TOUR_STEPS[1].title)
	tour.back()
	assert_eq(tour.step_index(), 0)
	tour.back()
	assert_eq(tour.step_index(), 0, "back stops at the first step")


func test_the_last_step_offers_done_and_finishes_the_tour() -> void:
	var tour := _tour()
	watch_signals(tour)
	tour.start()
	for i in GUIDE.TOUR_STEPS.size() - 1:
		tour.next()
	assert_eq(tour.step_index(), GUIDE.TOUR_STEPS.size() - 1)
	assert_eq(tour.next_button().text, "Done")
	tour.next()
	assert_signal_emitted(tour, "finished")
	assert_false(tour.is_open())


func test_skip_finishes_at_once() -> void:
	var tour := _tour()
	watch_signals(tour)
	tour.start()
	tour.skip_button().pressed.emit()
	assert_signal_emitted(tour, "finished")
	assert_false(tour.is_open())


func test_a_step_with_a_target_outlines_it() -> void:
	var tour := _tour()
	var target := Control.new()
	target.name = "Target"
	target.position = Vector2(100.0, 200.0)
	target.size = Vector2(120.0, 96.0)
	add_child_autofree(target)
	tour.target_resolver = func(_path: String) -> Control: return target
	tour.start()
	tour.go_to(_first_step_with_target())
	assert_true(tour.highlight_visible())
	assert_eq(tour.highlight_rect(), Rect2(target.global_position, target.size).grow(8.0))
	tour.go_to(0)
	assert_false(tour.highlight_visible())


func test_the_buttons_are_big_enough_for_a_thumb() -> void:
	var tour := _tour()
	for button in [tour.next_button(), tour.back_button(), tour.skip_button()]:
		assert_gte(button.custom_minimum_size.y * 0.54, 44.0)
		assert_gte(button.custom_minimum_size.x * 0.54, 44.0)


func _first_step_with_target() -> int:
	for i in GUIDE.TOUR_STEPS.size():
		if GUIDE.TOUR_STEPS[i].target != "":
			return i
	return -1


func test_it_covers_the_whole_viewport_when_started() -> void:
	var tour := _tour()
	tour.start()
	assert_eq(tour.size, tour.get_viewport_rect().size)
	assert_eq(tour.position, Vector2.ZERO)
