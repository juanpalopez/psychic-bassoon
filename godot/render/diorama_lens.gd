## The tilt-shift and the depth haze of the diorama, fitted to where the camera looks: the play
## area stays sharp and clear, and the blur and the haze grow towards the top edge (the far
## side of the valley) at every zoom and pan (docs/art/STYLE.md, Atmosphere). The tilt-shift is
## this game's own: `assets-src/diorama_lookdev/post.py`'s depth blur would blur nothing at a
## 20 degree field of view.
##
## There is no near blur. Looking down through 20 degrees, the ground across the lower half of
## the screen spans only 2 to 5 m of depth, less than a Cardboard Golem or a tower on its block
## stands up towards the camera, so any near blur that softened the bottom edge of the ground
## would also blur a foe standing in the play area (a 2 m foe at 80% of the screen height).
##
## `depth_at`, `distance_at`, `focus`, `haze` and `haze_amount` are plain maths, tested;
## `follow` reads the camera and writes the result into the depth of field
## (`CameraAttributesPractical`) and the Environment's depth fog, only when the view moved.
class_name DioramaLens
extends RefCounted

## How far from the middle towards the top edge the ground stays sharp, as a share of the way.
const SHARP_SHARE := 0.8
## The share of the screen height, about its middle, that the haze leaves clear; above it the
## haze thickens to its full amount at `HAZE_FULL` times the distance of the screen's top edge.
const CLEAR_SHARE := 0.5
const HAZE_FULL := 1.25

var _key := Vector3(-1.0, -1.0, -1.0)


## The view depth (metres along the camera's axis) of the flat ground seen `angle_degrees`
## above the middle of the screen (negative is below), from a camera `distance` metres from
## the ground point in the middle, looking down at `pitch_degrees`. The depth of field uses it.
static func depth_at(distance: float, pitch_degrees: float, angle_degrees: float) -> float:
	return distance_at(distance, pitch_degrees, angle_degrees) * cos(deg_to_rad(angle_degrees))


## How far from the camera (metres along the ray) that ground point is. The fog uses it.
static func distance_at(distance: float, pitch_degrees: float, angle_degrees: float) -> float:
	var pitch := deg_to_rad(pitch_degrees)
	return distance * sin(pitch) / sin(pitch - deg_to_rad(angle_degrees))


## Where the far blur starts (`x`) and how far it ramps to full (`y`), for a vertical field of
## view `fov_degrees`: sharp up to `SHARP_SHARE` of the way from the middle to the top edge,
## full at the top edge (a value, so a pan allocates nothing).
static func focus(distance: float, pitch_degrees: float, fov_degrees: float) -> Vector2:
	var half := fov_degrees / 2.0
	var far := depth_at(distance, pitch_degrees, half * SHARP_SHARE)
	return Vector2(far, depth_at(distance, pitch_degrees, half) - far)


## Where the depth haze begins and where it reaches its full amount (`x` and `y`), as
## distances from the camera.
static func haze(distance: float, pitch_degrees: float, fov_degrees: float) -> Vector2:
	var half := fov_degrees / 2.0
	var begin := distance_at(distance, pitch_degrees, half * CLEAR_SHARE)
	return Vector2(begin, distance_at(distance, pitch_degrees, half) * HAZE_FULL)


## How much depth fog Godot draws at `at` metres from the camera (its FOG_MODE_DEPTH:
## smoothstep from begin to end, raised to the curve, times the density).
static func haze_amount(at: float, span: Vector2, curve: float, density: float) -> float:
	return pow(smoothstep(span.x, span.y, at), curve) * density


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
		attributes.dof_blur_far_distance = blur.x
		attributes.dof_blur_far_transition = blur.y
	if environment != null and environment.fog_mode == Environment.FOG_MODE_DEPTH:
		var span := haze(distance, pitch, camera.fov)
		environment.fog_depth_begin = span.x
		environment.fog_depth_end = span.y
