## The papercraft board: masking tape along every road, decor only where nothing is
## played, the same look for the same seed, and few extra draw calls.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


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


## Whether the drawn tape covers a point on the ground (its triangles seen from above).
func _taped(faces: PackedVector3Array, x: float, z: float) -> bool:
	var point := Vector2(x, z)
	for i in range(0, faces.size(), 3):
		var a := Vector2(faces[i].x, faces[i].z)
		var b := Vector2(faces[i + 1].x, faces[i + 1].z)
		var c := Vector2(faces[i + 2].x, faces[i + 2].z)
		if _inside(point, a, b, c):
			return true
	return false


## Whether `p` lies in the triangle, its edges included (a point on the diagonal shared by
## two triangles of a quad counts as covered).
func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var below := d1 < -1e-6 or d2 < -1e-6 or d3 < -1e-6
	var above := d1 > 1e-6 or d2 > 1e-6 or d3 > 1e-6
	return not (below and above)


## The road cells whose middle and four points 0.3 from it are not all under the tape.
func _bare_cells(faces: PackedVector3Array, routes: Array) -> Array[Vector2i]:
	var bare: Array[Vector2i] = []
	for route in routes:
		for cell in route:
			var at := BoardSpace.cell_to_world(cell.x, cell.y)
			for offset in [
				Vector2.ZERO, Vector2(0.3, 0), Vector2(-0.3, 0), Vector2(0, 0.3), Vector2(0, -0.3)
			]:
				if not _taped(faces, at.x + offset.x, at.z + offset.y):
					bare.append(cell)
					break
	return bare


func test_the_drawn_tape_covers_every_road_cell() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		var faces := (board.get_node("Tape") as MeshInstance3D).mesh.get_faces()
		assert_eq(_bare_cells(faces, board.map.routes), [] as Array[Vector2i], "seed %d" % map_seed)


func test_tape_covers_a_detour_that_leaves_the_road_and_joins_it_again() -> void:
	var checked := 0
	for map_seed in range(1, 40):
		var map := MapGen.generate(map_seed, RULES.GRID_COLS, RULES.GRID_ROWS, true)
		if map.routes.size() < 2 or map.routes[1][0] != map.routes[0][0]:
			continue
		var faces := TapeBuilder.build(map.routes, map_seed).get_faces()
		assert_eq(_bare_cells(faces, map.routes), [] as Array[Vector2i], "seed %d" % map_seed)
		checked += 1
		if checked == 3:
			break
	assert_gt(checked, 0, "found a map whose detour starts on the main road")


func test_the_tape_lies_on_the_mat_under_the_road_height() -> void:
	var box := (_board(1).get_node("Tape") as MeshInstance3D).mesh.get_aabb()
	assert_almost_eq(box.position.y, TapeBuilder.HEIGHT, 1e-6, "above the mat")
	assert_lt(box.end.y, Board.ROAD_HEIGHT, "under where foes walk")
	assert_lt(
		TapeBuilder.HEIGHT + TapeBuilder.STEP * float(TapeBuilder.LAYERS - 1),
		Board.ROAD_HEIGHT,
		"every layer under the road height"
	)


func test_decor_keeps_off_the_road_the_sockets_and_the_heartstone() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		var road := _road(board)
		for key in board.decor_cells:
			var keep: int = Board.DECOR[key][1]
			for cell in board.decor_cells[key]:
				assert_false(road.has(cell), "%s on the road at %s" % [key, cell])
				assert_eq(
					board.map.socket_anchor_at(cell), GameMap.NO_SOCKET, "%s on a socket" % key
				)
				assert_false(board.map.heartstone.has_point(cell), "%s on the Heartstone" % key)
				assert_gte(_distance(cell, road), keep, "%s at %s, seed %d" % [key, cell, map_seed])


func test_the_same_seed_scatters_the_same_decor() -> void:
	assert_eq(_board(42).decor_cells, _board(42).decor_cells)


func test_the_open_mat_is_not_left_bare() -> void:
	for map_seed in [1, 7920, 15839]:
		var board := _board(map_seed)
		var total := 0
		for key in board.decor_cells:
			total += board.decor_cells[key].size()
		assert_gt(total, 8, "seed %d" % map_seed)


func test_decor_is_drawn_with_few_draw_calls() -> void:
	var decor := _board(1).get_node("Decor")
	var surfaces := 0
	for child in decor.get_children():
		assert_true(child is MultiMeshInstance3D, str(child.name))
		surfaces += (child as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
	assert_lte(decor.get_child_count(), Board.DECOR.size() + Board.CLUTTER.size())
	assert_lt(surfaces, 32, "a few dozen draw calls at most")


func test_every_spawn_has_its_spilled_ink() -> void:
	for map_seed in [1, 7920]:
		var board := _board(map_seed)
		var starts := {}
		for route in board.map.routes:
			starts[route[0]] = true
		assert_eq(board.spawn_count, starts.size(), "seed %d" % map_seed)
		assert_false(board.spawn_marker.mesh is BoxMesh, "the ink, not the box")


func test_every_board_piece_wears_the_paper_look() -> void:
	var board := _board(7920)
	for node_name in ["Mat", "Lane", "Cardboard", "Paperboard", "SocketOverlays", "Desk"]:
		var mesh := (board.get_node(node_name) as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			assert_true(mesh.surface_get_material(i) is ShaderMaterial, "%s %d" % [node_name, i])


func test_paperboard_tiles_step_in_on_the_outside_of_their_block() -> void:
	var board: Board = null
	for map_seed in range(1, 60):
		board = _board(map_seed)
		if _level_2_cells(board).size() > 0:
			break
	var cells := _level_2_cells(board)
	assert_gt(cells.size(), 0, "a map with a level 2 socket")
	var multimesh := (board.get_node("Paperboard") as MultiMeshInstance3D).multimesh
	for i in cells.size():
		var tile := multimesh.get_instance_transform(i)
		var anchor := board.map.socket_anchor_at(cells[i])
		var middle := BoardSpace.footprint_centre(anchor, board.map.footprint)
		var stepped := tile.basis * Vector3(1.0, 0.0, 1.0)
		assert_gt(stepped.dot(tile.origin - middle), 0.0, str(cells[i]))


func _level_2_cells(board: Board) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in board.map.rows:
		for col in board.map.cols:
			var cell := Vector2i(col, row)
			if (
				board.map.socket_anchor_at(cell) != GameMap.NO_SOCKET
				and board.map.elevation_at(cell) == 2
			):
				cells.append(cell)
	return cells


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
	# the phone budget is under 120 draw calls a frame with 80 foes and every tower; the board,
	# its decor and their shadows keep to about a third of it
	for map_seed in [1, 7920, 15839]:
		var counts := {"drawn": 0, "shadows": 0}
		_surfaces(_board(map_seed), counts)
		assert_lte(counts["drawn"], 32, "seed %d: surfaces drawn" % map_seed)
		assert_lte(counts["shadows"], 12, "seed %d: surfaces in the shadow map" % map_seed)
