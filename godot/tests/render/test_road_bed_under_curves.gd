## The diorama's road bed (#325) is laid along the curved routes the valley board's foes walk
## (#321), so every point a foe walks past is drawn on the bed, or on a bridge's planks over the
## river (the bed stops at the gorge).
extends GutTest

## Sub-points checked on each segment between two route points.
const SUBSTEPS := 4
const EPSILON := 1e-6


func test_every_point_of_the_curved_routes_lies_on_the_road_bed() -> void:
	for map_seed in [1, 2, 3, 42, 7920]:
		var game := Game.create_on_strip_valley(map_seed)
		var board := Board.new()
		board.build_on_ready = false
		add_child_autofree(board)
		board.show_map(game.map, game.routes)
		var bed := board.diorama.builder("RoadBeds").get_node("RoadBed") as MeshInstance3D
		var mesh := bed.mesh as ArrayMesh
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var buckets := _buckets(vertices)
		var off := 0
		var checked := 0
		for route in game.routes:
			# from the first cell on (the spawn approach before it runs off the board)
			for p in range(2, route.xs.size()):
				for s in SUBSTEPS:
					var t := float(s) / float(SUBSTEPS)
					var x := route.xs[p - 1] + (route.xs[p] - route.xs[p - 1]) * t
					var y := route.ys[p - 1] + (route.ys[p] - route.ys[p - 1]) * t
					var at := BoardSpace.point_to_world(x, y)
					checked += 1
					if _on_a_bridge(game.map, Vector2(x, y)):
						continue
					if not _on_bed(vertices, buckets, Vector2(at.x, at.z)):
						off += 1
		assert_gt(checked, 0)
		assert_eq(off, 0, "points off the road bed, seed %d" % map_seed)


## True on a bridge's deck, end to end and edge to edge (sim cells).
func _on_a_bridge(map: GameMap, at: Vector2) -> bool:
	for bridge in map.bridges:
		if RoadBedBuilder.deck_rect(bridge).has_point(at):
			return true
	return false


## The triangles (by first vertex index) whose bounds reach into each unit square of the world.
func _buckets(vertices: PackedVector3Array) -> Dictionary:
	var buckets := {}
	for i in range(0, vertices.size(), 3):
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for k in 3:
			var v := vertices[i + k]
			low = Vector2(minf(low.x, v.x), minf(low.y, v.z))
			high = Vector2(maxf(high.x, v.x), maxf(high.y, v.z))
		for bx in range(int(floor(low.x)), int(floor(high.x)) + 1):
			for bz in range(int(floor(low.y)), int(floor(high.y)) + 1):
				var key := Vector2i(bx, bz)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(i)
	return buckets


func _on_bed(vertices: PackedVector3Array, buckets: Dictionary, point: Vector2) -> bool:
	var key := Vector2i(int(floor(point.x)), int(floor(point.y)))
	for i in buckets.get(key, []):
		var a := Vector2(vertices[i].x, vertices[i].z)
		var b := Vector2(vertices[i + 1].x, vertices[i + 1].z)
		var c := Vector2(vertices[i + 2].x, vertices[i + 2].z)
		if Geometry2D.point_is_inside_triangle(point, a, b, c):
			return true
		# a point exactly on a shared edge may fall outside both triangles by rounding
		var on_edge := (
			_near_segment(point, a, b) or _near_segment(point, b, c) or _near_segment(point, c, a)
		)
		if on_edge:
			return true
	return false


func _near_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) < EPSILON
