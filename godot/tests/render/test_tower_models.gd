## Towers are drawn with the owner's papercraft models (`assets-src/papercraft/`), scaled a
## little bigger each tier, wearing the papercraft looks and playing their stop-motion clips;
## a missing file leaves the box.
extends GutTest

const SCENE := preload("res://render/tower_view.tscn")
const TOWERS := preload("res://content/towers.gd")
## The clip each tower plays when the game asks it to act.
const ACTIONS := {
	"spoolGuard": "fire",
	"thimbleMortar": "fire",
	"prismSpire": "fire",
	"guardTent": "deploy",
	"messTent": "serve"
}


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


func _meshes(node: Node, found: Array[MeshInstance3D] = []) -> Array[MeshInstance3D]:
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		_meshes(child, found)
	return found


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


func test_a_model_is_at_most_three_animated_parts() -> void:
	for id in TOWERS.TOWER_IDS:
		var parts := _meshes(_view(0, id).get_node("Model"))
		assert_between(parts.size(), 1, 3, id)


func test_every_part_wears_a_papercraft_shader_in_one_surface() -> void:
	for id in TOWERS.TOWER_IDS:
		for part in _meshes(_view(0, id).get_node("Model")):
			var surfaces := part.mesh.get_surface_count()
			# one craft surface a part, and the glass marble's shell beside it
			assert_between(surfaces, 1, 2, "%s %s" % [id, part.name])
			for i in surfaces:
				var material := part.mesh.surface_get_material(i)
				assert_true(material is ShaderMaterial, "%s %s surface %d" % [id, part.name, i])


func test_only_the_base_of_a_tower_casts_a_shadow() -> void:
	for id in TOWERS.TOWER_IDS:
		for part in _meshes(_view(0, id).get_node("Model")):
			var casts := part.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			assert_eq(casts, String(part.name).ends_with("_Base"), "%s %s" % [id, part.name])


func test_every_tower_idles_and_has_its_action_clip() -> void:
	for id in TOWERS.TOWER_IDS:
		var view := _view(0, id)
		assert_eq(view.clip(), "idle", id)
		var player := StopMotion.player_of(view)
		assert_true(player.has_animation(ACTIONS[id]), "%s has %s" % [id, ACTIONS[id]])
		assert_eq(player.get_animation("idle").loop_mode, Animation.LOOP_LINEAR, id)
		assert_eq(player.get_animation(ACTIONS[id]).loop_mode, Animation.LOOP_NONE, id)


func test_the_clips_step_like_stop_motion() -> void:
	for id in TOWERS.TOWER_IDS:
		var player := StopMotion.player_of(_view(0, id))
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			for track in animation.get_track_count():
				assert_eq(
					animation.track_get_interpolation_type(track),
					Animation.INTERPOLATION_NEAREST,
					"%s %s track %d" % [id, clip, track]
				)


func test_a_shooting_tower_plays_its_shot_then_idles_again() -> void:
	var view := _view(0, "thimbleMortar")
	view.fire(view.global_position + Vector3(3, 0, 0))
	assert_eq(view.clip(), "fire")
	view.advance(0.5)
	assert_eq(view.clip(), "fire", "the shot plays out")
	StopMotion.player_of(view).advance(2.0)
	view.advance(TowerView.AIM_HOLD + 0.1)
	assert_eq(view.clip(), "idle")


func test_an_aiming_tower_turns_its_head_to_what_it_shot() -> void:
	for id in ["spoolGuard", "thimbleMortar"]:
		var view := _view(0, id)
		var head := StopMotion.part(view, "_Head")
		assert_not_null(head, id)
		view.fire(view.global_position + Vector3(4, 0, 0))
		assert_almost_eq(head.rotation.y, PI / 2.0, 1e-4, "%s faces +x" % id)
		view.fire(view.global_position + Vector3(0, 0, -4))
		assert_almost_eq(absf(head.rotation.y), PI, 1e-4, "%s faces -z" % id)


func test_a_tower_that_does_not_aim_keeps_its_head() -> void:
	var view := _view(0, "prismSpire")
	var head := StopMotion.part(view, "_Head")
	var before := head.rotation
	view.fire(view.global_position + Vector3(4, 0, 0))
	assert_almost_eq(head.rotation.y, before.y, 1e-6)


func test_the_model_grows_a_little_each_tier() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		var raw := ModelLoader.bounds(look.model_path).end.y
		var last := 0.0
		for level in 3:
			var view := _view(level, id)
			var expected := raw * look.model_scale * (1.0 + TowerView.TIER_GROWTH * float(level))
			assert_almost_eq(view.body_height(), expected, 1e-5, "%s level %d" % [id, level])
			assert_almost_eq(TowerView.height_of(level, look), expected, 1e-5, id)
			assert_gt(view.body_height(), last)
			last = view.body_height()


func test_a_top_tier_model_still_fits_its_two_by_two_block() -> void:
	for id in TOWERS.TOWER_IDS:
		var look := TowerLooks.for_type(id)
		var box := ModelLoader.bounds(look.model_path)
		var scale := look.model_scale * (1.0 + TowerView.TIER_GROWTH * 2.0)
		for axis in [0, 2]:
			var far := maxf(absf(box.position[axis]), absf(box.end[axis]))
			assert_lte(far * scale, 1.0, "%s stays on its block (axis %d)" % [id, axis])


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
	view.fire(Vector3.ZERO)
	assert_eq(view.clip(), "", "a box has no clips")


func test_the_camp_cook_model_has_the_heros_clips() -> void:
	var packed := ModelLoader.scene("res://assets/models/heroes/camp_cook.glb")
	var cook := packed.instantiate()
	var player := StopMotion.player_of(cook)
	for clip in ["idle", "walk", "attack", "splash", "fall", "rise"]:
		assert_true(player.has_animation(clip), clip)
	assert_lte(_meshes(cook).size(), 3)
	cook.free()
