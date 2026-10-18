## The tilt-shift and the depth haze of the diorama, fitted to where the camera looks: a band
## across the middle of the screen (the play area) stays sharp and clear, and the blur and the
## haze grow towards the top and bottom edges at every zoom and pan (docs/art/STYLE.md,
## Atmosphere; the values start from `assets-src/diorama_lookdev/post.py`).
##
## `depth_at`, `focus` and `haze` are plain maths, tested; `follow` reads the camera and writes
## the result into the depth of field (`CameraAttributesPractical`) and the Environment's depth
## fog, only when the view has changed.
class_name DioramaLens
extends RefCounted

## The share of the screen height, about its middle, that stays sharp.
const SHARP_SHARE := 0.6
## The share of the screen height, about its middle, that the haze leaves clear; above it
## the haze thickens to its full amount at `HAZE_FULL` times the depth of the screen's top edge.
const CLEAR_SHARE := 0.0
const HAZE_FULL := 1.25

var _key := Vector3(-1.0, -1.0, -1.0)


## The view depth (metres along the camera's axis) of the flat ground seen `angle_degrees`
## above the middle of the screen (negative is below), from a camera `distance` metres from
## the ground point in the middle, looking down at `pitch_degrees`.
static func depth_at(distance: float, pitch_degrees: float, angle_degrees: float) -> float:
	var pitch := deg_to_rad(pitch_degrees)
	var angle := deg_to_rad(angle_degrees)
	return distance * sin(pitch) / sin(pitch - angle) * cos(angle)


## Where the blur starts and how far it ramps to full, past and before the focus, for a
## vertical field of view `fov_degrees`: sharp in the middle `SHARP_SHARE` of the screen,
## full at its top and bottom edges. Keys: `far`, `far_transition`, `near`, `near_transition`.
static func focus(distance: float, pitch_degrees: float, fov_degrees: float) -> Dictionary:
	var half := fov_degrees / 2.0
	var far := depth_at(distance, pitch_degrees, half * SHARP_SHARE)
	var near := depth_at(distance, pitch_degrees, -half * SHARP_SHARE)
	return {
		"far": far,
		"far_transition": depth_at(distance, pitch_degrees, half) - far,
		"near": near,
		"near_transition": near - depth_at(distance, pitch_degrees, -half),
	}


## Where the depth haze begins and where it reaches its full amount (`x` and `y`).
static func haze(distance: float, pitch_degrees: float, fov_degrees: float) -> Vector2:
	var half := fov_degrees / 2.0
	var begin := depth_at(distance, pitch_degrees, half * CLEAR_SHARE)
	return Vector2(begin, depth_at(distance, pitch_degrees, half) * HAZE_FULL)


## Fits the depth of field and the haze to `camera`, which looks down at the ground (y = 0).
func follow(
	camera: Camera3D, environment: Environment, attributes: CameraAttributesPractical
) -> void:
	var forward := -camera.global_basis.z
	if forward.y >= -1e-4:
		return
	var distance := camera.global_position.y / -forward.y
	var pitch := rad_to_deg(asin(-forward.y))
	var key := Vector3(distance, pitch, camera.fov)
	if key.is_equal_approx(_key):
		return
	_key = key
	if attributes != null:
		var blur := focus(distance, pitch, camera.fov)
		attributes.dof_blur_far_distance = blur["far"]
		attributes.dof_blur_far_transition = blur["far_transition"]
		attributes.dof_blur_near_distance = blur["near"]
		attributes.dof_blur_near_transition = blur["near_transition"]
	if environment != null and environment.fog_mode == Environment.FOG_MODE_DEPTH:
		var span := haze(distance, pitch, camera.fov)
		environment.fog_depth_begin = span.x
		environment.fog_depth_end = span.y
