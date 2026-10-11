## Project checks: the project is set up the way the plan says.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


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


func test_main_scene_draws_the_board_with_a_camera() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var board := main.get_node("Board") as Board
	assert_not_null(board)
	assert_gt(board.road_count, 0)
	assert_gt(board.plot_count, 0)
	var rig := main.get_node("CameraRig") as CameraRig
	assert_not_null(rig)
	assert_not_null(rig.get_child(0) as Camera3D)
	assert_eq(main.get_node("Hud/NextSeed").get("text"), "Next seed")


func test_next_seed_button_rebuilds_the_board() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var board := main.get_node("Board") as Board
	var before := board.map.path
	(main.get_node("Hud/NextSeed") as Button).pressed.emit()
	assert_eq(board.map_seed, 2)
	assert_ne(board.map.path, before)


func test_engine_matches_pinned_version() -> void:
	var pinned := (
		FileAccess
		. get_file_as_string(ProjectSettings.globalize_path("res://") + "../.godot-version")
		. strip_edges()
	)
	var info := Engine.get_version_info()
	var running := "%d.%d.%d-%s" % [info.major, info.minor, info.patch, info.status]
	assert_eq(running, pinned)
