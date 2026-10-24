## The scenery scatter (#326), on the diorama's terrain field: no prop's footprint covers a socket
## block, the Heartstone, the road, a bridge or the river, and none stands in the gorge or across
## a terrace step; each kind keeps its distance; it follows the map's regions and carries on at
## least 30 cells past each edge, thicker further out; it is the same every time for a seed; and
## it is one MultiMesh per kind per chunk, inside the scenery's 32k triangles at the overview.
extends GutTest

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 42, 259, 7920]
## Layout valley seeds (#458), on the 40 by 24 board (#480); the feeder now starts on the top row.
const LAYOUT_SEEDS: Array[int] = [1, 2, 3, 5, 6, 11]
## The scenery's share of the frame at the overview zoom, from the owner's provisional budget
## (2026-10-18: 200k a frame; terrain and road beds 40k, scenery 32k), in view, before shadows;
## and its draw calls there.
const OVERVIEW_TRIANGLES := 32000
const MAX_DRAW_CALLS := 18
const EPSILON := 1e-4
## How many times denser per cell a kind grows in its own region than elsewhere on the board.
const REGION_CROWDING := 5.0


func _field(map_seed: int) -> TerrainField:
	var game := Game.create(map_seed)
	return TerrainField.from_map(game.map, game.routes)


## The field of the layout valley (#458) for a seed, with the routes the game would walk.
func _layout_field(map_seed: int) -> TerrainField:
	return TerrainField.from_map(MapGen.generate_layout_valley(map_seed))


func test_no_prop_covers_a_socket_the_heartstone_the_road_a_bridge_or_the_river() -> void:
	for map_seed in SEEDS:
		var field := _field(map_seed)
		var map := field.map
		var blocked: Array[Rect2] = []
		for anchor in map.sockets:
			blocked.append(Rect2(Vector2(anchor), Vector2(map.footprint, map.footprint)))
		blocked.append(Rect2(map.heartstone))
		for bridge in map.bridges:
			blocked.append(RoadBedBuilder.deck_rect(bridge))
		for cell in field.river:
			blocked.append(Rect2(Vector2(cell), Vector2.ONE))
		var road := _segments(RoadBedBuilder.centrelines(field.routes))
		var walked := _segments(_route_lines(field.routes))
		var bed := LOOKS.ROAD_WIDTH / 2.0 + LOOKS.ROAD_WOBBLE
		var covering := 0
		var checked := 0
		for placement in SceneryScatter.placements(field):
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


func test_no_prop_stands_in_the_gorge_across_a_step_or_on_a_road_lead() -> void:
	for map_seed in SEEDS:
		_assert_on_their_terrace(_field(map_seed), "seed %d" % map_seed)
	# the layout valley's feeder may come in from the east edge: its lead runs out that way, and
	# the road is drawn coming in from there too, not from the top (#461)
	for map_seed in LAYOUT_SEEDS:
		_assert_on_their_terrace(_layout_field(map_seed), "layout seed %d" % map_seed)


func _assert_on_their_terrace(field: TerrainField, label: String) -> void:
	var leads := {}
	for lead: Array in field.leads:
		for cell: Vector2i in lead:
			leads[cell] = true
	var wrong := 0
	for placement in SceneryScatter.placements(field):
		var at := placement.at
		var own := field.level_at(Vector2i(floori(at.x), floori(at.y)))
		# every cell the footprint reaches into, checked on a ring of points round it
		for k in 16:
			var angle := TAU * float(k) / 16.0
			var edge := at + Vector2(cos(angle), sin(angle)) * (placement.radius - EPSILON)
			var cell := Vector2i(floori(edge.x), floori(edge.y))
			if field.is_gorge(cell) or field.level_at(cell) != own or leads.has(cell):
				wrong += 1
				break
	assert_eq(wrong, 0, "props off their terrace, %s" % label)


