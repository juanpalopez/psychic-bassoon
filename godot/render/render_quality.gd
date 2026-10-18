## How much of the diorama's light and post a device draws (docs/art/STYLE.md, Renderers):
## - HIGH (a desktop): everything `main.tscn` sets up;
## - PHONE (the phone default): no SSAO or SSIL (the Mobile renderer has neither; the painted
##   paper bakes contact shading instead), no soft-shadow search (PCSS) on the sun, and a
##   lighter, cheaper depth of field. Glow, fog and the grade stay, so the phone is softer and
##   simpler, never another style;
## - LOW (for a device that misses its frame budget even so): PHONE without the depth of
##   field, the glow and the soft shadow filter.
##
## The level comes from the platform through `from_platform`, the one place that reads it: a
## phone (`mobile`, `ios` or `android`) gets PHONE, anything else HIGH. `--quality=low`,
## `--quality=phone` or `--quality=high` after `--` on the command line overrides it.
class_name RenderQuality
extends RefCounted

enum Level { LOW, PHONE, HIGH }

const PHONE_FEATURES: Array[String] = ["mobile", "ios", "android"]
const ARG := "--quality="
const NAMES := {"low": Level.LOW, "phone": Level.PHONE, "high": Level.HIGH}
## The sun's shadow edge without PCSS: a wider blur of the cheap filter instead.
const CHEAP_SUN_BLUR := 2.0
## The share of the scene's depth-of-field blur a phone draws.
const PHONE_DOF_AMOUNT := 0.6
const DOF_QUALITY := {
	Level.LOW: RenderingServer.DOF_BLUR_QUALITY_VERY_LOW,
	Level.PHONE: RenderingServer.DOF_BLUR_QUALITY_LOW,
	Level.HIGH: RenderingServer.DOF_BLUR_QUALITY_MEDIUM,
}
const DOF_SHAPE := {
	Level.LOW: RenderingServer.DOF_BOKEH_BOX,
	Level.PHONE: RenderingServer.DOF_BOKEH_BOX,
	Level.HIGH: RenderingServer.DOF_BOKEH_CIRCLE,
}
const DOF_QUALITY_SETTING := "rendering/camera/depth_of_field/depth_of_field_bokeh_quality"
const DOF_SHAPE_SETTING := "rendering/camera/depth_of_field/depth_of_field_bokeh_shape"
const DOF_JITTER_SETTING := "rendering/camera/depth_of_field/depth_of_field_use_jitter"
const SHADOW_SETTINGS := "rendering/lights_and_shadows/directional_shadow/"
const SOFT_SHADOW_SETTING := SHADOW_SETTINGS + "soft_shadow_filter_quality"


## The level for a platform with these features and command-line user arguments.
static func choose(features: Array[String], args: PackedStringArray) -> Level:
	for arg in args:
		if arg.begins_with(ARG) and NAMES.has(arg.trim_prefix(ARG)):
			return NAMES[arg.trim_prefix(ARG)]
	for feature in PHONE_FEATURES:
		if feature in features:
			return Level.PHONE
	return Level.HIGH


## The phone features this platform has.
static func platform_features() -> Array[String]:
	var features: Array[String] = []
	for feature in PHONE_FEATURES:
		if OS.has_feature(feature):
			features.append(feature)
	return features


## The level for this device: the adapter that reads the platform.
static func from_platform() -> Level:
	return choose(platform_features(), OS.get_cmdline_user_args())


## Which of the costly passes a level draws.
static func passes(level: Level) -> Dictionary:
	return {
		"ssao": level == Level.HIGH,
		"ssil": level == Level.HIGH,
		"soft_sun": level == Level.HIGH,
		"soft_filter": level != Level.LOW,
		"glow": level != Level.LOW,
		"dof": level != Level.LOW,
	}


## Turns the costly passes off below HIGH; HIGH keeps what the scene set up.
static func apply(
	level: Level,
	environment: Environment,
	sun: DirectionalLight3D,
	attributes: CameraAttributesPractical
) -> void:
	var on := passes(level)
	environment.ssao_enabled = environment.ssao_enabled and on["ssao"]
	environment.ssil_enabled = environment.ssil_enabled and on["ssil"]
	environment.glow_enabled = environment.glow_enabled and on["glow"]
	if not on["soft_sun"]:
		sun.light_angular_distance = 0.0
		sun.shadow_blur = maxf(sun.shadow_blur, CHEAP_SUN_BLUR)
	if attributes != null:
		attributes.dof_blur_far_enabled = attributes.dof_blur_far_enabled and on["dof"]
		attributes.dof_blur_near_enabled = attributes.dof_blur_near_enabled and on["dof"]
		if level == Level.PHONE:
			attributes.dof_blur_amount *= PHONE_DOF_AMOUNT
	RenderingServer.camera_attributes_set_dof_blur_quality(DOF_QUALITY[level], level == Level.HIGH)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(DOF_SHAPE[level])
	if not on["soft_filter"]:
		RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_HARD
		)


## Puts the renderer's global depth-of-field and soft-shadow settings back to the project's.
static func reset_globals() -> void:
	RenderingServer.camera_attributes_set_dof_blur_quality(
		ProjectSettings.get_setting_with_override(DOF_QUALITY_SETTING),
		ProjectSettings.get_setting_with_override(DOF_JITTER_SETTING)
	)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(
		ProjectSettings.get_setting_with_override(DOF_SHAPE_SETTING)
	)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		ProjectSettings.get_setting_with_override(SOFT_SHADOW_SETTING)
	)
