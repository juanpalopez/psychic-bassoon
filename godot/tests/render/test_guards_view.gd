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


func test_a_fallen_guard_falls_then_is_hidden_and_comes_back_with_the_raise() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	var guard: Guard = game.guards[0]
	guard.alive = false
	view.update(game)
	assert_eq(view.state_of(guard.id), "fall")
	assert_eq(view.clip_of(guard.id), "fall")
	assert_true(view.is_shown(guard.id), "drawn while it falls")
	view.advance(GuardsView.FALL_SECONDS + 0.01)
	assert_false(view.is_shown(guard.id), "hidden once the fall is over")
	assert_true(view.is_shown(game.guards[1].id))
	guard.alive = true
	view.update(game)
	assert_true(view.is_shown(guard.id))
	assert_eq(view.clip_of(guard.id), "rise", "it springs back up")
	assert_eq(view.state_of(guard.id), "idle")


func test_a_guard_is_the_papercraft_model_and_idles() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	for guard in game.guards:
		assert_eq(view.clip_of(guard.id), "idle")
	var model := view.get_child(0).get_node_or_null("Model")
	assert_not_null(model, "the guard model, not the capsule")


func test_a_guard_holding_a_foe_strikes_until_it_is_free() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	var guard: Guard = game.guards[0]
	guard.foe_id = 7
	view.update(game)
	assert_eq(view.clip_of(guard.id), "strike")
	view.update(game)
	assert_eq(view.clip_of(guard.id), "strike", "the strike keeps looping")
	guard.foe_id = -1
	view.update(game)
	assert_eq(view.clip_of(guard.id), "idle")


func test_a_guard_faces_up_the_road() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	var guard: Guard = game.guards[0]
	var route: Route = game.routes[0]
	var here := route.position_at(guard.post)
	var ahead := route.position_at(guard.post - GuardsView.LOOK_AHEAD)
	var toward := (
		BoardSpace.point_to_world(ahead.x, ahead.y) - BoardSpace.point_to_world(here.x, here.y)
	)
	var node := view.get_child(0) as Node3D
	var facing := node.global_transform.basis.z
	assert_gt(facing.dot(toward.normalized()), 0.99)


func test_the_health_bar_follows_the_guards_health() -> void:
	var game := GuardKit.game_with_tent()
	var view := _view()
	view.update(game)
	assert_almost_eq(view.health_fraction_of(game.guards[0].id), 1.0, 1e-9)
	game.guards[0].hp = 30.0
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