## The keep-offs, at their edge: a prop just inside its distance from a deck, a socket, the river
## and the road is refused, one just outside it stands (each obstacle alone, so nothing else is
## near).
func test_each_kind_keeps_its_distance_from_a_deck_a_socket_and_the_road() -> void:
	var half := LOOKS.ROAD_WIDTH / 2.0 + LOOKS.ROAD_WOBBLE
	var box := Rect2(Vector2(10.0, 10.0), Vector2(2.0, 1.2))
	var edge := Vector2(11.0, 10.0)
	var up := Vector2(0.0, -1.0)
	for kind in SceneryProps.KINDS:
		var radius := SceneryProps.reach(kind)
		var deck := SceneryScatter.Obstacles.new(null)
		deck.add_rect(box, "bridge")
		_assert_edge(deck, kind, radius, edge, up, radius + LOOKS.KEEP_OFF_BRIDGE, "deck")
		var socket := SceneryScatter.Obstacles.new(null)
		socket.add_rect(box, "socket")
		var socket_gap: float = radius + LOOKS.KEEP_OFF_SOCKET[kind]
		_assert_edge(socket, kind, radius, edge, up, socket_gap, "socket")
		var river := SceneryScatter.Obstacles.new(null)
		river.add_rect(box, "river")
		_assert_edge(river, kind, radius, edge, up, radius + LOOKS.KEEP_OFF_RIVER, "river")
		var road := SceneryScatter.Obstacles.new(null)
		road.add_segment(Vector2(5.0, 10.5), Vector2(15.0, 10.5))
		var road_gap: float = half + radius + LOOKS.KEEP_OFF_ROAD[kind]
		_assert_edge(road, kind, radius, Vector2(10.0, 10.5), up, road_gap, "road")


## The biggest tree, close enough to a road to be refused, stands two rows from the road's own
## cells: the obstacles must be bucketed that far out (`REACH`).
func test_the_buckets_reach_as_far_as_the_biggest_prop_keeps_off() -> void:
	var size := LOOKS.SCALE_MAX * LOOKS.OUTSIDE_TREE_SCALE
	var radius := SceneryProps.reach("broadleaf") * size
	var gap: float = (
		LOOKS.ROAD_WIDTH / 2.0 + LOOKS.ROAD_WOBBLE + radius + LOOKS.KEEP_OFF_ROAD["broadleaf"]
	)
	var road := SceneryScatter.Obstacles.new(null)
	road.add_segment(Vector2(0.0, 10.5), Vector2(20.0, 10.5))
	var placement := SceneryScatter.Placement.new()
	placement.kind = "broadleaf"
	placement.radius = radius
	placement.at = Vector2(10.0, 10.5 - gap + 0.01)
	assert_lte(floori(placement.at.y), 8, "two rows from the road's row")
	assert_false(road.clear(placement), "found from %.2f cells away" % gap)
	placement.at.y -= 0.02
	assert_true(road.clear(placement))


func test_the_river_past_the_board_is_kept_clear() -> void:
	var field := _field(7920)
	var past := 0
	for cell in field.river:
		if not field.map.in_bounds(cell):
			past += 1
	assert_gt(past, 20, "the field carries the river past the board")
	var keep_off := SceneryScatter.Obstacles.new(field)
	var outside: Vector2i = field.river[field.river.size() - 3]
	assert_false(field.map.in_bounds(outside))
	var placement := SceneryScatter.Placement.new()
	placement.kind = "grass"
	placement.radius = SceneryProps.reach("grass")
	placement.at = Vector2(outside) + Vector2(1.0 + placement.radius, 0.5)
	assert_false(keep_off.clear(placement), "kept off the river's bank by KEEP_OFF_RIVER")
	placement.at.x += LOOKS.KEEP_OFF_RIVER + 0.01
	if not field.is_gorge(Vector2i(floori(placement.at.x), floori(placement.at.y))):
		assert_true(keep_off.clear(placement), "and no further")


func test_it_carries_on_at_least_30_cells_past_every_edge() -> void:
	var field := _field(1)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for placement in SceneryScatter.placements(field):
		low = Vector2(minf(low.x, placement.at.x), minf(low.y, placement.at.y))
		high = Vector2(maxf(high.x, placement.at.x), maxf(high.y, placement.at.y))
	assert_lt(low.x, -30.0)
	assert_lt(low.y, -30.0)
	assert_gt(high.x, float(field.map.cols) + 30.0)
	assert_gt(high.y, float(field.map.rows) + 30.0)
	assert_lte(LOOKS.SCATTER_RING, TerrainField.MARGIN, "inside the field")


