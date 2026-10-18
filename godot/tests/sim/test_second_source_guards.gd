## Guards hold foes of the second route once those foes are on the main road.
extends GutTest


## A game with a Guard Tent whose guards stand past the point where the second road joins, or null.
func _game_with_post_past_the_join() -> GameState:
	for map_seed in range(1, 80):
		var game := GuardKit.game_with_tent(map_seed)
		if game.routes.size() < 2:
			continue
		var join_main := game.routes[0].cell_distance(game.map.join_index)
		if GuardKit.post(game) > join_main + 0.8:
			return game
	return null


func test_a_second_route_foe_on_the_main_road_has_a_main_distance() -> void:
	var game := _game_with_post_past_the_join()
	assert_not_null(game, "some seed has a tent past the join")
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 1)
	var join_on_second := game.routes[1].cell_distance(game.map.feeder_length)
	foe.distance = join_on_second - 0.5
	assert_eq(Barracks.main_distance(game, foe), -1.0, "still on the feeder")
	foe.distance = join_on_second + 3.0
	assert_almost_eq(
		Barracks.main_distance(game, foe), join_on_second + 3.0 - game.second_offset, 1e-9
	)
	var main_foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	main_foe.distance = 4.0
	assert_eq(Barracks.main_distance(game, main_foe), 4.0)


func test_a_guard_holds_a_second_route_foe_that_has_walked_up_to_its_post() -> void:
	var game := _game_with_post_past_the_join()
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 1)
	foe.distance = GuardKit.post(game) - 0.1 + game.second_offset
	GuardKit.tick(game, 1)
	assert_ne(foe.engaged_guard_id, -1, "the guard took the foe")


func test_a_foe_still_on_the_feeder_is_not_held_by_a_post_it_has_not_reached() -> void:
	var game := _game_with_post_past_the_join()
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 1)
	# the same number on its own route is somewhere on the feeder or just after the join
	foe.distance = game.routes[1].cell_distance(game.map.feeder_length) - 0.5
	GuardKit.tick(game, 1)
	assert_eq(foe.engaged_guard_id, -1)


func test_on_the_old_random_detour_a_foe_of_another_lane_is_never_on_the_main_road() -> void:
	var game := Game.create(7, 9, 13, true, 1)
	assert_true(game.random_lanes)
	assert_gte(game.routes.size(), 2)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 1)
	foe.distance = 8.0
	assert_eq(Barracks.main_distance(game, foe), -1.0)
