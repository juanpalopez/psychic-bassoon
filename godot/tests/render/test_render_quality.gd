## The quality setting: a phone gets the phone default and a desktop everything, a command-line
## argument overrides either, and the phone default turns the costly passes off.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


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
		RenderQuality.choose(phone, PackedStringArray(["--quality=ultra"])),
		RenderQuality.Level.PHONE,
		"an unknown level is ignored"
	)


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
	RenderQuality.apply(RenderQuality.Level.PHONE, environment, sun)
	assert_false(environment.ssao_enabled, "no SSAO")
	assert_false(environment.ssil_enabled, "no SSIL")
	assert_eq(sun.light_angular_distance, 0.0, "no soft-shadow search")
	assert_gt(sun.shadow_blur, 1.0, "a wider cheap blur instead")
	assert_true(environment.glow_enabled, "glow stays for the magic")
	assert_true(environment.fog_enabled, "the haze stays")


func test_high_keeps_what_the_scene_set_up() -> void:
	var environment := _scene_environment().duplicate() as Environment
	var sun := DirectionalLight3D.new()
	autofree(sun)
	sun.light_angular_distance = 1.5
	RenderQuality.apply(RenderQuality.Level.HIGH, environment, sun)
	assert_true(environment.ssao_enabled)
	assert_true(environment.ssil_enabled)
	assert_eq(sun.light_angular_distance, 1.5)


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
