## The scenery scatter (#326): no prop's footprint covers a socket block, the Heartstone, the
## road, a bridge or the river; it follows the map's regions and carries on at least 30 cells past
## each edge, thicker further out; it is the same every time for a seed; and it is one
## MultiMesh per kind per chunk, inside a triangle budget at the overview zoom.
extends GutTest

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 42, 7920]
## The scenery's proposed share of the frame at the overview zoom (#326's PR): triangles and
## draw calls in view (the shadow pass not counted).
const OVERVIEW_TRIANGLES := 32000
const MAX_DRAW_CALLS := 18
const EPSILON := 1e-4


func _flat(_cell: Vector2i) -> float:
	return 0.0


func test_no_prop_covers_a_socket_the_heartstone_the_road_a_bridge_or_the_river() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var map := game.map
		var blocked: Array[Rect2] = []
		for anchor in map.sockets:
			blocked.append(Rect2(Vector2(anchor), Vector2(map.footprint, map.footprint)))
		blocked.append(Rect2(map.heartstone))
		for bridge in map.bridges:
			blocked.append(RoadBedBuilder.deck_rect(bridge))
		for cell in map.river:
			blocked.append(Rect2(Vector2(cell), Vector2.ONE))
		var road := _segments(RoadBedBuilder.centrelines(game.routes))
		var walked := _segments(_route_lines(game.routes))
		var bed := LOOKS.ROAD_WIDTH / 2.0 + LOOKS.ROAD_WOBBLE
		var covering := 0
		var checked := 0
		for placement in SceneryScatter.placements(map, game.routes):
			checked += 1
			for rect in blocked:
				var nearest := placement.at.clamp(rect.position, rect.end)
				if placement.at.distance_to(nearest) < placement.radius - EPSILON:
					covering += 1
			if _distance(road, placement.at) < bed + placement.radius - EPSILON:
				covering += 1
			if _distance(walked, placement.at) < placement.radius:
				covering += 1
		assert_gt(checked, 1000, "a full scatter, seed %d" % map_seed)
		assert_eq(covering, 0, "props over the play, seed %d" % map_seed)


func test_it_carries_on_at_least_30_cells_past_every_edge() -> void:
	var map := Game.create(1).map
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for placement in SceneryScatter.placements(map, Game.create(1).routes):
		low = Vector2(minf(low.x, placement.at.x), minf(low.y, placement.at.y))
		high = Vector2(maxf(high.x, placement.at.x), maxf(high.y, placement.at.y))
	assert_lt(low.x, -30.0)
	assert_lt(low.y, -30.0)
	assert_gt(high.x, float(map.cols) + 30.0)
	assert_gt(high.y, float(map.rows) + 30.0)


func test_the_forest_is_thicker_further_out() -> void:
	for map_seed in [1, 2, 3]:
		var game := Game.create(map_seed)
		var near := 0.0
		var far := 0.0
		for placement in SceneryScatter.placements(game.map, game.routes):
			if not SceneryScatter.TREES.has(placement.kind):
				continue
			var out := _out(game.map, placement.at)
			var cover := PI * placement.radius * placement.radius
			if out > 0.0 and out <= 6.0:
				near += cover
			elif out > 20.0:
				far += cover
		var near_cells := _ring_area(game.map, 0.0, 6.0)
		var far_cells := _ring_area(game.map, 20.0, float(LOOKS.SCATTER_RING))
		assert_gt(far / far_cells, near / near_cells, "seed %d" % map_seed)


func test_the_board_scatter_follows_the_regions() -> void:
	var on_rocks := 0
	var boulders := 0
	var on_dirt := 0
	var patches := 0
	var in_forest := 0
	var trees := 0
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		for placement in SceneryScatter.placements(game.map, game.routes):
			var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
			if not game.map.in_bounds(cell):
				continue
			var region := game.map.region_at(cell)
			match placement.kind:
				"boulder":
					boulders += 1
					on_rocks += 1 if region == GameMap.Region.ROCKS else 0
				"dirt":
					patches += 1
					on_dirt += 1 if region == GameMap.Region.DIRT else 0
				"pine", "broadleaf":
					trees += 1
					in_forest += 1 if region == GameMap.Region.FOREST else 0
	assert_gt(boulders, 0)
	assert_gt(patches, 0)
	assert_gt(trees, 0)
	assert_gt(float(on_rocks) / float(boulders), 0.7, "boulders on the rocks")
	assert_gt(float(on_dirt) / float(patches), 0.7, "dirt on the dirt")
	assert_gt(float(in_forest) / float(trees), 0.7, "trees in the forest")


func test_the_same_seed_scatters_the_same_props() -> void:
	var game := Game.create(42)
	var first := SceneryScatter.placements(game.map, game.routes)
	var second := SceneryScatter.placements(game.map, game.routes)
	assert_eq(first.size(), second.size())
	for i in first.size():
		if first[i].at != second[i].at or first[i].kind != second[i].kind:
			fail_test("placement %d differs" % i)
			return
	var other := SceneryScatter.placements(Game.create(43).map, Game.create(43).routes)
	assert_ne(first[0].at, other[0].at, "another seed scatters elsewhere")


