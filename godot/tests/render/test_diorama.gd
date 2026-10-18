## The diorama terrain (#324): built from the map's terrain layer, at the sim's heights under
## every cell, in chunks, carrying on past the map with no edge in view, and within its budget.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const SEEDS: Array[int] = [1, 7920, 15839]
## Maps whose river meets the edges hard: seed 22's runs down column 1, beside the edge the
## main road leaves by; seed 1's bridge carries a road running down the board.
const RIVER_SEEDS: Array[int] = [1, 22]
## Points of a cell, as offsets from its centre, where nothing may stand above a guarded cell.
const INSIDE: Array[Vector2] = [
	Vector2(0, 0),
	Vector2(0.4, 0),
	Vector2(-0.4, 0),
	Vector2(0, 0.4),
	Vector2(0, -0.4),
	Vector2(0.4, 0.4),
	Vector2(-0.4, 0.4),
	Vector2(0.4, -0.4),
	Vector2(-0.4, -0.4),
]
## The owner's provisional frame budget (docs/lessons/2026-10-18-diorama-budget.md, measured on
## the iPhone in #97): terrain and road beds 40k triangles, scenery 32k.
const TERRAIN_TRIANGLES := 40000
const SCENERY_TRIANGLES := 32000
## Where along a shared edge the seam test compares the tops (never the middle, where a
## guarded outline crosses exactly).
## Every surface the diorama draws before culling: 12 near chunks, at most 12 coarse ones, the
## water's chunks, the road bed and five scatter meshes.
const SURFACES := 36
const ALONG: Array[float] = [0.07, 0.23, 0.41, 0.62, 0.79, 0.94]
## The screen shapes the camera frames for: a 16:9 screen, a tall phone, a 4:3 tablet.
const ASPECTS: Array[float] = [16.0 / 9.0, 19.5 / 9.0, 4.0 / 3.0]


func _board(map_seed: int) -> Board:
	var board := Board.new()
	board.map_seed = map_seed
	add_child_autofree(board)
	return board


## The top faces (facing up) of every mesh a builder drew, binned by the map cells their
## footprints overlap, so a height can be read under any point of the map.
func _tops(builder: DioramaBuilder, map: GameMap) -> Dictionary:
	var bins := {}
	for child in builder.get_children():
		if not child is MeshInstance3D:
			continue
		var mesh := (child as MeshInstance3D).mesh
		var faces := mesh.get_faces()
		for k in range(0, faces.size(), 3):
			var a := faces[k]
			var b := faces[k + 1]
			var c := faces[k + 2]
			if absf((b - a).cross(c - a).normalized().y) < 0.9:
				continue
			var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			var first := Vector2i(
				floori(low.x + float(map.cols) / 2.0), floori(low.y + float(map.rows) / 2.0)
			)
			var last := Vector2i(
				floori(high.x + float(map.cols) / 2.0), floori(high.y + float(map.rows) / 2.0)
			)
			if last.x < 0 or last.y < 0 or first.x >= map.cols or first.y >= map.rows:
				continue
			for y in range(maxi(first.y, 0), mini(last.y, map.rows - 1) + 1):
				for x in range(maxi(first.x, 0), mini(last.x, map.cols - 1) + 1):
					var key := Vector2i(x, y)
					if not bins.has(key):
						bins[key] = []
					bins[key].append([a, b, c])
	return bins


## The highest top at a world point (x, z) among the binned faces, or -INF where there is none.
func _height_at(bins: Dictionary, map: GameMap, x: float, z: float) -> float:
	var cell := Vector2i(floori(x + float(map.cols) / 2.0), floori(z + float(map.rows) / 2.0))
	var best := -INF
	for face in bins.get(cell, []):
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var p := Vector2(x, z)
		var v0 := Vector2(c.x - a.x, c.z - a.z)
		var v1 := Vector2(b.x - a.x, b.z - a.z)
		var v2 := p - Vector2(a.x, a.z)
		var den := v0.cross(v1)
		if absf(den) < 1e-12:
			continue
		var u := v2.cross(v1) / den
		var v := v0.cross(v2) / den
		if u < -1e-5 or v < -1e-5 or u + v > 1.0 + 1e-5:
			continue
		best = maxf(best, a.y + u * (c.y - a.y) + v * (b.y - a.y))
	return best


