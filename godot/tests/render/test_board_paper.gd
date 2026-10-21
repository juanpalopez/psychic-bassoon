## The papercraft pieces on the diorama: the spilled ink at each spawn, the pencil circles on
## the sockets, the scatter (only where nothing is played, the same for the same seed), and few
## draw calls for the whole board.
extends GutTest

const SEEDS: Array[int] = [1, 7920, 15839]


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


func _scatter(board: Board) -> ScenerySlot:
	return board.diorama.builder("Scatter") as ScenerySlot


func _road(board: Board) -> Dictionary:
	var road := {}
	for route in board.map.routes:
		for cell in route:
			road[cell] = true
	return road


func test_scatter_keeps_off_the_road_the_sockets_the_heartstone_and_the_river() -> void:
	for map_seed in SEEDS:
		var board := _board(map_seed)
		var road := _road(board)
		for placement in _scatter(board).placements:
			var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
			var label := "%s at %s, seed %d" % [placement.kind, cell, map_seed]
			assert_false(road.has(cell), "on the road: " + label)
			assert_false(board.map.is_socket_cell(cell), "on a socket: " + label)
			assert_false(board.map.heartstone.has_point(cell), "on the Heartstone: " + label)
			assert_false(board.diorama.field.is_gorge(cell), "in the gorge: " + label)


func test_scatter_stands_on_the_ground_of_its_cell() -> void:
	var board := _board(7920)
	var top := Callable(board.diorama.field, "top_at")
	for placement in _scatter(board).placements:
		var spot := SceneryScatter.instance_transform(placement, top)
		var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
		assert_almost_eq(
			spot.origin.y, board.surface_height(cell), 1e-6, "%s %s" % [placement.kind, cell]
		)


func test_the_same_seed_scatters_the_same_props() -> void:
	var first := _scatter(_board(42)).placements
	var second := _scatter(_board(42)).placements
	assert_eq(first.size(), second.size())
	for i in mini(first.size(), second.size()):
		assert_eq(first[i].at, second[i].at)


func test_every_seed_keeps_a_good_amount_of_scatter() -> void:
	for map_seed in [1, 7, 42, 7920, 15839]:
		var on_board := 0
		var board := _board(map_seed)
		for placement in _scatter(board).placements:
			var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
			on_board += 1 if board.map.in_bounds(cell) else 0
		assert_gte(on_board, 20, "seed %d is not left bare" % map_seed)


func test_every_spawn_has_its_spilled_ink() -> void:
	for map_seed in [1, 7920]:
		var board := _board(map_seed)
		var starts := {}
		for route in board.map.routes:
			starts[route[0]] = true
		assert_eq(board.spawn_count, starts.size(), "seed %d" % map_seed)
		assert_false(board.spawn_marker.mesh is BoxMesh, "the ink, not the box")


func test_the_socket_circles_wear_the_paper_look() -> void:
	var board := _board(7920)
	var mesh := (board.get_node("SocketOverlays") as MultiMeshInstance3D).multimesh.mesh
	assert_false(mesh is BoxMesh, "the model, not the box")
	for i in mesh.get_surface_count():
		assert_true(mesh.surface_get_material(i) is ShaderMaterial, "surface %d" % i)


func test_the_camera_near_plane_is_not_the_engine_default() -> void:
	var rig := CameraRig.new()
	add_child_autofree(rig)
	assert_gte(rig.camera().near, 1.0)


## Every surface the board draws, and those that also draw into the shadow map.
func _surfaces(node: Node, counts: Dictionary) -> void:
	var mesh: Mesh = null
	if node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		mesh = multi.multimesh.mesh if multi.multimesh.instance_count > 0 else null
	elif node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	if mesh != null:
		counts["drawn"] += mesh.get_surface_count()
		if (
			(node as GeometryInstance3D).cast_shadow
			!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			counts["shadows"] += mesh.get_surface_count()
	for child in node.get_children():
		_surfaces(child, counts)


func test_the_whole_board_keeps_to_its_share_of_the_draw_calls() -> void:
	# the phone budget is under 120 draw calls a frame with 80 foes and every tower; the whole
	# diorama (every chunk, before the camera culls most of them up close), its markers and their
	# shadows keep to about a third of it; the coarse chunks out in the haze cast no shadow. The
	# scatter (#326) takes 18 of them (10 casting), in four chunks so that a close view culls
	# about half of it. The sectioned valley draws two or three more than the old maps (57 at most).
	for map_seed in SEEDS:
		var counts := {"drawn": 0, "shadows": 0}
		_surfaces(_board(map_seed), counts)
		gut.p(
			(
				"seed %d: %d surfaces, %d in the shadow map"
				% [map_seed, counts["drawn"], counts["shadows"]]
			)
		)
		assert_lte(counts["drawn"], 58, "seed %d: surfaces drawn" % map_seed)
		assert_lte(counts["shadows"], 24, "seed %d: surfaces in the shadow map" % map_seed)
