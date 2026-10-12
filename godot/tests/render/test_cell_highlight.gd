## The square (or block) laid over the selected socket.
extends GutTest


func _highlight() -> CellHighlight:
	var highlight := CellHighlight.new()
	add_child_autofree(highlight)
	return highlight


func test_it_is_hidden_until_shown() -> void:
	assert_false(_highlight().visible)


func test_a_cell_is_marked_where_the_cell_is() -> void:
	var highlight := _highlight()
	highlight.show_cell(Vector2i(4, 3), 0.3, Color.RED)
	var at := BoardSpace.cell_to_world(4, 3)
	assert_true(highlight.visible)
	assert_almost_eq(highlight.position.x, at.x, 1e-9)
	assert_almost_eq(highlight.position.z, at.z, 1e-9)
	assert_almost_eq(highlight.scale.x, 1.0, 1e-9)


func test_a_block_is_marked_over_all_its_cells() -> void:
	var highlight := _highlight()
	highlight.show_block(Vector2i(4, 3), 2, 0.3, Color.RED)
	var middle := BoardSpace.footprint_centre(Vector2i(4, 3), 2)
	assert_true(highlight.visible)
	assert_almost_eq(highlight.position.x, middle.x, 1e-9)
	assert_almost_eq(highlight.position.z, middle.z, 1e-9)
	assert_almost_eq(highlight.scale.x, 2.0, 1e-9)
	assert_almost_eq(highlight.scale.z, 2.0, 1e-9)
	assert_gt(highlight.position.y, 0.3)


func test_a_cell_after_a_block_is_one_cell_wide_again() -> void:
	var highlight := _highlight()
	highlight.show_block(Vector2i(4, 3), 2, 0.3, Color.RED)
	highlight.show_cell(Vector2i(1, 1), 0.3, Color.RED)
	assert_almost_eq(highlight.scale.x, 1.0, 1e-9)
