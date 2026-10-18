## The ground the camera shows and the pans that keep it over the board.
extends GutTest

const FOV := 20.0


func test_the_footprint_and_bounds_maths() -> void:
	var foot := Rect2(Vector2(-3.0, -2.0), Vector2(6.0, 5.0))
	var bounds := CameraRig.pan_bounds(Vector2(10.0, 8.0), foot)
	assert_eq(bounds.position, Vector2(-7.0, -6.0))
	assert_eq(bounds.end, Vector2(7.0, 5.0))
	# a view wider than the board has nothing to pan on that axis
	var wide := CameraRig.pan_bounds(Vector2(2.0, 8.0), foot)
	assert_eq(wide.position.x, 0.0)
	assert_eq(wide.end.x, 0.0)


func test_a_turned_footprint_is_the_box_around_the_turned_screen() -> void:
	var plain := CameraRig.footprint(20.0, 59.0, FOV, 16.0 / 9.0, 0.0)
	var turned := CameraRig.footprint(20.0, 59.0, FOV, 16.0 / 9.0, 40.0)
	# turning a wide, shallow screen makes its box deeper and narrower
	assert_gt(turned.size.y, plain.size.y)
	assert_lt(turned.size.x, plain.size.x * 1.2)
	# the screen is centred on the target at yaw 0
	assert_almost_eq(plain.position.x, -plain.end.x, 1e-6)
