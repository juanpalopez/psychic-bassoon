## The quality setting: a phone gets the phone default and a desktop everything, a command-line
## argument overrides either, the lower levels turn the costly passes off, and the game wires it
## in.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func after_each() -> void:
	# apply() sets the renderer's global depth of field and shadow filter
	RenderQuality.reset_globals()


## The game at `level`, after its _ready.
func _main_at(level: RenderQuality.Level) -> Node:
	var main := MAIN_SCENE.instantiate()
	main.render_quality = level
	add_child_autofree(main)
	return main


func _scene_environment() -> Environment:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	return (main.get_node("WorldEnvironment") as WorldEnvironment).environment


func test_a_phone_gets_the_phone_default() -> void:
	for feature in ["mobile", "ios", "android"]:
		var features: Array[String] = [feature]
		assert_eq(RenderQuality.choose(features, []), RenderQuality.Level.PHONE, feature)


func test_a_desktop_gets_everything() -> void:
	var features: Array[String] = ["pc", "macos"]
	assert_eq(RenderQuality.choose(features, []), RenderQuality.Level.HIGH)
	assert_eq(RenderQuality.choose([] as Array[String], []), RenderQuality.Level.HIGH)


func test_the_command_line_overrides_the_platform() -> void:
	var phone: Array[String] = ["ios"]
	var desktop: Array[String] = ["pc"]
	var high := PackedStringArray(["--stress=80", "--quality=high"])
	assert_eq(RenderQuality.choose(phone, high), RenderQuality.Level.HIGH)
	assert_eq(
		RenderQuality.choose(desktop, PackedStringArray(["--quality=phone"])),
		RenderQuality.Level.PHONE
	)
	assert_eq(
		RenderQuality.choose(phone, PackedStringArray(["--quality=low"])), RenderQuality.Level.LOW
	)
	assert_eq(
		RenderQuality.choose(phone, PackedStringArray(["--quality=ultra"])),
		RenderQuality.Level.PHONE,
		"an unknown level is ignored"
	)


func test_this_desktop_reads_as_high() -> void:
	# the suite runs on a desktop (or CI's Linux) with no --quality argument
	assert_eq(RenderQuality.platform_features(), [] as Array[String])
	assert_eq(RenderQuality.from_platform(), RenderQuality.Level.HIGH)


func test_the_phone_default_turns_the_costly_passes_off() -> void:
	var environment := Environment.new()
	environment.ssao_enabled = true
	environment.ssil_enabled = true
	environment.glow_enabled = true
	environment.fog_enabled = true
	var sun := DirectionalLight3D.new()
	autofree(sun)
	sun.light_angular_distance = 1.5
	sun.shadow_blur = 1.0
	sun.shadow_enabled = true
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_amount = 0.1
	RenderQuality.apply(RenderQuality.Level.PHONE, environment, sun, attributes)
	assert_false(environment.ssao_enabled, "no SSAO")
	assert_false(environment.ssil_enabled, "no SSIL")
	assert_eq(sun.light_angular_distance, 0.0, "no soft-shadow search")
	assert_gt(sun.shadow_blur, 1.0, "a wider cheap blur instead")
	assert_true(environment.glow_enabled, "glow stays for the magic")
	assert_true(environment.fog_enabled, "the haze stays")
	assert_true(sun.shadow_enabled, "the sun still casts")
	assert_true(attributes.dof_blur_far_enabled, "the tilt-shift stays")
	assert_lt(attributes.dof_blur_amount, 0.1, "but lighter")


func test_the_phone_blur_is_a_share_of_the_scene_blur_however_often_it_is_applied() -> void:
	var environment := Environment.new()
	var sun := DirectionalLight3D.new()
	autofree(sun)
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_amount = 0.1
	RenderQuality.apply(RenderQuality.Level.PHONE, environment, sun, attributes)
	RenderQuality.apply(RenderQuality.Level.PHONE, environment, sun, attributes)
	assert_almost_eq(attributes.dof_blur_amount, 0.1 * RenderQuality.PHONE_DOF_AMOUNT, 1e-6)
	RenderQuality.apply(RenderQuality.Level.HIGH, environment, sun, attributes)
	assert_almost_eq(attributes.dof_blur_amount, 0.1, 1e-6, "back to the scene's on HIGH")


