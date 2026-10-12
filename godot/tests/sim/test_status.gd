## The shared slow status: the strongest slow wins, a fresh one refreshes the
## timer, and a slowed foe walks that much less each tick.
extends GutTest


func _foe(type: String = "scrapGoblin") -> Foe:
	var game := Game.create(1)
	var foe := FoeSpawner.spawn(game, type, 1, 0)
	game.events = []
	return foe


func test_a_slow_sets_its_share_and_its_time() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.4, 2.0)
	assert_eq(foe.slow, 0.4)
	assert_eq(foe.slow_timer, 2.0)


func test_a_stronger_slow_replaces_a_weaker_one() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.3, 2.0)
	Status.apply_slow(foe, 0.6, 1.0)
	assert_eq(foe.slow, 0.6)
	assert_eq(foe.slow_timer, 1.0)


func test_a_weaker_slow_does_not_replace_a_stronger_active_one() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.6, 1.0)
	Status.apply_slow(foe, 0.3, 5.0)
	assert_eq(foe.slow, 0.6)
	assert_eq(foe.slow_timer, 1.0, "the weaker slow does not stretch the stronger one")


func test_an_equal_slow_refreshes_the_timer() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.5, 1.0)
	foe.slow_timer = 0.2
	Status.apply_slow(foe, 0.5, 1.0)
	assert_eq(foe.slow_timer, 1.0)


func test_a_weaker_slow_applies_once_the_stronger_has_run_out() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.6, 1.0)
	foe.slow_timer = 0.0
	Status.apply_slow(foe, 0.3, 2.0)
	assert_eq(foe.slow, 0.3)
	assert_eq(foe.slow_timer, 2.0)


func test_a_slow_that_is_not_a_share_or_has_no_time_is_ignored() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.0, 1.0)
	Status.apply_slow(foe, -0.2, 1.0)
	Status.apply_slow(foe, NAN, 1.0)
	Status.apply_slow(foe, 0.5, 0.0)
	Status.apply_slow(foe, 0.5, -1.0)
	Status.apply_slow(foe, 0.5, NAN)
	assert_eq(foe.slow, 0.0)
	assert_eq(foe.slow_timer, 0.0)


func test_a_slow_cannot_take_more_than_all_of_a_foes_speed() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 1.7, 1.0)
	assert_eq(foe.slow, 1.0)


func test_a_slowed_foe_walks_that_much_less_each_tick() -> void:
	var game := Game.create(1)
	var fast := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	var slowed := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	Status.apply_slow(slowed, 0.5, 5.0)
	Game.tick(game)
	assert_almost_eq(slowed.distance, fast.distance * 0.5, 1e-12)
	assert_gt(fast.distance, 0.0)


func test_a_slow_lasts_exactly_its_time_in_ticks() -> void:
	var game := Game.create(1)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	Status.apply_slow(foe, 0.5, 0.1)
	var walked: Array[float] = []
	for i in 5:
		var before := foe.distance
		Game.tick(game)
		walked.append(foe.distance - before)
	var full := walked[4]
	# 0.1 s is three ticks: three slowed steps, then full speed
	for i in 3:
		assert_almost_eq(walked[i], full * 0.5, 1e-12, "tick %d slowed" % i)
	assert_almost_eq(walked[3], full, 1e-12, "tick 3 full")
	assert_eq(foe.slow, 0.0)


func test_a_slow_draws_no_random_numbers() -> void:
	var game := Game.create(1)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	var waves := game.rng.state
	var routes := game.route_rng.state
	Status.apply_slow(foe, 0.5, 1.0)
	Game.tick(game)
	assert_eq(game.rng.state, waves)
	assert_eq(game.route_rng.state, routes)


func test_a_slow_that_runs_out_this_tick_is_gone_at_once() -> void:
	var game := Game.create(1)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	Status.apply_slow(foe, 0.5, 0.1)
	for i in 3:
		Game.tick(game)
	assert_eq(foe.slow, 0.0, "cleared in the tick of its last slowed step")
	assert_eq(foe.slow_timer, 0.0)


func test_a_timer_a_hair_above_zero_counts_as_run_out() -> void:
	var foe := _foe()
	Status.apply_slow(foe, 0.6, 1.0)
	foe.slow_timer = 1e-12
	Status.apply_slow(foe, 0.3, 2.0)
	assert_eq(foe.slow, 0.3, "the stronger slow had run out")
	assert_eq(foe.slow_timer, 2.0)
