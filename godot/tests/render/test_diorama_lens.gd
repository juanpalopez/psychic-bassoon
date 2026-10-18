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
		# the middle 80% of the screen is between the near and the far blur
		for tenth in range(-4, 5):
			var depth := DioramaLens.depth_at(distance, view[1], float(tenth))
			assert_between(depth, blur.z - 1e-4, blur.x + 1e-4, "%d degrees" % tenth)
		var top := DioramaLens.depth_at(distance, view[1], 10.0)
		var bottom := DioramaLens.depth_at(distance, view[1], -10.0)
		assert_almost_eq(blur.x + blur.y, top, 1e-3, "full at the top")
		assert_almost_eq(blur.z - blur.w, bottom, 1e-3, "and the bottom")
		assert_gt(blur.y, 0.0)
		assert_gt(blur.w, 0.0)


func test_the_sharp_band_scales_with_the_zoom() -> void:
	var far := DioramaLens.focus(60.0, 62.0, 20.0)
	var close := DioramaLens.focus(20.0, 62.0, 20.0)
	assert_almost_eq(far.x / 60.0, close.x / 20.0, 1e-5)


## The haze the scene's fog draws on the ground seen `angle` degrees above the middle.
func _haze_at(environment: Environment, distance: float, pitch: float, angle: float) -> float:
	var span := DioramaLens.haze(distance, pitch, 20.0)
	return DioramaLens.haze_amount(
		DioramaLens.distance_at(distance, pitch, angle),
		span,
		environment.fog_depth_curve,
		environment.fog_density
	)


func test_the_middle_of_the_screen_is_never_hazed() -> void:
	var scene := MAIN_SCENE.instantiate()
	var environment := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	scene.free()
	for view in [[60.0, 62.0], [35.0, 59.0], [18.0, 56.0]]:
		# the bottom of the screen up to half way to the top: no haze at all
		for angle in [-10.0, -5.0, 0.0, 2.5, 4.9]:
			assert_eq(
				_haze_at(environment, view[0], view[1], angle), 0.0, "%s at %s" % [view, angle]
			)
		var top := _haze_at(environment, view[0], view[1], 10.0)
		assert_between(top, 0.05, 0.3, "a light haze at the top edge, %s" % [view])


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
	assert_almost_eq(attributes.dof_blur_far_distance, blur.x, 1e-3)
	assert_almost_eq(attributes.dof_blur_near_distance, blur.z, 1e-3)
	assert_true(attributes.dof_blur_far_enabled and attributes.dof_blur_near_enabled)
	var span := DioramaLens.haze(30.0, 60.0, 20.0)
	assert_almost_eq(environment.fog_depth_begin, span.x, 1e-3)
	assert_almost_eq(environment.fog_depth_end, span.y, 1e-3)


func test_the_game_fits_the_lens_to_its_camera_each_frame() -> void:
	var packed := MAIN_SCENE.instantiate()
	var defaults := packed.get_node("WorldEnvironment") as WorldEnvironment
	var far_default := (
		(defaults.camera_attributes as CameraAttributesPractical).dof_blur_far_distance
	)
	var fog_default := defaults.environment.fog_depth_begin
	packed.free()
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world := main.get_node("WorldEnvironment") as WorldEnvironment
	var attributes := world.camera_attributes as CameraAttributesPractical
	assert_ne(attributes.dof_blur_far_distance, far_default, "the far blur follows the camera")
	assert_ne(world.environment.fog_depth_begin, fog_default, "and so does the haze")
	var camera := (main.get_node("CameraRig") as CameraRig).camera()
	var forward := -camera.global_basis.z
	var distance := camera.global_position.y / -forward.y
	var blur := DioramaLens.focus(distance, rad_to_deg(asin(-forward.y)), camera.fov)
	assert_almost_eq(attributes.dof_blur_far_distance, blur.x, 1e-2)
