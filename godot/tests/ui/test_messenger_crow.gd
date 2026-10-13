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