func test_the_forest_is_thicker_further_out() -> void:
	for map_seed in [1, 2, 3]:
		var field := _field(map_seed)
		var near := 0.0
		var far := 0.0
		for placement in SceneryScatter.placements(field):
			if not SceneryScatter.TREES.has(placement.kind):
				continue
			var out := _out(field.map, placement.at)
			var cover := PI * placement.radius * placement.radius
			if out > 0.0 and out <= 6.0:
				near += cover
			elif out > 20.0:
				far += cover
		var near_cells := _ring_area(field.map, 0.0, 6.0)
		var far_cells := _ring_area(field.map, 20.0, float(LOOKS.SCATTER_RING))
		assert_gt(far / far_cells, near / near_cells, "seed %d" % map_seed)


## The valley has far more meadow than rock, so the share of boulders that lie in the rocks would
## be low whatever the table says; what follows the region is the density per cell. The same holds
## for dirt and trees: the layout valley (#458) paints far less forest and dirt than the strip
## valley (about 5 and 3 per cent of its cells against 9 and 11), so their share in their region
## drops while the scatter follows the regions as before (#461).
func test_the_board_scatter_follows_the_regions() -> void:
	var fields: Array[TerrainField] = []
	for map_seed in SEEDS:
		fields.append(_field(map_seed))
	for map_seed in LAYOUT_SEEDS:
		fields.append(_layout_field(map_seed))
	_assert_follows_the_regions(fields.slice(0, SEEDS.size()), "game board")
	_assert_follows_the_regions(fields.slice(SEEDS.size()), "layout valley")


## Each kind is at least `REGION_CROWDING` times as dense per cell in its region as elsewhere on
## the board.
func _assert_follows_the_regions(fields: Array[TerrainField], label: String) -> void:
	var wanted := {
		"boulder": GameMap.Region.ROCKS, "dirt": GameMap.Region.DIRT, "tree": GameMap.Region.FOREST
	}
	# per kind: props in its region, props elsewhere, cells in its region, cells elsewhere
	var counts := {"boulder": [0, 0, 0, 0], "dirt": [0, 0, 0, 0], "tree": [0, 0, 0, 0]}
	for field in fields:
		for row in field.map.rows:
			for col in field.map.cols:
				var region := field.map.region_at(Vector2i(col, row))
				for key: String in counts:
					counts[key][2 if region == wanted[key] else 3] += 1
		for placement in SceneryScatter.placements(field):
			var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
			if not field.map.in_bounds(cell):
				continue
			var key := "tree" if SceneryScatter.TREES.has(placement.kind) else placement.kind
			if not counts.has(key):
				continue
			counts[key][0 if field.map.region_at(cell) == wanted[key] else 1] += 1
	for key: String in counts:
		var tally: Array = counts[key]
		assert_gt(tally[0], 0, "%s in its region, %s" % [key, label])
		assert_gt(tally[2], 0, "the %s has %s cells" % [label, key])
		var inside := float(tally[0]) / float(tally[2])
		var elsewhere := float(tally[1]) / float(tally[3])
		gut.p("%s, %s: %.3f a cell in its region, %.3f elsewhere" % [label, key, inside, elsewhere])
		assert_gt(inside, elsewhere * REGION_CROWDING, "%s crowd their region, %s" % [key, label])


func test_the_same_seed_scatters_the_same_props() -> void:
	var first := SceneryScatter.placements(_field(42))
	var second := SceneryScatter.placements(_field(42))
	assert_eq(first.size(), second.size())
	for i in first.size():
		if first[i].at != second[i].at or first[i].kind != second[i].kind:
			fail_test("placement %d differs" % i)
			return
	var other := SceneryScatter.placements(_field(43))
	assert_ne(first[0].at, other[0].at, "another seed scatters elsewhere")


func test_one_multimesh_per_kind_per_chunk_standing_on_the_terrain() -> void:
	var field := _field(3)
	var top := Callable(field, "top_at")
	var found := SceneryScatter.placements(field)
	var per_node := {}
	for placement in found:
		assert_eq(placement.chunk, SceneryScatter.chunk_of(field.map, placement.at))
		var key := "%s_%s" % [SceneryScatter.NAMES[placement.kind], placement.chunk]
		per_node[key] = per_node.get(key, 0) + 1
		var place := SceneryScatter.instance_transform(placement, top)
		var cell := Vector2i(floori(placement.at.x), floori(placement.at.y))
		var at := BoardSpace.point_to_world(placement.at.x, placement.at.y)
		if (
			absf(place.origin.y - field.top_at(cell)) > EPSILON
			or absf(place.origin.x - at.x) > EPSILON
		):
			fail_test("a %s stands off the terrain at %s" % [placement.kind, cell])
			return
	var root := SceneryScatter.build(field)
	assert_eq(root.get_child_count(), per_node.size(), "one node per kind and chunk")
	assert_lte(root.get_child_count(), MAX_DRAW_CALLS)
	for child in root.get_children():
		assert_true(child is MultiMeshInstance3D, child.name)
		var node := child as MultiMeshInstance3D
		assert_eq(node.multimesh.instance_count, per_node.get(String(node.name), -1), node.name)
		var parts := String(node.name).split("_")
		var light := not SceneryScatter.MIDDLE.has(parts[1])
		var kind: String = SceneryScatter.NAMES.find_key(parts[0])
		var casts := node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var should := SceneryScatter.TREES.has(kind) or (kind == "boulder" and not light)
		assert_eq(casts, should, "%s: trees and near boulders cast" % node.name)
		assert_eq(node.multimesh.mesh, SceneryProps.mesh(kind, light), node.name)
	root.free()