func test_low_also_drops_the_tilt_shift_and_the_glow() -> void:
	var environment := Environment.new()
	environment.glow_enabled = true
	environment.fog_enabled = true
	var sun := DirectionalLight3D.new()
	autofree(sun)
	sun.light_angular_distance = 1.5
	sun.shadow_enabled = true
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_near_enabled = true
	RenderQuality.apply(RenderQuality.Level.LOW, environment, sun, attributes)
	assert_false(environment.glow_enabled)
	assert_false(attributes.dof_blur_far_enabled)
	assert_false(attributes.dof_blur_near_enabled)
	assert_eq(sun.light_angular_distance, 0.0)
	assert_false(sun.shadow_enabled, "no shadow pass at all")
	assert_true(environment.fog_enabled, "the haze is cheap and stays")


func test_high_keeps_what_the_scene_set_up() -> void:
	var environment := _scene_environment().duplicate() as Environment
	var sun := DirectionalLight3D.new()
	autofree(sun)
	sun.light_angular_distance = 1.5
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_amount = 0.1
	RenderQuality.apply(RenderQuality.Level.HIGH, environment, sun, attributes)
	assert_true(environment.ssao_enabled)
	assert_true(environment.ssil_enabled)
	assert_eq(sun.light_angular_distance, 1.5)
	assert_almost_eq(attributes.dof_blur_amount, 0.1, 1e-6)


func test_only_the_phone_caps_the_shadow_reach() -> void:
	assert_eq(RenderQuality.shadow_cap(RenderQuality.Level.HIGH), INF)
	assert_eq(RenderQuality.shadow_cap(RenderQuality.Level.PHONE), RenderQuality.PHONE_SHADOW_REACH)
	assert_lt(RenderQuality.PHONE_SHADOW_REACH, 110.0, "short of the 32 by 20 overview")
	assert_gt(RenderQuality.PHONE_SHADOW_REACH, 42.0, "past the top of the closest view")


func test_a_phone_game_keeps_its_shadows_within_the_phone_reach() -> void:
	var main := _main_at(RenderQuality.Level.PHONE)
	await wait_frames(2)
	var sun := main.get_node("Sun") as DirectionalLight3D
	assert_lte(sun.directional_shadow_max_distance, RenderQuality.PHONE_SHADOW_REACH)


func test_the_game_applies_the_phone_default_when_it_starts() -> void:
	var main := _main_at(RenderQuality.Level.PHONE)
	var environment := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_false(environment.ssao_enabled, "no SSAO after _ready")
	assert_eq((main.get_node("Sun") as DirectionalLight3D).light_angular_distance, 0.0)


func test_a_phone_game_leaves_the_next_game_its_own_scene() -> void:
	_main_at(RenderQuality.Level.PHONE)
	var main := _main_at(RenderQuality.Level.HIGH)
	var environment := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	assert_true(environment.ssao_enabled, "the Environment is not shared between games")
	assert_gt((main.get_node("Sun") as DirectionalLight3D).light_angular_distance, 0.0)


func test_the_scene_sets_up_the_diorama_light_and_post() -> void:
	var environment := _scene_environment()
	assert_eq(environment.tonemap_mode, Environment.TONE_MAPPER_ACES)
	assert_true(environment.ssao_enabled, "contact shading on desktop")
	assert_true(environment.glow_enabled, "the magic glows")
	assert_true(environment.fog_enabled)
	assert_eq(environment.fog_mode, Environment.FOG_MODE_DEPTH, "haze towards the far edge")
	assert_gt(environment.fog_height_density, 0.0, "height fog that settles low")
	assert_true(environment.adjustment_enabled, "the grade")
	assert_not_null(environment.adjustment_color_correction, "the warm/cool split")
