## The foes on the board: one MultiMesh per foe type, smooth between ticks.
extends GutTest

const FOES := preload("res://content/foes.gd")


func _view() -> FoesView:
	var view := FoesView.new()
	add_child_autofree(view)
	return view


func _foe(id: int, type: String, x: float, y: float, hp: int = 20, max_hp: int = 20) -> Foe:
	var foe := Foe.new()
	foe.id = id
	foe.type = type
	foe.x = x
	foe.y = y
	foe.hp = hp
	foe.max_hp = max_hp
	foe.radius = float(FOES.DEFS[type].radius)
	return foe


func _game_with(foes: Array[Foe], tick: int = 1) -> GameState:
	var game := GameState.new()
	game.tick_count = tick
	game.foes = foes
	return game


func _multimesh(view: FoesView, type: String) -> MultiMesh:
	return (view.get_node(type) as MultiMeshInstance3D).multimesh


func _at(view: FoesView, type: String, index: int) -> Vector3:
	return view.drawn_position(type, index)


func test_there_is_one_multimesh_per_foe_type_and_no_node_per_foe() -> void:
	var view := _view()
	assert_eq(view.get_child_count(), FOES.FOE_IDS.size() + 1, "the types and the bars")
	for type in FOES.FOE_IDS:
		assert_true(view.get_node(type) is MultiMeshInstance3D, type)
		assert_eq(_multimesh(view, type).instance_count, FoesView.MAX_PER_TYPE)
		assert_eq(view.visible_count(type), 0)
	view.update(_game_with([_foe(0, "scrapGoblin", 4.5, 3.5)] as Array[Foe]), 1.0)
	assert_eq(view.get_child_count(), FOES.FOE_IDS.size() + 1, "still no node per foe")


func test_each_foe_is_drawn_in_its_types_multimesh() -> void:
	var view := _view()
	var foes: Array[Foe] = [
		_foe(0, "scrapGoblin", 4.5, 3.5),
		_foe(1, "scrapGoblin", 4.5, 4.5),
		_foe(2, "corrugatedOrc", 2.5, 6.5, 130, 130),
	]
	view.update(_game_with(foes), 1.0)
	assert_eq(view.visible_count("scrapGoblin"), 2)
	assert_eq(view.visible_count("corrugatedOrc"), 1)
	assert_eq(view.visible_count("cardboardGolem"), 0)


func test_a_foe_stands_at_its_sim_position_on_the_board() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.5, 3.5)] as Array[Foe]), 1.0)
	var at := _at(view, "scrapGoblin", 0)
	var expected := BoardSpace.point_to_world(4.5, 3.5)
	assert_almost_eq(at.x, expected.x, 1e-5)
	assert_almost_eq(at.z, expected.z, 1e-5)
	assert_gt(at.y, 0.0, "it stands on the board, not in it")


func test_a_new_foe_starts_at_its_position_whatever_the_blend() -> void:
	var view := _view()
	var foe := _foe(0, "scrapGoblin", 4.5, 3.5)
	view.update(_game_with([foe] as Array[Foe]), 0.0)
	var expected := BoardSpace.point_to_world(4.5, 3.5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, expected.x, 1e-5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).z, expected.z, 1e-5)


func test_between_ticks_a_foe_moves_from_where_it_was_to_where_it_is() -> void:
	var view := _view()
	var foe := _foe(0, "scrapGoblin", 4.5, 3.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	# the next tick: the foe has walked one cell down
	foe.y = 4.0
	var game := _game_with([foe] as Array[Foe], 2)
	view.update(game, 0.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 3.0).x, 1e-5)
	view.update(game, 0.5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 3.5).x, 1e-5)
	view.update(game, 1.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 4.0).x, 1e-5)


func test_the_blend_is_clamped_to_the_two_positions() -> void:
	var view := _view()
	var foe := _foe(0, "scrapGoblin", 4.5, 3.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	foe.y = 4.0
	var game := _game_with([foe] as Array[Foe], 2)
	view.update(game, -3.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 3.0).x, 1e-5)
	view.update(game, 9.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 4.0).x, 1e-5)


func test_a_foe_that_is_gone_disappears() -> void:
	var view := _view()
	var a := _foe(0, "scrapGoblin", 4.5, 3.5)
	var b := _foe(1, "scrapGoblin", 4.5, 4.5)
	view.update(_game_with([a, b] as Array[Foe], 1), 1.0)
	view.update(_game_with([b] as Array[Foe], 2), 1.0)
	assert_eq(view.visible_count("scrapGoblin"), 1)
	var expected := BoardSpace.point_to_world(4.5, 4.5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, expected.x, 1e-5)


