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
		# the ground from the bottom edge up to 80% of the way to the top edge is sharp
		for degrees in range(-10, 9):
			var depth := DioramaLens.depth_at(distance, view[1], float(degrees))
			assert_lte(depth, blur.x + 1e-4, "%d degrees is sharp, %s" % [degrees, view])
		var top := DioramaLens.depth_at(distance, view[1], 10.0)
		assert_gt(DioramaLens.depth_at(distance, view[1], 9.0), blur.x, "9 degrees is blurred")
		assert_almost_eq(blur.x + blur.y, top, 1e-3, "full at the top")
		assert_gt(blur.y, 0.0)


## The view depth of the head of something `height` metres tall standing on the ground seen
## `degrees` from the middle of the screen (it leans towards the camera, which looks down).
func _head_depth(distance: float, pitch: float, degrees: float, height: float) -> float:
	return DioramaLens.depth_at(distance, pitch, degrees) - height * sin(deg_to_rad(pitch))


func test_a_standing_foe_in_the_play_area_is_never_blurred() -> void:
	var scene := MAIN_SCENE.instantiate()
	var attributes := (
		(scene.get_node("WorldEnvironment") as WorldEnvironment).camera_attributes
		as CameraAttributesPractical
	)
	scene.free()
	assert_false(attributes.dof_blur_near_enabled, "no near blur to catch a foe's head")
	for view in [[60.0, 62.0], [35.0, 59.0], [18.0, 56.0]]:
		var blur := DioramaLens.focus(view[0], view[1], 20.0)
		# a Cardboard Golem (2 m) or a tower on its block (4 m), from the bottom to row 0.1
		for degrees in range(-10, 9):
			for height in [0.8, 2.0, 4.0]:
				var head := _head_depth(view[0], view[1], float(degrees), height)
				assert_lt(head, blur.x, "%s m at %d degrees, %s" % [height, degrees, view])


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
	assert_almost_eq(attributes.dof_blur_far_transition, blur.y, 1e-3)
	assert_true(attributes.dof_blur_far_enabled)
	var span := DioramaLens.haze(30.0, 60.0, 20.0)
	assert_almost_eq(environment.fog_depth_begin, span.x, 1e-3)
	assert_almost_eq(environment.fog_depth_end, span.y, 1e-3)


func test_the_shadows_reach_past_the_top_of_the_screen_at_every_zoom() -> void:
	for view in [[110.0, 62.0], [36.0, 56.0]]:
		var reach := DioramaLens.shadow_reach(view[0], view[1], 20.0)
		assert_gt(reach, DioramaLens.distance_at(view[0], view[1], 10.0), str(view))
		assert_lt(reach, DioramaLens.distance_at(view[0], view[1], 10.0) * 1.5, "not wasted")


func test_a_quality_cap_keeps_the_shadows_short() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.fov = 20.0
	camera.rotation_degrees = Vector3(-62.0, 30.0, 0.0)
	camera.global_position = Vector3(0.0, 110.0 * sin(deg_to_rad(62.0)), 0.0)
	var sun := DirectionalLight3D.new()
	autofree(sun)
	var lens := DioramaLens.new()
	lens.shadow_cap = 70.0
	lens.follow(camera, null, null, sun)
	assert_almost_eq(sun.directional_shadow_max_distance, 70.0, 1e-4, "the overview casts none")
	camera.global_position = Vector3(0.0, 36.0 * sin(deg_to_rad(62.0)), 0.0)
	lens.follow(camera, null, null, sun)
	assert_almost_eq(
		sun.directional_shadow_max_distance, DioramaLens.shadow_reach(36.0, 62.0, 20.0), 1e-3
	)


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
	var sun := main.get_node("Sun") as DirectionalLight3D
	var top := DioramaLens.distance_at(distance, rad_to_deg(asin(-forward.y)), camera.fov / 2.0)
	assert_gt(sun.directional_shadow_max_distance, top, "shadows reach the top of the screen")
	assert_gte(sun.directional_shadow_fade_start, 0.949)
	assert_gt(
		sun.directional_shadow_max_distance * sun.directional_shadow_fade_start,
		top,
		"and fade only past it, not from the middle"
	)
	var blur := DioramaLens.focus(distance, rad_to_deg(asin(-forward.y)), camera.fov)
	assert_almost_eq(attributes.dof_blur_far_distance, blur.x, 1e-2)
