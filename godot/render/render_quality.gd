## How much of the diorama's light and post a device draws (docs/art/STYLE.md, Renderers):
## everything `main.tscn` sets up on a desktop, and on a phone the costly passes turned off:
## SSAO and SSIL (the Mobile renderer has neither; the painted paper bakes contact shading
## instead), the sun's soft shadow (PCSS), and the depth of field at its cheapest blur. Glow,
## fog and the grade stay on both, so the phone is softer and simpler, never another style.
##
## The level comes from the platform through `from_platform`, the one place that reads it: a
## phone (`mobile`, `ios` or `android`) gets PHONE, anything else HIGH. `--quality=phone` or
## `--quality=high` after `--` on the command line overrides it, to see either on a desktop.
class_name RenderQuality
extends RefCounted

enum Level { PHONE, HIGH }

const PHONE_FEATURES: Array[String] = ["mobile", "ios", "android"]
const ARG := "--quality="
const NAMES := {"phone": Level.PHONE, "high": Level.HIGH}
## The sun's shadow edge on a phone: no PCSS, a wider blur of the cheap filter instead.
const PHONE_SUN_BLUR := 2.0
const DOF_QUALITY := {
	Level.PHONE: RenderingServer.DOF_BLUR_QUALITY_LOW,
	Level.HIGH: RenderingServer.DOF_BLUR_QUALITY_MEDIUM,
}
const DOF_SHAPE := {
	Level.PHONE: RenderingServer.DOF_BOKEH_BOX,
	Level.HIGH: RenderingServer.DOF_BOKEH_CIRCLE,
}


## The level for a platform with these features and command-line user arguments.
static func choose(features: Array[String], args: PackedStringArray) -> Level:
	for arg in args:
		if arg.begins_with(ARG) and NAMES.has(arg.trim_prefix(ARG)):
			return NAMES[arg.trim_prefix(ARG)]
	for feature in PHONE_FEATURES:
		if feature in features:
			return Level.PHONE
	return Level.HIGH


## The level for this device: the adapter that reads the platform.
static func from_platform() -> Level:
	var features: Array[String] = []
	for feature in PHONE_FEATURES:
		if OS.has_feature(feature):
			features.append(feature)
	return choose(features, OS.get_cmdline_user_args())


## Which of the costly passes a level draws.
static func passes(level: Level) -> Dictionary:
	var high := level == Level.HIGH
	return {"ssao": high, "ssil": high, "soft_sun": high}


## Turns the costly passes off for PHONE; HIGH keeps what the scene set up.
static func apply(level: Level, environment: Environment, sun: DirectionalLight3D) -> void:
	var on := passes(level)
	environment.ssao_enabled = environment.ssao_enabled and on["ssao"]
	environment.ssil_enabled = environment.ssil_enabled and on["ssil"]
	if not on["soft_sun"]:
		sun.light_angular_distance = 0.0
		sun.shadow_blur = maxf(sun.shadow_blur, PHONE_SUN_BLUR)
	RenderingServer.camera_attributes_set_dof_blur_quality(DOF_QUALITY[level], level == Level.HIGH)
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(DOF_SHAPE[level])
