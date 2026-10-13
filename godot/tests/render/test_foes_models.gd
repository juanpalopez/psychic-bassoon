## The Scrap Goblin is drawn with the owner's greybox model; other foes keep their
## capsules, and a missing model file falls back to a capsule.
extends GutTest

const FOES := preload("res://content/foes.gd")
const MODELS := preload("res://render/foes_view.gd").MODELS


func _foe(id: int, type: String, x: float, y: float) -> Foe:
	var foe := Foe.new()
	foe.id = id
	foe.type = type
	foe.x = x
	foe.y = y
	foe.hp = 20
	foe.max_hp = 20
	foe.radius = float(FOES.DEFS[type].radius)
	return foe


func _game_with(foes: Array[Foe], tick: int) -> GameState:
	var game := GameState.new()
	game.tick_count = tick
	game.foes = foes
	return game


func _view(models: Dictionary = MODELS) -> FoesView:
	var view := FoesView.new(models)
	add_child_autofree(view)
	return view


func test_the_scrap_goblin_uses_the_model_and_the_others_stay_capsules() -> void:
	var view := _view()
	assert_true(view.uses_model("scrapGoblin"))
	assert_false(view.mesh_of("scrapGoblin") is CapsuleMesh)
	assert_gt(view.mesh_of("scrapGoblin").get_aabb().size.y, 0.0)
	assert_false(view.uses_model("corrugatedOrc"))
	assert_true(view.mesh_of("corrugatedOrc") is CapsuleMesh)
	assert_true(view.mesh_of("cardboardGolem") is CapsuleMesh)


func test_a_missing_model_file_falls_back_to_a_capsule() -> void:
	var view := _view({"scrapGoblin": {"path": "res://assets/models/none.glb", "height": 0.8}})
	assert_false(view.uses_model("scrapGoblin"))
	assert_true(view.mesh_of("scrapGoblin") is CapsuleMesh)
	view.update(_game_with([_foe(0, "scrapGoblin", 4.5, 3.5)] as Array[Foe], 1), 1.0)
	assert_eq(view.visible_count("scrapGoblin"), 1, "and it still draws")


func test_the_model_is_scaled_to_its_height_and_stands_with_its_feet_on_the_road() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.5, 3.5)] as Array[Foe], 1), 1.0)
	var aabb := view.mesh_of("scrapGoblin").get_aabb()
	var scale := view.drawn_scale("scrapGoblin", 0)
	assert_almost_eq(scale * aabb.size.y, float(MODELS.scrapGoblin.height), 1e-6)
	# the lowest point of the model is at the road's surface
	assert_almost_eq(
		view.drawn_position("scrapGoblin", 0).y + aabb.position.y * scale, FoesView.GROUND, 1e-6
	)


func test_a_foe_faces_the_way_it_walks() -> void:
	var view := _view()
	# a tick ago it was at (4, 3), now at (5, 3): walking along +x, which is world +x
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 3.0)] as Array[Foe], 1), 1.0)
	view.update(_game_with([_foe(0, "scrapGoblin", 5.0, 3.0)] as Array[Foe], 2), 1.0)
	assert_almost_eq(view.drawn_yaw("scrapGoblin", 0), PI / 2.0, 1e-6, "facing +x")
	# then down the board, along +y (world +z)
	view.update(_game_with([_foe(0, "scrapGoblin", 5.0, 4.0)] as Array[Foe], 3), 1.0)
	assert_almost_eq(view.drawn_yaw("scrapGoblin", 0), 0.0, 1e-6, "facing +z")
	# and back along -x
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 4.0)] as Array[Foe], 4), 1.0)
	assert_almost_eq(absf(view.drawn_yaw("scrapGoblin", 0)), 3.0 * PI / 2.0 - PI, 1e-6)


func test_a_foe_that_stands_still_keeps_its_heading() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 3.0)] as Array[Foe], 1), 1.0)
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 4.0)] as Array[Foe], 2), 1.0)
	var heading := view.drawn_yaw("scrapGoblin", 0)
	# held by a guard: the same place next tick
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 4.0)] as Array[Foe], 3), 1.0)
	assert_almost_eq(view.drawn_yaw("scrapGoblin", 0), heading, 1e-9)


func test_a_new_foe_faces_along_the_road_until_it_moves() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 3.0)] as Array[Foe], 1), 1.0)
	assert_almost_eq(view.drawn_yaw("scrapGoblin", 0), PI / 2.0, 1e-6)


func test_reset_forgets_the_headings() -> void:
	var view := _view()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 3.0)] as Array[Foe], 1), 1.0)
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 4.0)] as Array[Foe], 2), 1.0)
	view.reset()
	view.update(_game_with([_foe(0, "scrapGoblin", 4.0, 3.0)] as Array[Foe], 1), 1.0)
	assert_almost_eq(view.drawn_yaw("scrapGoblin", 0), PI / 2.0, 1e-6, "a new game, a new heading")
