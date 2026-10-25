## The start view does not depend on when the window size became known: a window that changes
## size after the run began gives the view a fresh start at the new size, until the player moves.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _spawn_share(main: Node, port: SubViewport) -> float:
	var spawn: Vector2i = main.game().map.path[0]
	var at: Vector2 = main.get("_rig").camera().unproject_position(
		BoardSpace.cell_to_world(spawn.x, spawn.y)
	)
	return at.x / float(port.size.x)


func _main_in(size: Vector2i) -> Array:
	var port := SubViewport.new()
	port.size = size
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	await get_tree().process_frame
	return [port, main]


func test_a_window_resize_after_the_start_keeps_the_spawn_a_quarter_across() -> void:
	var made := await _main_in(Vector2i(960, 720))
	var port: SubViewport = made[0]
	var main: Node = made[1]
	port.size = Vector2i(1560, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(_spawn_share(main, port), 0.25, 0.01)
	assert_gte(main.get("_rig").zoom, CameraRig.START_MIN_ZOOM)


func test_the_start_view_is_the_same_whichever_size_came_first() -> void:
	var first := await _main_in(Vector2i(1560, 720))
	var direct: CameraRig = first[1].get("_rig")
	var second := await _main_in(Vector2i(960, 720))
	second[0].size = Vector2i(1560, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var settled: CameraRig = second[1].get("_rig")
	assert_eq(settled.zoom, direct.zoom)
	assert_almost_eq(settled.pan.x, direct.pan.x, 1e-4)
	assert_almost_eq(settled.pan.y, direct.pan.y, 1e-4)


func test_a_camera_the_player_moved_is_left_where_it_is_on_resize() -> void:
	var made := await _main_in(Vector2i(960, 720))
	var port: SubViewport = made[0]
	var rig: CameraRig = made[1].get("_rig")
	rig.set_zoom(0.9)
	port.size = Vector2i(1560, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(rig.zoom, 0.9)
