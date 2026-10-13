## Towers are drawn with the owner's greybox models, scaled a little bigger each tier,
## and the Heartstone marker too; a missing file leaves the box.
extends GutTest

const SCENE := preload("res://render/tower_view.tscn")
const TOWERS := preload("res://content/towers.gd")


func _tower(level: int, type: String) -> Tower:
	var tower := Tower.new()
	tower.id = 1
	tower.type = type
	tower.col = 3
	tower.row = 6
	tower.level = level
	return tower


func _view(level: int, type: String, look: TowerLook = null, footprint: int = 2) -> TowerView:
	var view := SCENE.instantiate() as TowerView
	add_child_autofree(view)
	view.setup(
		_tower(level, type), look if look != null else TowerLooks.for_type(type), 0.3, footprint
	)
	return view


func test_every_tower_look_names_an_existing_model() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		assert_ne(look.model_path, "", id)
		assert_true(ResourceLoader.exists(look.model_path), look.model_path)
		assert_gt(look.model_scale, 0.0, id)


func test_a_tower_is_drawn_with_its_model_and_not_the_box() -> void:
	for id in TOWERS.TOWER_IDS:
		var view := _view(0, id)
		assert_true(view.has_model(), id)
		assert_not_null(view.get_node_or_null("Model"), id)
		assert_null((view.get_node("Body") as MeshInstance3D).mesh, "no box for %s" % id)


func test_the_model_grows_a_little_each_tier() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		var raw := ModelLoader.mesh(look.model_path).get_aabb().end.y
		var last := 0.0
		for level in 3:
			var view := _view(level, id)
			var expected := raw * look.model_scale * (1.0 + TowerView.TIER_GROWTH * float(level))
			assert_almost_eq(view.body_height(), expected, 1e-5, "%s level %d" % [id, level])
			assert_gt(view.body_height(), last)
			last = view.body_height()


func test_a_top_tier_model_still_fits_its_two_by_two_block() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		var width := ModelLoader.mesh(look.model_path).get_aabb().size.x
		var scale := look.model_scale * (1.0 + TowerView.TIER_GROWTH * 2.0)
		assert_lte(width * scale, 2.0, "%s is no wider than the block" % id)


func test_the_pips_sit_above_the_model() -> void:
	var view := _view(2, "prismSpire")
	for pip in view.get_node("Pips").get_children():
		assert_gte((pip as Node3D).position.y, view.body_height(), "a pip above the top")
	assert_eq(view.pip_count(), 3)


func test_a_missing_model_file_leaves_the_box() -> void:
	var look := TowerLooks.for_type("spoolGuard").duplicate() as TowerLook
	look.model_path = "res://assets/models/towers/none.glb"
	var view := _view(1, "spoolGuard", look)
	assert_false(view.has_model())
	assert_not_null((view.get_node("Body") as MeshInstance3D).mesh)
	assert_almost_eq(view.body_height(), look.base_height + look.height_per_level, 1e-6)