func test_more_foes_than_the_cap_are_clamped_not_an_error() -> void:
	var view := _view()
	var foes: Array[Foe] = []
	for i in FoesView.MAX_PER_TYPE + 40:
		foes.append(_foe(i, "scrapGoblin", 4.5, 3.5))
	view.update(_game_with(foes), 1.0)
	assert_eq(view.visible_count("scrapGoblin"), FoesView.MAX_PER_TYPE)


func test_a_hurt_foe_is_drawn_darker() -> void:
	var view := _view()
	var foes: Array[Foe] = [
		_foe(0, "corrugatedOrc", 4.5, 3.5, 130, 130),
		_foe(1, "corrugatedOrc", 4.5, 4.5, 40, 130),
	]
	view.update(_game_with(foes), 1.0)
	var healthy := view.drawn_colour("corrugatedOrc", 0)
	var hurt := view.drawn_colour("corrugatedOrc", 1)
	assert_gt(healthy.v, hurt.v)


func test_a_bigger_foe_is_drawn_taller() -> void:
	var view := _view()
	view.update(
		_game_with(
			(
				[_foe(0, "scrapGoblin", 4.5, 3.5), _foe(1, "cardboardGolem", 4.5, 4.5, 850, 850)]
				as Array[Foe]
			)
		),
		1.0
	)
	# a model is scaled to its height, a capsule by the foe's radius: compare what is drawn
	var small := view.drawn_scale("scrapGoblin", 0) * view.mesh_of("scrapGoblin").get_aabb().size.y
	var large := (
		view.drawn_scale("cardboardGolem", 0) * view.mesh_of("cardboardGolem").get_aabb().size.y
	)
	assert_gt(large, small)


func test_reset_forgets_old_positions() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.5, 3.0)] as Array[Foe], 5), 1.0)
	view.reset()
	# a new game reuses id 0 at a different place: no blend from the old one
	view.update(_game_with([_foe(0, "scrapGoblin", 2.5, 8.0)] as Array[Foe], 1), 0.0)
	var expected := BoardSpace.point_to_world(2.5, 8.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, expected.x, 1e-5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).z, expected.z, 1e-5)


func test_the_multimeshes_carry_colours_and_3d_transforms() -> void:
	var view := _view()
	for type in FOES.FOE_IDS:
		var multimesh := _multimesh(view, type)
		assert_true(multimesh.use_colors, type)
		assert_eq(multimesh.transform_format, MultiMesh.TRANSFORM_3D, type)


func test_two_ticks_between_updates_blend_over_the_two_tick_walk() -> void:
	var view := _view()
	var foe := _foe(0, "scrapGoblin", 4.5, 3.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	foe.y = 5.0
	var game := _game_with([foe] as Array[Foe], 3)
	view.update(game, 0.5)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 4.0).x, 1e-5)


func test_updating_twice_on_the_same_tick_does_not_move_the_foe() -> void:
	var view := _view()
	var foe := _foe(0, "scrapGoblin", 4.5, 3.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	foe.y = 4.0
	var game := _game_with([foe] as Array[Foe], 2)
	view.update(game, 0.25)
	var first := _at(view, "scrapGoblin", 0)
	view.update(game, 0.25)
	assert_eq(_at(view, "scrapGoblin", 0), first)


func test_a_foe_that_appears_mid_run_starts_in_place_beside_a_walking_one() -> void:
	var view := _view()
	var walker := _foe(0, "scrapGoblin", 4.5, 3.0)
	view.update(_game_with([walker] as Array[Foe], 1), 1.0)
	walker.y = 4.0
	var newcomer := _foe(1, "scrapGoblin", 2.5, 0.5)
	view.update(_game_with([walker, newcomer] as Array[Foe], 2), 0.0)
	assert_almost_eq(_at(view, "scrapGoblin", 0).x, BoardSpace.point_to_world(4.5, 3.0).x, 1e-5)
	assert_almost_eq(_at(view, "scrapGoblin", 1).x, BoardSpace.point_to_world(2.5, 0.5).x, 1e-5)
	assert_almost_eq(_at(view, "scrapGoblin", 1).z, BoardSpace.point_to_world(2.5, 0.5).z, 1e-5)


func _bars(view: FoesView) -> FoeBars:
	return view.get_node("HealthBars") as FoeBars


func test_hurt_foes_get_a_bar_and_healthy_or_dying_ones_do_not() -> void:
	var view := _view()
	var dying := _foe(2, "scrapGoblin", 4.5, 5.5, 5, 20)
	dying.alive = false
	var foes: Array[Foe] = [
		_foe(0, "scrapGoblin", 4.5, 3.5, 20, 20),
		_foe(1, "scrapGoblin", 4.5, 4.5, 10, 20),
		dying,
		_foe(3, "cardboardGolem", 2.5, 6.5, 100, 400),
	]
	view.update(_game_with(foes), 1.0)
	assert_eq(_bars(view).bar_count(), 2)
