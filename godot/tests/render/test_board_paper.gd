## The papercraft pieces on the diorama: the spilled ink at each spawn, the pencil circles on
## the sockets, the placeholder scatter (only where nothing is played, the same for the same
## seed), and few draw calls for the whole board.
extends GutTest

const SEEDS: Array[int] = [1, 7920, 15839]


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


func _scatter(board: Board) -> PlaceholderScatter:
	return board.diorama.builder("Scatter") as PlaceholderScatter


func _road(board: Board) -> Dictionary:
	var road := {}
	for route in board.map.routes:
		for cell in route:
			road[cell] = true
	return road


func _distance(cell: Vector2i, cells: Dictionary) -> int:
	var best := 99
	for other in cells:
		var d: Vector2i = (other - cell).abs()
		best = mini(best, maxi(d.x, d.y))
	return best


func _blocked(board: Board) -> Dictionary:
	var blocked := {}
	for anchor in board.map.sockets:
		for dy in board.map.footprint:
			for dx in board.map.footprint:
				blocked[anchor + Vector2i(dx, dy)] = true
	var heart := board.map.heartstone
	for dy in heart.size.y:
		for dx in heart.size.x:
			blocked[heart.position + Vector2i(dx, dy)] = true
	return blocked


func test_scatter_keeps_off_the_road_the_sockets_the_heartstone_and_the_river() -> void:
	for map_seed in SEEDS:
		var board := _board(map_seed)
		var road := _road(board)
		var scatter := _scatter(board)
		for key in scatter.decor_cells:
			var keep: int = PlaceholderScatter.DECOR[key][1]
			for cell in scatter.decor_cells[key]:
				assert_false(road.has(cell), "%s on the road at %s" % [key, cell])
				assert_false(board.map.is_socket_cell(cell), "%s on a socket" % key)
				assert_false(board.map.heartstone.has_point(cell), "%s on the Heartstone" % key)
				assert_false(board.map.river.has(cell), "%s in the river" % key)
				assert_gte(_distance(cell, road), keep, "%s at %s, seed %d" % [key, cell, map_seed])


func test_scatter_keeps_clear_of_the_sockets_and_the_heartstone_by_its_reach() -> void:
	# the reach in cells is written out here, not read from PlaceholderScatter.DECOR
	var reach := {"Trees": 2, "RoundTrees": 2, "Shrubs": 2, "Grass": 1, "Flowers": 1}
	for map_seed in [1, 7, 7920, 15839]:
		var board := _board(map_seed)
		var blocked := _blocked(board)
		var scatter := _scatter(board)
		for key in scatter.decor_cells:
			for cell in scatter.decor_cells[key]:
				assert_gte(
					_distance(cell, blocked),
					reach[key],
					"%s at %s over a socket or the Heartstone, seed %d" % [key, cell, map_seed]
				)


func test_scatter_stands_on_the_terrace_of_its_cell() -> void:
	var board := _board(7920)
	var scatter := _scatter(board)
	for key in scatter.decor_spots:
		for i in scatter.decor_spots[key].size():
			var spot: Transform3D = scatter.decor_spots[key][i]
			var cell: Vector2i = scatter.decor_cells[key][i]
			assert_eq(BoardSpace.world_to_cell(spot.origin), cell, "%s stays in its cell" % key)
			assert_almost_eq(spot.origin.y, board.surface_height(cell), 1e-6, "%s %s" % [key, cell])


func test_the_same_seed_scatters_the_same_decor() -> void:
	assert_eq(_scatter(_board(42)).decor_cells, _scatter(_board(42)).decor_cells)


func test_every_seed_keeps_a_good_amount_of_scatter() -> void:
	for map_seed in [1, 7, 42, 7920, 15839]:
		var scatter := _scatter(_board(map_seed))
		var total := 0
		for key in scatter.decor_cells:
			total += scatter.decor_cells[key].size()
		assert_gte(total, 20, "seed %d is not left bare" % map_seed)


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
	# shadows keep to about a third of it
	for map_seed in SEEDS:
		var counts := {"drawn": 0, "shadows": 0}
		_surfaces(_board(map_seed), counts)
		gut.p(
			(
				"seed %d: %d surfaces, %d in the shadow map"
				% [map_seed, counts["drawn"], counts["shadows"]]
			)
		)
		assert_lte(counts["drawn"], 36, "seed %d: surfaces drawn" % map_seed)
		assert_lte(counts["shadows"], 20, "seed %d: surfaces in the shadow map" % map_seed)
