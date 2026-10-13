## One tower as its own scene instance: a body that grows with the tier, and a
## pip for each tier it has reached.
extends GutTest

const SCENE := preload("res://render/tower_view.tscn")


func _tower(level: int, type: String = "spoolGuard") -> Tower:
	var tower := Tower.new()
	tower.id = 4
	tower.type = type
	tower.col = 3
	tower.row = 6
	tower.level = level
	return tower


func _view(level: int, top: float = 0.3, type: String = "spoolGuard") -> TowerView:
	var view := SCENE.instantiate() as TowerView
	add_child_autofree(view)
	view.setup(_tower(level, type), TowerLooks.for_type(type), top)
	return view


func test_the_scene_is_a_tower_view_with_a_body() -> void:
	var view := SCENE.instantiate()
	add_child_autofree(view)
	assert_true(view is TowerView)
	assert_not_null(view.get_node("Body"))


func test_it_stands_on_its_cell_at_the_height_of_the_tile() -> void:
	var view := _view(0, 0.52)
	var at := BoardSpace.cell_to_world(3, 6)
	assert_almost_eq(view.position.x, at.x, 1e-6)
	assert_almost_eq(view.position.z, at.z, 1e-6)
	assert_almost_eq(view.position.y, 0.52, 1e-6)
	assert_eq(view.tower_id, 4)


func test_the_box_body_grows_with_each_tier_by_the_looks_numbers() -> void:
	# a look without a model draws the box (the models are tested in test_tower_models.gd)
	var look := TowerLooks.for_type("spoolGuard").duplicate() as TowerLook
	look.model_path = ""
	for level in 3:
		var view := SCENE.instantiate() as TowerView
		add_child_autofree(view)
		view.setup(_tower(level), look, 0.3)
		assert_almost_eq(
			view.body_height(), look.base_height + look.height_per_level * float(level), 1e-5
		)


func test_each_tier_adds_a_visible_pip() -> void:
	for level in 3:
		assert_eq(_view(level).pip_count(), level + 1, "level %d" % level)


func test_the_body_is_coloured_by_the_looks_colour() -> void:
	for type in ["spoolGuard", "thimbleMortar", "prismSpire"]:
		var view := _view(0, 0.3, type)
		assert_eq(view.body_colour(), TowerLooks.for_type(type).body_colour, type)


func test_setting_up_again_rebuilds_the_pips_not_adds_to_them() -> void:
	var view := _view(0)
	view.setup(_tower(2), TowerLooks.for_type("spoolGuard"), 0.3)
	assert_eq(view.pip_count(), 3)


func test_a_tower_on_a_block_stands_at_the_blocks_centre() -> void:
	var view := SCENE.instantiate() as TowerView
	add_child_autofree(view)
	view.setup(_tower(0), TowerLooks.for_type("spoolGuard"), 0.5, 2)
	var middle := BoardSpace.footprint_centre(Vector2i(3, 6), 2)
	assert_almost_eq(view.position.x, middle.x, 1e-6)
	assert_almost_eq(view.position.z, middle.z, 1e-6)
