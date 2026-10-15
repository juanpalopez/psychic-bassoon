## A pulsing ring on every socket the intro asks the player to tap.
extends GutTest


func _glow() -> SocketGlow:
	var glow := SocketGlow.new()
	add_child_autofree(glow)
	return glow


func test_it_starts_hidden_with_no_rings() -> void:
	var glow := _glow()
	assert_false(glow.visible)
	assert_eq(glow.ring_count(), 0)


func test_it_puts_a_ring_over_the_middle_of_every_block_at_its_height() -> void:
	var glow := _glow()
	var anchors: Array[Vector2i] = [Vector2i(2, 3), Vector2i(8, 4)]
	glow.show_blocks(anchors, 2, func(cell: Vector2i) -> float: return 1.0 if cell.x == 8 else 0.0)
	assert_true(glow.visible)
	assert_eq(glow.ring_count(), 2)
	for i in 2:
		var middle := BoardSpace.footprint_centre(anchors[i], 2)
		var at := glow.ring_position(i)
		assert_almost_eq(at.x, middle.x, 1e-6)
		assert_almost_eq(at.z, middle.z, 1e-6)
	assert_gt(glow.ring_position(1).y, glow.ring_position(0).y)


func test_showing_again_replaces_the_rings_and_hiding_removes_them() -> void:
	var glow := _glow()
	var three: Array[Vector2i] = [Vector2i(1, 1), Vector2i(4, 4), Vector2i(7, 7)]
	glow.show_blocks(three, 2, func(_c: Vector2i) -> float: return 0.0)
	glow.show_blocks(
		[Vector2i(1, 1)] as Array[Vector2i], 2, func(_c: Vector2i) -> float: return 0.0
	)
	assert_eq(glow.ring_count(), 1)
	glow.hide_all()
	assert_false(glow.visible)
	assert_eq(glow.ring_count(), 0)


func test_the_ring_pulses_over_time() -> void:
	var glow := _glow()
	glow.show_blocks(
		[Vector2i(1, 1)] as Array[Vector2i], 2, func(_c: Vector2i) -> float: return 0.0
	)
	glow.advance(0.0)
	var a := glow.pulse()
	glow.advance(0.4)
	assert_ne(glow.pulse(), a)
	assert_between(glow.pulse(), 0.0, 1.0)
