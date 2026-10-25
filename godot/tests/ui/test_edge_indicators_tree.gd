## The edge arrows in a real node tree: under the HUD's CanvasLayer the control must take the
## canvas's size, or no arrow is ever drawn (the pure functions passed while it ended 0 by 0).
extends GutTest

const CANVAS := Vector2i(1280, 720)


func _hud_with_arrows() -> EdgeIndicators:
	var port := SubViewport.new()
	port.size = CANVAS
	add_child_autofree(port)
	var layer := CanvasLayer.new()
	port.add_child(layer)
	var arrows := EdgeIndicators.new()
	layer.add_child(arrows)
	return arrows


func test_the_arrows_take_the_size_of_the_canvas_under_a_canvas_layer() -> void:
	var arrows := _hud_with_arrows()
	await get_tree().process_frame
	assert_eq(arrows.size, Vector2(CANVAS))
	assert_eq(arrows.position, Vector2.ZERO)


func test_a_hero_off_screen_gets_an_arrow_spot_in_the_room_the_hud_leaves() -> void:
	var arrows := _hud_with_arrows()
	await get_tree().process_frame
	var room := arrows.room(arrows.size)
	assert_gt(room.size.x, 0.0)
	var spot: Variant = EdgeArrows.spot(Vector2(-500.0, 360.0), false, arrows.size, room)
	assert_not_null(spot)
	assert_true(room.grow(1.0).has_point(spot.position))
