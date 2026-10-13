## The guards of the Guard Tents, drawn at their posts on the road.
extends GutTest


func _view() -> GuardsView:
	var view := GuardsView.new()
	add_child_autofree(view)
	return view


func test_one_guard_is_drawn_for_each_live_guard_at_its_post() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	assert_eq(view.guard_count(), 2)
	for guard in game.guards:
		var at := game.routes[0].position_at(guard.post)
		var world := BoardSpace.point_to_world(at.x, at.y)
		var drawn := view.position_of(guard.id)
		assert_almost_eq(drawn.x, world.x, 1e-6)
		assert_almost_eq(drawn.z, world.z, 1e-6)
		assert_true(view.is_shown(guard.id))


func test_a_fallen_guard_is_hidden_and_comes_back_with_the_raise() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	var guard: Guard = game.guards[0]
	guard.alive = false
	view.update(game)
	assert_false(view.is_shown(guard.id))
	assert_true(view.is_shown(game.guards[1].id))
	guard.alive = true
	view.update(game)
	assert_true(view.is_shown(guard.id))


func test_the_health_bar_follows_the_guards_health() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	assert_almost_eq(view.health_fraction_of(game.guards[0].id), 1.0, 1e-9)
	game.guards[0].hp = 15.0
	view.update(game)
	assert_almost_eq(view.health_fraction_of(game.guards[0].id), 0.25, 1e-9)


func test_selling_the_tent_removes_the_guards_from_the_view() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	assert_eq(view.get_child_count(), 2)
	GameTestKit.run(game, [Command.sell(GuardKit.tent(game).id)])
	view.update(game)
	assert_eq(view.guard_count(), 0)
	assert_eq(view.get_child_count(), 0, "the nodes are freed")


func test_updating_again_keeps_the_same_nodes() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	var first := view.get_child(0)
	view.update(game)
	view.update(game)
	assert_eq(view.get_child(0), first)
	assert_eq(view.get_child_count(), 2)


func test_a_guard_with_no_health_pool_draws_an_empty_bar_not_nan() -> void:
	var game := GuardKit.game_with_tent()
	game.guards[0].max_hp = 0.0
	game.guards[0].hp = 0.0
	var view := _view()
	view.update(game)
	assert_eq(view.health_fraction_of(game.guards[0].id), 0.0)


func test_reset_forgets_the_guards() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	view.reset()
	assert_eq(view.guard_count(), 0)
	assert_eq(view.get_child_count(), 0)


func test_no_guards_means_nothing_is_drawn() -> void:
	var game := Game.create(1)
	var view := _view()
	view.update(game)
	assert_eq(view.get_child_count(), 0)
