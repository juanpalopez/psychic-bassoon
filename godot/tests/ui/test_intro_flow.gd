## The intro wave as a sequence of steps, each moved on by something the player does.
extends GutTest

const GUIDE := preload("res://content/guide.gd")


func _flow() -> IntroFlow:
	var flow := IntroFlow.new()
	flow.start()
	return flow


func test_it_starts_on_the_goal_step() -> void:
	var flow := _flow()
	assert_true(flow.is_active())
	assert_eq(flow.step(), IntroFlow.Step.GOAL)
	assert_eq(flow.text(), GUIDE.INTRO.goal.text)


func test_each_step_moves_on_by_its_own_event() -> void:
	var flow := _flow()
	flow.notify(IntroFlow.Event.NEXT)
	assert_eq(flow.step(), IntroFlow.Step.PICK_SOCKET)
	assert_true(flow.highlights_sockets())
	flow.notify(IntroFlow.Event.SOCKET_SELECTED)
	assert_eq(flow.step(), IntroFlow.Step.PICK_TOWER)
	assert_false(flow.highlights_sockets())
	flow.notify(IntroFlow.Event.TOWER_BUILT)
	assert_eq(flow.step(), IntroFlow.Step.START_WAVE)
	assert_eq(flow.target(), "LaunchWave")
	flow.notify(IntroFlow.Event.WAVE_LAUNCHED)
	assert_eq(flow.step(), IntroFlow.Step.WATCH)
	flow.notify(IntroFlow.Event.WAVE_CLEARED)
	assert_eq(flow.step(), IntroFlow.Step.DONE)


func test_an_event_for_another_step_does_nothing() -> void:
	var flow := _flow()
	flow.notify(IntroFlow.Event.SOCKET_SELECTED)
	assert_eq(flow.step(), IntroFlow.Step.GOAL, "the goal waits for Next")
	flow.notify(IntroFlow.Event.NEXT)
	flow.notify(IntroFlow.Event.WAVE_CLEARED)
	assert_eq(flow.step(), IntroFlow.Step.PICK_SOCKET)


func test_a_tower_built_early_skips_the_picking_steps() -> void:
	var flow := _flow()
	flow.notify(IntroFlow.Event.NEXT)
	flow.notify(IntroFlow.Event.TOWER_BUILT)
	assert_eq(flow.step(), IntroFlow.Step.START_WAVE)


func test_a_wave_launched_early_goes_to_watching() -> void:
	var flow := _flow()
	flow.notify(IntroFlow.Event.NEXT)
	flow.notify(IntroFlow.Event.WAVE_LAUNCHED)
	assert_eq(flow.step(), IntroFlow.Step.WATCH)


func test_the_last_step_is_closed_with_done_and_finishes_once() -> void:
	var flow := _flow()
	watch_signals(flow)
	for event in [
		IntroFlow.Event.NEXT,
		IntroFlow.Event.SOCKET_SELECTED,
		IntroFlow.Event.TOWER_BUILT,
		IntroFlow.Event.WAVE_LAUNCHED,
		IntroFlow.Event.WAVE_CLEARED
	]:
		flow.notify(event)
	assert_true(flow.is_active(), "the closing words wait for Done")
	flow.notify(IntroFlow.Event.NEXT)
	assert_false(flow.is_active())
	flow.notify(IntroFlow.Event.NEXT)
	assert_signal_emit_count(flow, "finished", 1)
	assert_signal_emitted_with_parameters(flow, "finished", [false])


func test_skip_finishes_from_every_step() -> void:
	for steps in range(0, 5):
		var flow := _flow()
		watch_signals(flow)
		var events := [
			IntroFlow.Event.NEXT,
			IntroFlow.Event.SOCKET_SELECTED,
			IntroFlow.Event.TOWER_BUILT,
			IntroFlow.Event.WAVE_LAUNCHED
		]
		for i in steps:
			flow.notify(events[i])
		flow.skip()
		assert_false(flow.is_active(), "skipped after %d events" % steps)
		assert_signal_emitted_with_parameters(flow, "finished", [true])


func test_the_next_button_is_offered_only_where_the_player_has_nothing_to_do() -> void:
	var flow := _flow()
	assert_true(flow.offers_next())
	flow.notify(IntroFlow.Event.NEXT)
	assert_false(flow.offers_next(), "on the map the player taps a socket")
	flow.notify(IntroFlow.Event.SOCKET_SELECTED)
	assert_false(flow.offers_next())


func test_every_step_has_words_and_an_idle_flow_has_none() -> void:
	for key in ["goal", "pick_socket", "pick_tower", "start_wave", "watch", "done"]:
		assert_gt(String(GUIDE.INTRO[key].text).length(), 30, key)
	assert_eq(IntroFlow.new().text(), "")


func test_the_bubble_is_small_while_the_player_acts_on_the_map() -> void:
	var flow := _flow()
	assert_false(flow.compact(), "the goal can take the room it needs")
	flow.notify(IntroFlow.Event.NEXT)
	assert_true(flow.compact())
	flow.notify(IntroFlow.Event.SOCKET_SELECTED)
	assert_true(flow.compact())
	assert_false(IntroFlow.new().compact())