func test_the_field_takes_the_maps_terraces_and_carves_the_river() -> void:
	for map_seed in SEEDS:
		var map := MapGen.generate(map_seed)
		var field := TerrainField.from_map(map)
		for row in map.rows:
			for col in map.cols:
				var cell := Vector2i(col, row)
				if map.river.has(cell):
					assert_true(field.is_gorge(cell), "river %s" % cell)
				elif map.heartstone.has_point(cell):
					assert_eq(field.level_at(cell), 0, "the Heartstone stands on the floor")
				else:
					assert_eq(
						field.level_at(cell), map.height_at(cell), "seed %d %s" % [map_seed, cell]
					)


func test_without_the_games_routes_the_field_makes_them_from_the_map() -> void:
	var map := MapGen.generate(1)
	var field := TerrainField.from_map(map)
	assert_eq(field.routes.size(), map.routes.size())
	var game := Game.create(1)
	for i in field.routes.size():
		assert_eq(field.routes[i].xs, game.routes[i].xs, "route %d" % i)
		assert_eq(field.routes[i].ys, game.routes[i].ys, "route %d" % i)


func test_the_world_carries_on_at_least_30_cells_past_every_edge() -> void:
	var map := MapGen.generate(1)
	var field := TerrainField.from_map(map)
	assert_gte(TerrainField.MARGIN, 30)
	assert_true(field.has_cell(Vector2i(-30, -30)))
	assert_true(field.has_cell(Vector2i(map.cols + 29, map.rows + 29)))
	var rect := field.world_rect()
	var half := BoardSpace.size() / 2.0
	for k in 2:
		assert_lte(rect.position[k], -half[k] - 30.0)
		assert_gte(rect.end[k], half[k] + 30.0)


func test_the_country_past_the_map_rises_into_hills_and_keeps_the_roads_and_river() -> void:
	var map := MapGen.generate(7920)
	var field := TerrainField.from_map(map)
	var high := 0
	for y in range(field.origin.y, field.origin.y + 8):
		for x in range(field.origin.x, field.origin.x + field.size.x):
			high = maxi(high, field.level_at(Vector2i(x, y)))
	assert_gte(high, RULES.TERRAIN_LEVELS, "the far side climbs past the map's top terrace")
	assert_gt(field.leads.size(), 0, "a road leaves the map")
	for lead in field.leads:
		for cell in lead:
			assert_eq(field.level_at(cell), 0, "a road carries on along the floor")
	if not map.river.is_empty():
		assert_lt(field.river[0].y, -TerrainField.MARGIN + 2, "the river comes from the far edge")
		assert_gt(field.river[field.river.size() - 1].y, map.rows + TerrainField.MARGIN - 3)
		for cell in field.river:
			if not map.in_bounds(cell) and field.guard_at(cell) == TerrainField.GUARD_NONE:
				assert_true(field.is_gorge(cell), str(cell))


func test_the_same_seed_gives_the_same_terrain_and_the_map_is_left_alone() -> void:
	var map := MapGen.generate(42)
	var heights_before := map.heights.duplicate(true)
	var a := TerrainField.from_map(map)
	var b := TerrainField.from_map(MapGen.generate(42))
	assert_eq(a.levels, b.levels)
	assert_eq(map.heights, heights_before, "the field never writes to the map")
	var first := _board(42)
	var second := _board(42)
	var one := (first.diorama.builder("Terraces").get_child(0) as MeshInstance3D).mesh
	var two := (second.diorama.builder("Terraces").get_child(0) as MeshInstance3D).mesh
	assert_eq(one.get_faces(), two.get_faces())


func test_the_ground_drawn_under_each_cell_is_the_height_the_views_use() -> void:
	for map_seed in SEEDS + [22]:
		var board := _board(map_seed)
		var map := board.map
		var terraces := _tops(board.diorama.builder("Terraces"), map)
		var water := _tops(board.diorama.builder("Water"), map)
		var road := _tops(board.diorama.builder("RoadBeds"), map)
		for row in map.rows:
			for col in map.cols:
				var cell := Vector2i(col, row)
				var at := BoardSpace.cell_to_world(col, row)
				var surface := board.surface_height(cell)
				var label := "seed %d %s" % [map_seed, cell]
				if map.tiles[row][col] == GameMap.Tile.ROAD:
					assert_almost_eq(surface, Board.ROAD_HEIGHT, 1e-9, label)
					var bed := _height_at(road, map, at.x, at.z)
					assert_almost_eq(bed, surface, 0.01, "the road bed is under the foes " + label)
					if not map.river.has(cell):
						assert_almost_eq(_height_at(terraces, map, at.x, at.z), 0.0, 1e-5, label)
				elif map.river.has(cell):
					assert_almost_eq(surface, TerrainField.WATER_HEIGHT, 1e-9, label)
					assert_almost_eq(_height_at(water, map, at.x, at.z), surface, 1e-5, label)
				else:
					var top := _height_at(terraces, map, at.x, at.z)
					assert_almost_eq(top, surface, 1e-5, label)
					# the Heartstone's block is levelled with the end of the road
					var level := 0 if map.heartstone.has_point(cell) else map.height_at(cell)
					assert_almost_eq(surface, float(level) * Board.TERRACE_STEP, 1e-6, label)