## A view of one end of the board draws only the props near it: at the closest zoom over the
## spawn, the other half of the board and the far strips are culled.
func test_a_close_view_culls_most_of_the_scenery() -> void:
	var field := _field(1)
	var found := SceneryScatter.placements(field)
	var spawn := Vector2(field.routes[0].xs[1], field.routes[0].ys[1])
	var view := Rect2(spawn - Vector2(8.0, 6.0), Vector2(16.0, 12.0))
	var drawn := {}
	var all := 0
	var triangles := {}
	for placement in found:
		var tris := SceneryProps.triangles(
			placement.kind, not SceneryScatter.MIDDLE.has(placement.chunk)
		)
		var key := "%s %s" % [placement.kind, placement.chunk]
		triangles[key] = triangles.get(key, 0) + tris
		all += tris
		if view.has_point(placement.at):
			drawn[key] = true
	var shown := 0
	for key: String in drawn:
		shown += triangles[key]
	gut.p("close view at the spawn draws %d of %d scenery triangles" % [shown, all])
	assert_lt(float(shown) / float(all), 0.6)


## The scenery drawn at the overview zoom (the game's fit of the whole board on a 16:9 screen).
## A MultiMesh is culled as a whole, so every node with a prop inside the box round the screen's
## footprint on the ground draws all its props.
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
		var triangles := {}
		var seen := {}
		for placement in SceneryScatter.placements(_field(map_seed)):
			var light := not SceneryScatter.MIDDLE.has(placement.chunk)
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


func test_the_props_are_low_poly_and_their_footprint_is_their_mesh() -> void:
	for kind in SceneryProps.KINDS:
		var full := SceneryProps.triangles(kind, false)
		var light := SceneryProps.triangles(kind, true)
		assert_between(full, 4, 30, kind)
		assert_lte(light, full, kind)
		var reach := SceneryProps.reach(kind)
		for lod: bool in [false, true]:
			for v: Vector3 in SceneryProps.mesh(kind, lod).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				assert_lte(Vector2(v.x, v.z).length(), reach + EPSILON, kind)
		var built: float = LOOKS.PROP_RADIUS[kind]
		assert_between(
			reach, built * 0.8, built * 1.25, "%s is about the size it is built to" % kind
		)
	for kind in SceneryScatter.FAR_KINDS:
		assert_lt(SceneryProps.triangles(kind, true), SceneryProps.triangles(kind, false), kind)


## The light pine is the full one's outline: as tall and as wide, so the switch does not jump.
func test_the_light_pine_keeps_the_full_pines_outline() -> void:
	var size := {}
	for lod: bool in [false, true]:
		var top := 0.0
		for v: Vector3 in SceneryProps.mesh("pine", lod).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			top = maxf(top, v.y)
		size[lod] = top
	assert_almost_eq(size[true], size[false], 0.02, "as tall")


func _assert_edge(
	keep_off: SceneryScatter.Obstacles,
	kind: String,
	radius: float,
	edge: Vector2,
	out: Vector2,
	gap: float,
	what: String
) -> void:
	var placement := SceneryScatter.Placement.new()
	placement.kind = kind
	placement.radius = radius
	placement.at = edge + out * (gap - 0.01)
	assert_false(
		keep_off.clear(placement), "a %s just inside its keep-off from the %s" % [kind, what]
	)
	placement.at = edge + out * (gap + 0.01)
	assert_true(keep_off.clear(placement), "a %s just outside it, by the %s" % [kind, what])


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
