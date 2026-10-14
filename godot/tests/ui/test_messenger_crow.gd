## The Messenger Crow flies in with a scroll, holds it, flies out, and delivers one
## message after another.
extends GutTest

const ALERTS := preload("res://content/alerts.gd")


func _crow() -> MessengerCrow:
	var crow := MessengerCrow.new()
	add_child_autofree(crow)
	return crow


func test_an_idle_crow_is_hidden_and_the_viewport_is_off() -> void:
	var crow := _crow()
	assert_eq(crow.phase(), MessengerCrow.Phase.IDLE)
	assert_false(crow.visible)
	assert_false(crow.is_rendering())


func test_delivering_a_message_starts_the_flight_and_shows_it() -> void:
	var crow := _crow()
	crow.deliver("Wave 1 is coming")
	assert_eq(crow.phase(), MessengerCrow.Phase.FLYING_IN)
	assert_eq(crow.text(), "Wave 1 is coming")
	assert_true(crow.visible)
	assert_true(crow.is_rendering())


func test_the_flight_goes_in_then_holds_then_goes_out_then_rests() -> void:
	var crow := _crow()
	crow.deliver("hello")
	crow.advance(ALERTS.CROW_FLY_SECONDS + 0.01)
	assert_eq(crow.phase(), MessengerCrow.Phase.HOLDING)
	crow.advance(ALERTS.CROW_HOLD_SECONDS + 0.01)
	assert_eq(crow.phase(), MessengerCrow.Phase.FLYING_OUT)
	crow.advance(ALERTS.CROW_FLY_SECONDS + 0.01)
	assert_eq(crow.phase(), MessengerCrow.Phase.IDLE)
	assert_false(crow.visible)
	assert_false(crow.is_rendering())


func test_the_crow_crosses_the_screen_from_the_left_to_the_right() -> void:
	var crow := _crow()
	crow.deliver("x")
	assert_almost_eq(crow.position_fraction(), 0.0, 1e-9)
	crow.advance(ALERTS.CROW_FLY_SECONDS)
	assert_almost_eq(crow.position_fraction(), 0.5, 1e-9, "the middle while it holds")
	crow.advance(ALERTS.CROW_HOLD_SECONDS + ALERTS.CROW_FLY_SECONDS)
	assert_almost_eq(crow.position_fraction(), 1.0, 1e-9)


func test_messages_wait_their_turn_and_arrive_in_order() -> void:
	var crow := _crow()
	crow.deliver("first")
	crow.deliver("second")
	assert_eq(crow.pending(), 1)
	var whole := ALERTS.CROW_FLY_SECONDS * 2.0 + ALERTS.CROW_HOLD_SECONDS
	crow.advance(whole + 0.01)
	assert_eq(crow.text(), "second")
	assert_eq(crow.phase(), MessengerCrow.Phase.FLYING_IN)
	assert_eq(crow.pending(), 0)


func test_a_long_queue_keeps_only_the_newest_messages() -> void:
	var crow := _crow()
	crow.deliver("flying")
	for i in ALERTS.CROW_MAX_QUEUE + 3:
		crow.deliver("m%d" % i)
	assert_eq(crow.pending(), ALERTS.CROW_MAX_QUEUE)
	var whole := ALERTS.CROW_FLY_SECONDS * 2.0 + ALERTS.CROW_HOLD_SECONDS
	crow.advance(whole + 0.01)
	assert_eq(crow.text(), "m3", "the oldest waiting ones were dropped")


func test_an_empty_message_is_ignored() -> void:
	var crow := _crow()
	crow.deliver("")
	assert_eq(crow.phase(), MessengerCrow.Phase.IDLE)


func test_the_crow_draws_the_owners_model() -> void:
	var crow := _crow()
	assert_true(crow.has_model())


func test_main_feeds_the_crow_from_a_launched_wave() -> void:
	var main: Node = preload("res://main.tscn").instantiate()
	add_child_autofree(main)
	Game.submit(main._game, Command.launch_wave())
	Game.tick(main._game)
	main._after_tick(main._game)
	assert_eq(main._crow.text(), "Wave 1 is coming")
	assert_true(main._crow.visible)


func test_a_huge_step_plays_every_queued_message_through_to_rest() -> void:
	var crow := _crow()
	for i in ALERTS.CROW_MAX_QUEUE + 1:
		crow.deliver("m%d" % i)
	crow.advance(1000.0)
	assert_eq(crow.phase(), MessengerCrow.Phase.IDLE)
	assert_eq(crow.pending(), 0)


func test_a_message_delivered_while_flying_out_is_shown_next() -> void:
	var crow := _crow()
	crow.deliver("first")
	crow.advance(ALERTS.CROW_FLY_SECONDS + ALERTS.CROW_HOLD_SECONDS + 0.1)
	assert_eq(crow.phase(), MessengerCrow.Phase.FLYING_OUT)
	crow.deliver("late")
	crow.advance(ALERTS.CROW_FLY_SECONDS)
	assert_eq(crow.text(), "late")
	assert_eq(crow.phase(), MessengerCrow.Phase.FLYING_IN)


func test_clearing_sends_the_crow_home_and_drops_the_queue() -> void:
	var crow := _crow()
	crow.deliver("a")
	crow.deliver("b")
	crow.clear()
	assert_eq(crow.phase(), MessengerCrow.Phase.IDLE)
	assert_eq(crow.pending(), 0)
	assert_false(crow.visible)


func test_the_crow_only_runs_every_frame_while_it_is_out() -> void:
	var crow := _crow()
	assert_false(crow.is_processing())
	crow.deliver("a")
	assert_true(crow.is_processing())
	crow.advance(1000.0)
	assert_false(crow.is_processing())


func test_the_crow_flies_below_the_top_bar_and_the_left_hand_buttons() -> void:
	assert_gt(MessengerCrow.TOP_MARGIN, 280.0)


func test_reduced_motion_stops_the_bob() -> void:
	var crow := _crow()
	crow.reduced_motion = true
	crow.deliver("a")
	crow.advance(0.3)
	var first: float = crow.get_child(0).position.y
	crow.advance(0.2)
	assert_eq(crow.get_child(0).position.y, first)


func test_the_crow_holds_in_the_middle_of_the_screen_whatever_the_controls_size() -> void:
	# a Control under a CanvasLayer can report a size of 0 (as it does here), which once put
	# the crow off the left edge
	var crow := _crow()
	crow.deliver("x")
	crow.advance(ALERTS.CROW_FLY_SECONDS)
	var middle := crow.get_viewport_rect().size.x / 2.0
	var view_middle: float = crow.get_child(0).position.x + float(MessengerCrow.VIEW_SIZE) / 2.0
	assert_almost_eq(view_middle, middle, 1.0)