func test_nothing_stands_over_a_socket_or_the_road() -> void:
	for map_seed in SEEDS:
		var board := _board(map_seed)
		var map := board.map
		var terraces := _tops(board.diorama.builder("Terraces"), map)
		for row in map.rows:
			for col in map.cols:
				var cell := Vector2i(col, row)
				var socket := map.is_socket_cell(cell)
				var road := map.tiles[row][col] == GameMap.Tile.ROAD and not map.river.has(cell)
				if not socket and not road:
					continue
				var level := TerrainField.level_height(board.diorama.field.level_at(cell))
				var at := BoardSpace.cell_to_world(col, row)
				for offset in INSIDE:
					var top := _height_at(terraces, map, at.x + offset.x, at.z + offset.y)
					assert_almost_eq(top, level, 1e-5, "seed %d %s %s" % [map_seed, cell, offset])


func test_a_socket_block_is_flat_on_its_elevation_level() -> void:
	var board := _board(7920)
	var seen := {}
	for anchor in board.map.sockets:
		var level := board.map.elevation_at(anchor)
		seen[level] = true
		for dy in board.map.footprint:
			for dx in board.map.footprint:
				var cell := anchor + Vector2i(dx, dy)
				assert_almost_eq(
					board.surface_height(cell), float(level) * Board.TERRACE_STEP, 1e-9, str(cell)
				)
	assert_gt(seen.size(), 1, "sockets on more than one level")


func test_the_terraces_are_built_in_small_chunks_on_the_map_and_coarse_ones_far_out() -> void:
	var board := _board(1)
	var terraces := board.diorama.builder("Terraces") as TerraceBuilder
	var size := Vector2i(board.map.cols, board.map.rows)
	var near := TerraceBuilder.near_rect(size)
	var near_count := 0
	var material: Material = null
	for child in terraces.get_children():
		var chunk := child as MeshInstance3D
		var box := chunk.get_aabb()
		if str(chunk.name).begins_with("Chunk_"):
			near_count += 1
			var key := str(chunk.name).split("_")
			var first := Vector2i(int(key[1]), int(key[2])) * TerraceBuilder.CHUNK_CELLS
			# a square runs from its first cell's centre to the next one's, a lean at most 0.1 out
			var low := board.diorama.field.cell_centre(first)
			assert_gte(box.position.x, low.x - 0.1, str(chunk.name))
			assert_gte(box.position.z, low.z - 0.1, str(chunk.name))
			assert_lte(box.end.x, low.x + float(TerraceBuilder.CHUNK_CELLS) + 0.1, str(chunk.name))
			assert_lte(box.end.z, low.z + float(TerraceBuilder.CHUNK_CELLS) + 0.1, str(chunk.name))
		else:
			assert_true(str(chunk.name).begins_with("Far_"), str(chunk.name))
		if material == null:
			material = chunk.material_override
		assert_eq(chunk.material_override, material, "one shared material")
	assert_eq(material, board.diorama.ground_material)
	assert_eq(near_count, near.size.x * near.size.y / (TerraceBuilder.CHUNK_CELLS ** 2))
	assert_lte(terraces.chunk_count - near_count, 12, "a few coarse chunks round them")
	assert_true(near.encloses(Rect2i(Vector2i(-12, -12), size + Vector2i(24, 24))))


## The world points of a mesh's corners that lie on the line x = `x` (or z = `x` with `across`
## false), from its wall faces, and the top heights it draws along that line.
func _on_line(bucket: MeshBucket, x: float, across: bool) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for k in bucket.vertices.size():
		if absf(bucket.normals[k].y) > 0.5:
			continue
		var at := bucket.vertices[k]
		var off := (at.x if across else at.z) - x
		if absf(off) < 0.05:
			found.append(at)
	return found


