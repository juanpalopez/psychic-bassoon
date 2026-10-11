## The ring that shows how far a selected tower reaches.
extends GutTest


func test_it_is_hidden_until_shown() -> void:
	var ring := RangeRing.new()
	add_child_autofree(ring)
	assert_false(ring.visible)


func test_it_is_centred_on_the_point_and_as_wide_as_the_range() -> void:
	var ring := RangeRing.new()
	add_child_autofree(ring)
	ring.show_range(Vector3(2.0, 0.4, -1.0), 2.5)
	assert_true(ring.visible)
	assert_almost_eq(ring.position.x, 2.0, 1e-6)
	assert_almost_eq(ring.position.z, -1.0, 1e-6)
	assert_gt(ring.position.y, 0.4, "it floats a hair above the tile")
	assert_almost_eq(ring.radius(), 2.5, 1e-6)
	# a unit disc scaled by the range: the diameter is twice the radius
	assert_almost_eq(ring.scale.x, 2.5, 1e-6)
	assert_almost_eq(ring.scale.z, 2.5, 1e-6)


func test_it_can_be_hidden_again() -> void:
	var ring := RangeRing.new()
	add_child_autofree(ring)
	ring.show_range(Vector3.ZERO, 3.0)
	ring.hide_range()
	assert_false(ring.visible)