func test_one_multimesh_per_kind_per_chunk_standing_on_the_terrain() -> void:
	var game := Game.create(3)
	var raised := func(cell: Vector2i) -> float: return 0.25 * float(posmod(cell.x, 4))
	var placements := SceneryScatter.placements(game.map, game.routes)
	var per_node := {}
	for placement in placements:
		assert_eq(placement.chunk, SceneryScatter.chunk_of(game.map, placement.at))
		var key := "%s_%s" % [SceneryScatter.NAMES[placement.kind], placement.chunk]
		per_node[key] = per_node.get(key, 0) + 1
		var place := SceneryScatter.instance_transform(placement, raised)
		var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
		var at := BoardSpace.point_to_world(placement.at.x, placement.at.y)
		if (
			absf(place.origin.y - raised.call(cell)) > EPSILON
			or absf(place.origin.x - at.x) > EPSILON
		):
			fail_test("a %s stands off the terrain at %s" % [placement.kind, cell])
			return
	var root := SceneryScatter.build(game.map, game.routes, raised)
	assert_eq(root.get_child_count(), per_node.size(), "one node per kind and chunk")
	assert_lte(root.get_child_count(), MAX_DRAW_CALLS)
	for child in root.get_children():
		assert_true(child is MultiMeshInstance3D, child.name)
		var node := child as MultiMeshInstance3D
		assert_eq(node.multimesh.instance_count, per_node.get(String(node.name), -1), node.name)
		var parts := String(node.name).split("_")
		var light := parts[1] != SceneryScatter.CENTRE
		var shadow_off := node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if light:
			assert_true(shadow_off, "the strips cast no shadow: %s" % node.name)
		var kind: String = SceneryScatter.NAMES.find_key(parts[0])
		assert_eq(node.multimesh.mesh, SceneryProps.mesh(kind, light), node.name)
	root.free()


## The scenery drawn at the overview zoom (the game's fit of the whole board on a 16:9 screen).
## A MultiMesh is culled as a whole, so every node with a prop inside the box round the screen's
## footprint on the ground draws all its props. Recorded in the PR with the draw calls.
func test_the_overview_stays_inside_the_scenery_budget() -> void:
	var points: Array[Vector3] = []
	for corner in BoardSpace.corners():
		points.append(corner)
		points.append(corner + Vector3(0.0, CameraRig.top_height(), 0.0))
	var aspect := 16.0 / 9.0
	var pitch := CameraRig.MAX_PITCH
	var yaw := CameraRig.YAW_DEGREES
	var distance := CameraRig.fit_distance(points, pitch, 20.0, aspect, 1.0, yaw)
	var foot := CameraRig.footprint(distance, pitch, 20.0, aspect, yaw)
	var most := 0
	var most_calls := 0
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var triangles := {}
		var seen := {}
		for placement in SceneryScatter.placements(game.map, game.routes):
			var light := placement.chunk != SceneryScatter.CENTRE
			var key := "%s %s" % [placement.kind, placement.chunk]
			triangles[key] = triangles.get(key, 0) + SceneryProps.triangles(placement.kind, light)
			var at := BoardSpace.point_to_world(placement.at.x, placement.at.y)
			if foot.grow(placement.radius).has_point(Vector2(at.x, at.z)):
				seen[key] = true
		var drawn := 0
		for key: String in seen:
			drawn += triangles[key]
		most = maxi(most, drawn)
		most_calls = maxi(most_calls, seen.size())
	gut.p("overview: at most %d scenery triangles and %d draw calls" % [most, most_calls])
	assert_lt(most, OVERVIEW_TRIANGLES)
	assert_lte(most_calls, MAX_DRAW_CALLS)


func test_the_props_are_low_poly_and_the_strips_lighter() -> void:
	for kind in SceneryProps.KINDS:
		var full := SceneryProps.triangles(kind, false)
		var light := SceneryProps.triangles(kind, true)
		assert_between(full, 4, 30, kind)
		assert_lte(light, full, kind)
	for kind in SceneryScatter.FAR_KINDS:
		assert_lt(SceneryProps.triangles(kind, true), SceneryProps.triangles(kind, false), kind)


## How far a point lies outside the board (cells, 0 on it), along the nearer axis's gap.
func _out(map: GameMap, at: Vector2) -> float:
	var dx := maxf(maxf(-at.x, at.x - float(map.cols)), 0.0)
	var dy := maxf(maxf(-at.y, at.y - float(map.rows)), 0.0)
	return maxf(dx, dy)


## The area (cells) of the band from `inner` to `outer` cells outside the board.
func _ring_area(map: GameMap, inner: float, outer: float) -> float:
	var size := Vector2(map.cols, map.rows)
	var big := (size.x + 2.0 * outer) * (size.y + 2.0 * outer)
	var small := (size.x + 2.0 * inner) * (size.y + 2.0 * inner)
	return big - small


func _route_lines(routes: Array[Route]) -> Array[PackedVector2Array]:
	var lines: Array[PackedVector2Array] = []
	for route in routes:
		var line := PackedVector2Array()
		for i in route.xs.size():
			line.append(Vector2(route.xs[i], route.ys[i]))
		lines.append(line)
	return lines


## The segments of `lines`, bucketed by cell (each in every cell within 3 of its bounds).
func _segments(lines: Array[PackedVector2Array]) -> Dictionary:
	var buckets := {}
	for line in lines:
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var low := Vector2i(floori(minf(a.x, b.x)), floori(minf(a.y, b.y))) - Vector2i(3, 3)
			var high := Vector2i(floori(maxf(a.x, b.x)), floori(maxf(a.y, b.y))) + Vector2i(3, 3)
			for row in range(low.y, high.y + 1):
				for col in range(low.x, high.x + 1):
					var key := Vector2i(col, row)
					if not buckets.has(key):
						buckets[key] = []
					buckets[key].append([a, b])
	return buckets


## The distance from `at` to the nearest bucketed segment within reach (INF when none is).
func _distance(buckets: Dictionary, at: Vector2) -> float:
	var best := INF
	for pair: Array in buckets.get(Vector2i(floori(at.x), floori(at.y)), []):
		var closest := Geometry2D.get_closest_point_to_segment(at, pair[0], pair[1])
		best = minf(best, at.distance_to(closest))
	return best