func _top_on(bucket: MeshBucket, point: Vector2) -> float:
	var best := -INF
	for k in range(0, bucket.vertices.size(), 3):
		if bucket.normals[k].y < 0.9:
			continue
		var a := bucket.vertices[k]
		var b := bucket.vertices[k + 1]
		var c := bucket.vertices[k + 2]
		var v0 := Vector2(c.x - a.x, c.z - a.z)
		var v1 := Vector2(b.x - a.x, b.z - a.z)
		var v2 := point - Vector2(a.x, a.z)
		var den := v0.cross(v1)
		if absf(den) < 1e-12:
			continue
		var u := v2.cross(v1) / den
		var v := v0.cross(v2) / den
		if u >= -1e-6 and v >= -1e-6 and u + v <= 1.0 + 1e-6:
			best = maxf(best, a.y)
	return best


func test_squares_meet_their_neighbours_with_no_seam() -> void:
	# every square is meshed on its own, as the builder does, and compared with the next one
	# across and in depth along their shared edge: the same top heights, and wall ends that
	# stand exactly on the edge at one point with the same height on both sides
	for map_seed in [1, 22, 7920, 4242]:
		var map := MapGen.generate(map_seed)
		var field := TerrainField.from_map(map)
		var builder := TerraceBuilder.new()
		builder.prepare(field)
		var first := Vector2i(-12, -12) - field.origin
		var last := Vector2i(map.cols + 12, map.rows + 12) - field.origin
		var squares := {}
		for j in range(first.y, last.y + 1):
			for i in range(first.x, last.x + 1):
				squares[Vector2i(i, j)] = builder.square(i, j)
		var seams := 0
		for at in squares:
			var here: MeshBucket = squares[at]
			var corner := field.cell_centre(field.origin + at)
			for across in [true, false]:
				var next: Vector2i = at + (Vector2i.RIGHT if across else Vector2i.DOWN)
				if not squares.has(next):
					continue
				var there: MeshBucket = squares[next]
				var line := (corner.x + 1.0) if across else (corner.z + 1.0)
				for t in ALONG:
					var point := (
						Vector2(line, corner.z + t) if across else Vector2(corner.x + t, line)
					)
					var mine := _top_on(here, point)
					var theirs := _top_on(there, point)
					if not is_equal_approx(mine, theirs):
						seams += 1
						assert_almost_eq(
							mine, theirs, 1e-5, "seed %d top at %s" % [map_seed, point]
						)
				var ends_here := _on_line(here, line, across)
				var ends_there := _on_line(there, line, across)
				assert_eq(
					ends_here.is_empty(), ends_there.is_empty(), "seed %d %s" % [map_seed, at]
				)
				if ends_here.is_empty() or ends_there.is_empty():
					continue
				var spot := ends_here[0]
				var heights := Vector2(INF, -INF)
				var other := Vector2(INF, -INF)
				for end in ends_here:
					var off := Vector2(end.x - spot.x, end.z - spot.z).length()
					assert_almost_eq(off, 0.0, 1e-5, "a wall end off its edge, seed %d" % map_seed)
					assert_almost_eq(end.x if across else end.z, line, 1e-5, "on the edge")
					heights = Vector2(minf(heights.x, end.y), maxf(heights.y, end.y))
				for end in ends_there:
					var off := Vector2(end.x - spot.x, end.z - spot.z).length()
					assert_almost_eq(off, 0.0, 1e-5, "the two walls end apart, seed %d" % map_seed)
					other = Vector2(minf(other.x, end.y), maxf(other.y, end.y))
				assert_almost_eq(heights.x, other.x, 1e-5, "wall feet, seed %d %s" % [map_seed, at])
				assert_almost_eq(heights.y, other.y, 1e-5, "wall tops, seed %d %s" % [map_seed, at])
		assert_eq(seams, 0, "seed %d" % map_seed)
		builder.free()


func test_the_outlines_nest_one_level_inside_the_one_below() -> void:
	var map := MapGen.generate(7920)
	var field := TerrainField.from_map(map)
	var builder := TerraceBuilder.new()
	builder.prepare(field)
	var checked := 0
	for j in field.size.y - 1:
		for i in field.size.x - 1:
			var values := builder.middle_values(i, j)
			for k in range(1, values.size()):
				assert_lte(values[k], values[k - 1], "square %d %d" % [i, j])
				checked += 1
	assert_gt(checked, 1000)
	builder.free()


