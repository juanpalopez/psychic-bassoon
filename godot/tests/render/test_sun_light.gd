## The sun keeps the same angle to the view when the camera is turned by its yaw.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")
## The sun's yaw in the scene before the camera was turned (degrees).
const SUN_YAW_BEFORE := -121.5
const SUN_PITCH := -42.0


## The angle (degrees) between where the light travels over the ground and where the
## camera looks over the ground.
func _light_to_view(light_yaw: float, camera_yaw: float) -> float:
	var light := Basis.from_euler(Vector3(deg_to_rad(SUN_PITCH), deg_to_rad(light_yaw), 0.0))
	var toward := light * Vector3.FORWARD
	var view := Basis(Vector3.UP, deg_to_rad(camera_yaw)) * Vector3.FORWARD
	return rad_to_deg(
		Vector2(toward.x, toward.z).normalized().angle_to(Vector2(view.x, view.z).normalized())
	)


func test_the_sun_is_turned_with_the_camera_so_the_light_reads_as_before() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	var sun := main.get_node("Sun") as DirectionalLight3D
	var before := absf(_light_to_view(SUN_YAW_BEFORE, 0.0))
	var now := absf(_light_to_view(sun.rotation_degrees.y, CameraRig.YAW_DEGREES))
	assert_almost_eq(now, before, 0.5, "the light-to-view angle is where it was")
	assert_gt(now, 45.0, "the light is not almost along the view")
	assert_almost_eq(sun.rotation_degrees.x, SUN_PITCH, 1e-4)
