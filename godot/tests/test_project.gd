## Phase 3 checks: the project is set up the way the plan says.
extends GutTest


func test_renderer_is_compatibility_for_web() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.web"), "gl_compatibility"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility"
	)


func test_game_is_landscape_only() -> void:
	# 0 is landscape in Godot's DisplayServer.ScreenOrientation
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0)


func test_main_scene_is_set_and_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(path, "res://main.tscn")
	var scene := load(path) as PackedScene
	assert_not_null(scene)


func test_stub_scene_builds_80_foes_in_one_multimesh() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var multimeshes: Array = []
	for child in main.get_children():
		if child is MultiMeshInstance3D:
			multimeshes.append(child)
	assert_eq(multimeshes.size(), 1, "one MultiMesh for all foes")
	assert_eq((multimeshes[0] as MultiMeshInstance3D).multimesh.instance_count, 80)