func test_every_face_winds_toward_its_normal() -> void:
	# Godot draws a clockwise triangle as its front face: the corners' right-handed normal
	# points away from the stored normal; a face wound the other way is culled from above
	var board := _board(1)
	for slot in ["Terraces", "Water", "RoadBeds"]:
		var backwards := 0
		var total := 0
		for child in board.diorama.builder(slot).get_children():
			var arrays := ((child as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in range(0, vertices.size(), 3):
				var turn := (vertices[k + 1] - vertices[k]).cross(vertices[k + 2] - vertices[k])
				total += 1
				if turn.dot(normals[k]) >= 0.0:
					backwards += 1
		assert_gt(total, 0, slot)
		assert_eq(backwards, 0, "%s faces wound away from their normal" % slot)


func test_every_cliff_faces_the_lower_ground() -> void:
	for map_seed in SEEDS:
		var board := _board(map_seed)
		var map := board.map
		var tops := _tops(board.diorama.builder("Terraces"), map)
		var half := Vector2(map.cols, map.rows) / 2.0
		var checked := 0
		var wrong := 0
		for child in board.diorama.builder("Terraces").get_children():
			var arrays := ((child as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for k in range(0, vertices.size(), 3):
				var normal := normals[k]
				if absf(normal.y) > 0.5:
					continue
				var high := maxf(vertices[k].y, maxf(vertices[k + 1].y, vertices[k + 2].y))
				var middle := (vertices[k] + vertices[k + 1] + vertices[k + 2]) / 3.0
				if absf(middle.x) > half.x - 0.5 or absf(middle.z) > half.y - 0.5:
					continue
				# a wall leans at most 0.085 m out of line, so 0.1 either side of its middle is
				# off the face: the ground behind it is its top, the ground in front lower
				var out := Vector2(normal.x, normal.z).normalized() * 0.1
				var behind := _height_at(tops, map, middle.x - out.x, middle.z - out.y)
				var ahead := _height_at(tops, map, middle.x + out.x, middle.z + out.y)
				checked += 1
				if behind < high - 0.01 or ahead > high - 0.05:
					wrong += 1
		gut.p("seed %d: %d of %d cliff faces not facing down" % [map_seed, wrong, checked])
		assert_gt(checked, 2000)
		assert_eq(wrong, 0, "seed %d" % map_seed)


func test_the_cliffs_have_walls_and_a_soil_lip() -> void:
	var board := _board(1)
	var walls := 0
	var soil := 0
	for child in board.diorama.builder("Terraces").get_children():
		var arrays := ((child as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in normals.size():
			if absf(normals[k].y) < 0.5:
				walls += 1
				var want := TerrainPalette.SOIL.srgb_to_linear()
				var got := colours[k]
				# vertex colours are stored at 8 bits a channel
				if absf(got.r - want.r) + absf(got.g - want.g) + absf(got.b - want.b) < 0.02:
					soil += 1
	assert_gt(walls, 1000)
	assert_gt(soil, 100)


func test_a_bridge_over_the_river_has_its_gorge_and_its_deck_either_way_round() -> void:
	for map_seed in RIVER_SEEDS:
		var board := _board(map_seed)
		var field := board.diorama.field
		assert_gt(board.map.bridges.size(), 0, "seed %d has a bridge" % map_seed)
		for bridge in board.map.bridges:
			assert_true(field.is_gorge(bridge.cell), "the gorge runs under the bridge")
			assert_eq(field.guard_at(bridge.cell), TerrainField.GUARD_ROAD)
			assert_almost_eq(board.surface_height(bridge.cell), Board.ROAD_HEIGHT, 1e-9)
			# the banks the road reaches the bridge from stay on the floor
			var along := Vector2i.RIGHT if bridge.horizontal else Vector2i.DOWN
			for side in [along, -along]:
				assert_eq(field.level_at(bridge.cell + side), 0, "seed %d bank" % map_seed)
		assert_true(field.river.size() > board.map.river.size(), "the river runs on past the map")


func test_the_river_has_water_and_every_road_a_bed() -> void:
	var board := _board(7920)
	assert_false(board.map.river.is_empty(), "this seed has a river")
	assert_gt(board.diorama.builder("Water").get_child_count(), 0)
	assert_eq(board.diorama.builder("RoadBeds").get_child_count(), 1)


## The camera's real zoom, pitch, footprint and pan range (#339: the map plus its scenery margin).
func test_no_edge_of_the_world_is_in_view_from_any_camera_position() -> void:
	var board := _board(1)
	var rect := board.diorama.field.world_rect().grow(-2.0)
	var rig := CameraRig.new()
	rig.canvas_height = 720.0
	add_child_autofree(rig)
	for aspect in ASPECTS:
		rig.frame(aspect)
		for step in 11:
			rig.set_zoom(float(step) / 10.0)
			var range := rig.pan_range()
			var distance: float = rig._distance()
			var foot := CameraRig.footprint(
				distance,
				CameraRig.pitch_for(rig.zoom),
				rig.fov_degrees,
				aspect,
				CameraRig.YAW_DEGREES
			)
			# overscroll is rubber-banded: a drag past the limit gets only `RUBBER` of it through
			var slack := Vector2.ONE * 3.0 * CameraRig.RUBBER
			var pans: Array[Vector2] = [
				range.position - slack,
				range.end + slack,
				Vector2(range.position.x, range.end.y) + Vector2(-slack.x, slack.y),
				Vector2(range.end.x, range.position.y) + Vector2(slack.x, -slack.y),
			]
			for corner in pans:
				var seen := Rect2(foot.position + corner, foot.size)
				assert_true(
					rect.encloses(seen),
					"aspect %.2f zoom %.1f sees %s past %s" % [aspect, rig.zoom, seen, rect]
				)


func test_the_haze_is_whole_before_the_edge_of_the_world() -> void:
	# the uniform's default, read from the include (the headless renderer compiles no shader)
	var code := FileAccess.get_file_as_string("res://render/paper/haze.gdshaderinc")
	var found := RegEx.create_from_string("uniform float haze_to = ([0-9.]+);").search(code)
	assert_not_null(found, "haze_to has a default")
	assert_lt(float(found.get_string(1)), float(TerrainField.MARGIN) - 2.0)
	var scene := FileAccess.get_file_as_string("res://main.tscn")
	var sky := RegEx.create_from_string("background_color = Color\\(([0-9., ]+)\\)").search(scene)
	var background := sky.get_string(1).split(",")
	var haze := RegEx.create_from_string("haze_colour : source_color = vec3\\(([0-9., ]+)\\)")
	var rgb := haze.search(code).get_string(1).split(",")
	for k in 3:
		assert_almost_eq(float(background[k]), float(rgb[k]), 0.002, "the haze is the background")


func test_the_diorama_keeps_to_its_triangle_and_draw_call_budget() -> void:
	for map_seed in SEEDS:
		var board := _board(map_seed)
		var diorama := board.diorama
		var terraces := diorama.builder("Terraces")
		(
			gut
			. p(
				(
					(
						"seed %d: terraces %d triangles in %d chunks, water %d, road beds %d, scatter %d;"
						+ " %d triangles and %d surfaces in all"
					)
					% [
						map_seed,
						terraces.triangles,
						terraces.surfaces,
						diorama.builder("Water").triangles,
						diorama.builder("RoadBeds").triangles,
						diorama.builder("Scatter").triangles,
						diorama.triangle_count(),
						diorama.surface_count(),
					]
				)
			)
		)
		var ground: int = (
			terraces.triangles
			+ diorama.builder("Water").triangles
			+ diorama.builder("RoadBeds").triangles
		)
		assert_lte(ground, TERRAIN_TRIANGLES, "seed %d: terrain and road beds" % map_seed)
		assert_lte(diorama.builder("Scatter").triangles, SCENERY_TRIANGLES, "seed %d" % map_seed)
		assert_lte(diorama.surface_count(), SURFACES, "seed %d: surfaces" % map_seed)


func test_a_builder_plugs_into_its_slot_and_builds_from_the_field() -> void:
	var board := _board(1)
	var custom := _CountingBuilder.new()
	board.diorama.use_builder("Scatter", custom)
	assert_eq(custom.built, 1, "built at once from the current field")
	assert_eq(custom.seen, board.diorama.field)
	assert_eq(board.diorama.builder("Scatter"), custom)
	board.map_seed = 7920
	assert_eq(custom.built, 2, "and again with every rebuild")
	assert_eq(custom.seen.map.seed, 7920)
	var names: Array[String] = []
	for child in board.diorama.get_children():
		names.append(str(child.name))
	assert_eq(names, Diorama.SLOTS)


class _CountingBuilder:
	extends DioramaBuilder
	var built := 0
	var seen: TerrainField

	func build(field: TerrainField) -> void:
		clear()
		built += 1
		seen = field
