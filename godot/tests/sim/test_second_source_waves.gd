## From wave 11 the groups of a wave alternate between the two spawn sources.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _build(wave: int, routes: int) -> Array[SpawnOrder]:
	return WaveBuilder.build(wave, Rng.derive(42, Streams.WAVES), routes)


func test_the_first_ten_waves_do_not_name_a_route() -> void:
	for wave in range(1, WAVES.SECOND_SOURCE_AFTER_WAVE + 1):
		for order in _build(wave, 2):
			assert_eq(order.route, -1, "wave %d" % wave)


func test_a_single_route_game_never_names_a_route() -> void:
	for wave in [11, 15, 20]:
		for order in _build(wave, 1):
			assert_eq(order.route, -1)


func test_from_wave_11_every_rolled_foe_has_a_route_and_both_are_used() -> void:
	for wave in [11, 12, 15, 18]:
		var seen := {}
		for order in _build(wave, 2):
			assert_true(order.route == 0 or order.route == 1, "wave %d" % wave)
			seen[order.route] = true
		assert_true(seen.has(0) and seen.has(1), "wave %d uses both" % wave)


func test_a_group_stays_on_one_route_and_the_next_group_takes_the_other() -> void:
	var orders := _build(13, 2)
	var changes := 0
	for i in range(1, orders.size()):
		var inside_a_group := is_equal_approx(orders[i - 1].gap, WAVES.GROUP_SPACING)
		if inside_a_group:
			assert_eq(orders[i].route, orders[i - 1].route, "inside a group, order %d" % i)
		else:
			assert_ne(orders[i].route, orders[i - 1].route, "a new group, order %d" % i)
			changes += 1
	assert_gt(changes, 0, "a wave has several groups")


func test_the_waves_stream_is_drawn_the_same_with_or_without_a_second_route() -> void:
	for wave in [5, 11, 14, 20]:
		var one := Rng.derive(42, Streams.WAVES)
		var two := Rng.derive(42, Streams.WAVES)
		WaveBuilder.build(wave, one, 1)
		WaveBuilder.build(wave, two, 2)
		assert_eq(one.state, two.state, "wave %d" % wave)


func test_the_foes_and_pauses_do_not_change_only_the_routes() -> void:
	for wave in [11, 14]:
		var a := _build(wave, 1)
		var b := _build(wave, 2)
		assert_eq(a.size(), b.size())
		for i in a.size():
			assert_eq(a[i].type, b[i].type)
			assert_eq(a[i].gap, b[i].gap)


func test_a_launched_wave_11_puts_foes_on_both_routes() -> void:
	var game: GameState = null
	for map_seed in range(1, 40):
		var candidate := Game.create_on_strip_valley(map_seed)
		if candidate.routes.size() == 2:
			game = candidate
			break
	game.wave = WAVES.SECOND_SOURCE_AFTER_WAVE
	game.heartstone_health = 100000
	GameTestKit.run(game, [Command.launch_wave()])
	var used := {}
	for i in 3000:
		Game.tick(game)
		for foe in game.foes:
			used[foe.route] = true
		if game.spawners.is_empty():
			break
	assert_true(used.has(0) and used.has(1))


func test_the_boss_escort_and_the_golem_stay_on_the_main_road() -> void:
	var orders := _build(20, 2)
	assert_eq(orders[0].route, -1, "the escort")
	assert_eq(orders[orders.size() - 1].route, -1, "the Golem")
