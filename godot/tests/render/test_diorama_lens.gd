## The tilt-shift and the haze follow the camera: the middle of the screen stays sharp and
## clear at every zoom, and the blur and haze grow towards its edges.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func test_the_middle_of_the_screen_is_at_the_camera_distance() -> void:
	assert_almost_eq(DioramaLens.depth_at(40.0, 62.0, 0.0), 40.0, 1e-4)


func test_ground_higher_on_the_screen_is_further_away() -> void:
	var below := DioramaLens.depth_at(40.0, 62.0, -10.0)
	var above := DioramaLens.depth_at(40.0, 62.0, 10.0)
	assert_lt(below, 40.0)
	assert_gt(above, 40.0)
	# worked by hand: 40 * sin 62 / sin 52 * cos 10
	assert_almost_eq(above, 44.14, 0.01)


func test_the_play_area_is_sharp_and_the_edges_are_blurred() -> void:
	for view in [[60.0, 62.0], [18.0, 56.0]]:
		var distance: float = view[0]
		var blur := DioramaLens.focus(distance, view[1], 20.0)
		assert_lt(blur["near"], distance, "the middle is past the near blur")
		assert_gt(blur["far"], distance, "and before the far blur")
		var top := DioramaLens.depth_at(distance, view[1], 10.0)
		var bottom := DioramaLens.depth_at(distance, view[1], -10.0)
		assert_almost_eq(blur["far"] + blur["far_transition"], top, 1e-3, "full at the top")
		assert_almost_eq(blur["near"] - blur["near_transition"], bottom, 1e-3, "and the bottom")
		assert_gt(blur["far_transition"], 0.0)
		assert_gt(blur["near_transition"], 0.0)


func test_the_sharp_band_scales_with_the_zoom() -> void:
	var far := DioramaLens.focus(60.0, 62.0, 20.0)
	var close := DioramaLens.focus(20.0, 62.0, 20.0)
	assert_almost_eq(far["far"] / 60.0, close["far"] / 20.0, 1e-5)


func test_the_haze_leaves_the_middle_clear_and_thickens_past_the_top() -> void:
	var span := DioramaLens.haze(50.0, 62.0, 20.0)
	assert_gte(span.x, 50.0, "the middle is clear")
	assert_gt(span.y, DioramaLens.depth_at(50.0, 62.0, 10.0), "full only past the top edge")


func test_follow_fits_the_scene_to_the_camera() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var world := main.get_node("WorldEnvironment") as WorldEnvironment
	var attributes := (world.camera_attributes as CameraAttributesPractical).duplicate()
	var environment := world.environment.duplicate() as Environment
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.fov = 20.0
	camera.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	camera.global_position = Vector3(3.0, 30.0 * sin(deg_to_rad(60.0)), 0.0)
	DioramaLens.new().follow(camera, environment, attributes)
	var blur := DioramaLens.focus(30.0, 60.0, 20.0)
	assert_almost_eq(attributes.dof_blur_far_distance, blur["far"], 1e-3)
	assert_almost_eq(attributes.dof_blur_near_distance, blur["near"], 1e-3)
	assert_true(attributes.dof_blur_far_enabled and attributes.dof_blur_near_enabled)
	var span := DioramaLens.haze(30.0, 60.0, 20.0)
	assert_almost_eq(environment.fog_depth_begin, span.x, 1e-3)
	assert_almost_eq(environment.fog_depth_end, span.y, 1e-3)
