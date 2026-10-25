## The phone check keeps a fixed number of foes walking, without a wave, towers or a win.
extends GutTest

const RULES := preload("res://content/game_rules.gd")


func _alive(game: GameState) -> int:
	var count := 0
	for foe in game.foes:
		if foe.alive:
			count += 1
	return count


func _run(game: GameState, ticks: int, target: int) -> void:
	for i in ticks:
		Stress.top_up(game, target)
		Game.tick(game)


func test_the_first_call_fills_up_to_the_target() -> void:
	var game := Game.create_on_strip_valley(1)
	Stress.top_up(game, 80)
	assert_eq(_alive(game), 80)


func test_the_first_fill_spreads_the_foes_along_the_road() -> void:
	var game := Game.create_on_strip_valley(1)
	Stress.top_up(game, 80)
	var near_start := 0
	var past_middle := 0
	for foe in game.foes:
		if foe.distance < game.routes[0].total * 0.1:
			near_start += 1
		if foe.distance > game.routes[0].total * 0.5:
			past_middle += 1
	assert_lt(near_start, 20, "not stacked on the spawn point")
	assert_gt(past_middle, 20, "some are far along already")


func test_it_never_goes_above_the_target() -> void:
	var game := Game.create_on_strip_valley(1)
	for i in 10:
		Stress.top_up(game, 40)
	assert_eq(_alive(game), 40)


func test_the_count_holds_for_a_whole_crossing_and_the_game_does_not_end() -> void:
	var game := Game.create_on_strip_valley(1)
	_run(game, 2400, 80)
	assert_between(_alive(game), 75, 80, "foes leak at the Heartstone and are replaced")
	assert_false(game.over)
	assert_gte(game.heartstone_health, 1)


func test_the_mix_has_goblins_orcs_and_a_golem_in_a_big_crowd() -> void:
	var game := Game.create_on_strip_valley(1)
	Stress.top_up(game, 100)
	var types := {}
	for foe in game.foes:
		types[foe.type] = true
	for type in ["scrapGoblin", "corrugatedOrc", "cardboardGolem"]:
		assert_true(types.has(type), type)


func test_the_same_game_gives_the_same_crowd() -> void:
	var a := Game.create_on_strip_valley(7)
	var b := Game.create_on_strip_valley(7)
	_run(a, 300, 60)
	_run(b, 300, 60)
	assert_eq(GameTestKit.snapshot(a), GameTestKit.snapshot(b))


func test_a_target_of_zero_does_nothing() -> void:
	var game := Game.create_on_strip_valley(1)
	Stress.top_up(game, 0)
	assert_eq(game.foes.size(), 0)
	assert_eq(game.events.size(), 0)


func test_after_a_loss_the_crowd_refills_one_foe_a_tick_at_the_spawn_point() -> void:
	var game := Game.create_on_strip_valley(1)
	Stress.top_up(game, 10)
	for i in 4:
		game.foes[i].alive = false
	var before := game.foes.size()
	Stress.top_up(game, 10)
	assert_eq(game.foes.size(), before + 1, "one new foe, not four")
	assert_eq(game.foes[game.foes.size() - 1].distance, 0.0, "at the spawn point")
