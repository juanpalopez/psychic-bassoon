## The intro's speech bubble: words, an optional Next and an always-there Skip.
extends GutTest


func _view(flow: IntroFlow) -> IntroView:
	var view := IntroView.new()
	add_child_autofree(view)
	view.bind(flow)
	return view


func test_it_shows_the_flows_words_and_next_on_the_goal_step() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	view.refresh()
	assert_true(view.visible)
	assert_eq(view.bubble_text(), flow.text())
	assert_true(view.next_button().visible)


func test_next_is_hidden_while_the_player_has_something_to_do() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	flow.notify(IntroFlow.Event.NEXT)
	view.refresh()
	assert_false(view.next_button().visible)
	assert_true(view.skip_button().visible, "skip is always there")
	assert_eq(view.bubble_text(), flow.text())


func test_the_buttons_drive_the_flow() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	view.next_button().pressed.emit()
	assert_eq(flow.step(), IntroFlow.Step.PICK_SOCKET)
	view.skip_button().pressed.emit()
	assert_false(flow.is_active())
	view.refresh()
	assert_false(view.visible)


func test_it_does_not_block_taps_on_the_map() -> void:
	var flow := IntroFlow.new()
	flow.start()
	assert_eq(_view(flow).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_the_buttons_are_big_enough_for_a_thumb() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	for button in [view.next_button(), view.skip_button()]:
		assert_gte(button.custom_minimum_size.y * 0.54, 44.0)
		assert_gte(button.custom_minimum_size.x * 0.54, 44.0)


func test_a_step_that_names_a_control_outlines_it_when_it_is_on_screen() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	var target := Control.new()
	target.size = Vector2(120.0, 96.0)
	add_child_autofree(target)
	view.target_resolver = func(_name: String) -> Control: return target
	for event in [
		IntroFlow.Event.NEXT, IntroFlow.Event.SOCKET_SELECTED, IntroFlow.Event.TOWER_BUILT
	]:
		flow.notify(event)
	view.refresh()
	assert_true(view.highlight_visible())
	target.visible = false
	view.refresh()
	assert_false(view.highlight_visible())


func test_the_bubble_is_narrower_on_the_map_steps() -> void:
	var flow := IntroFlow.new()
	flow.start()
	var view := _view(flow)
	view.refresh()
	var wide: float = view.get_child(1).custom_minimum_size.x
	flow.notify(IntroFlow.Event.NEXT)
	view.refresh()
	assert_lt(view.get_child(1).custom_minimum_size.x, wide)
