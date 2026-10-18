## The road beds and bridges (#325): every point the foes walk lies on the bed or on a bridge, the
## bed stays inside the road cells (and the Heartstone's yard inside its block), the bridges stand
## on `map.bridges`, the feeder ends where it joins and the lips open there, and the whole road is
## two draw calls.
extends GutTest

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 42, 99, 7920]
## Points checked on each stretch between two route points (its start included).
const SUBSTEPS := 4
const EPSILON := 1e-4


func _flat(_cell: Vector2i) -> float:
	return 0.0


func test_every_route_point_lies_on_the_bed_or_a_bridge() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		assert_eq(
			_off_bed(game.map, game.routes), 0, "route points off the bed, seed %d" % map_seed
		)


## The curves of #321 (each corner cell's centre replaced by a Bezier from the cells either
## side, the widest it rounds) are on the bed too, so the bed needs no change when they land.
func test_curved_routes_lie_on_the_bed_too() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var curved: Array[Route] = []
		for cells: Array[Vector2i] in game.map.routes:
			curved.append(_curved(cells))
		assert_eq(_off_bed(game.map, curved), 0, "curve points off the bed, seed %d" % map_seed)


func test_the_bed_stays_inside_the_road_cells() -> void:
	for map_seed in SEEDS:
		var map := Game.create(map_seed).map
		var bed := _bed(map, Game.create(map_seed).routes)
		var outside := 0
		for i in range(0, bed.size(), 3):
			var a := bed[i]
			var b := bed[i + 1]
			var c := bed[i + 2]
			for at: Vector3 in [
				a, b, c, (a + b + c) / 3.0, (a + b) / 2.0, (b + c) / 2.0, (a + c) / 2.0
			]:
				if not _allowed(map, at):
					outside += 1
		assert_eq(outside, 0, "bed points outside the road cells, seed %d" % map_seed)


func test_the_bridges_stand_on_the_bridge_cells() -> void:
	var seen := 0
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var root := RoadBedBuilder.build(game.map, game.routes, _flat)
		var mesh: Mesh = (root.get_node("Bridges") as MeshInstance3D).mesh
		if game.map.bridges.is_empty():
			assert_eq(mesh.get_surface_count(), 0, "no bridge without a river, seed %d" % map_seed)
			root.free()
			continue
		seen += game.map.bridges.size()
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var stray := 0
		for v in vertices:
			var sim := _sim(v)
			var on_one := false
			for bridge in game.map.bridges:
				if RoadBedBuilder.deck_rect(bridge).grow(0.05).has_point(sim):
					on_one = true
			if not on_one:
				stray += 1
		assert_eq(stray, 0, "bridge parts off the bridge cells, seed %d" % map_seed)
		for bridge in game.map.bridges:
			var deck := RoadBedBuilder.deck_rect(bridge)
			var cell := Rect2(Vector2(bridge.cell), Vector2.ONE)
			assert_true(deck.encloses(cell), "the deck spans its cell, seed %d" % map_seed)
			assert_true(game.map.tiles[bridge.cell.y][bridge.cell.x] == GameMap.Tile.ROAD)
		root.free()
	assert_gt(seen, 0, "some of the seeds have a bridge")


func test_the_bed_keeps_off_the_river_and_reaches_under_the_deck() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var bed := _bed(game.map, game.routes)
		var wet := 0
		for v in bed:
			var sim := _sim(v)
			for cell in game.map.river:
				if Rect2(Vector2(cell) + Vector2(0.02, 0.02), Vector2(0.96, 0.96)).has_point(sim):
					wet += 1
		assert_eq(wet, 0, "no bed over the river, seed %d" % map_seed)
		# on both banks the bed runs to the river's edge, under the deck's ends
		for bridge in game.map.bridges:
			var along := 0 if bridge.horizontal else 1
			var reach := 0.5
			var middle := Vector2(bridge.cell) + Vector2(0.5, 0.5)
			for end: float in [-1.0, 1.0]:
				var found := false
				for v in bed:
					var sim := _sim(v)
					var gap := (sim[along] - middle[along]) * end
					if absf(sim[1 - along] - middle[1 - along]) < 0.5 and absf(gap - reach) < 0.02:
						found = true
						break
				assert_true(found, "the bed reaches the deck's end, seed %d" % map_seed)


func test_the_feeder_is_drawn_to_its_join_and_no_further() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var lines := RoadBedBuilder.centrelines(game.routes)
		assert_eq(lines.size(), game.routes.size(), "one line a route, seed %d" % map_seed)
		if lines.size() < 2:
			continue
		var main := game.routes[0]
		var feeder := lines[1]
		var end := feeder[feeder.size() - 1]
		var join := Vector2(main.xs[game.map.join_index + 1], main.ys[game.map.join_index + 1])
		assert_almost_eq(
			end.distance_to(join), 0.0, 1e-3, "it ends at the join, seed %d" % map_seed
		)
		# it starts off the board, past its spawn point
		var start := feeder[0]
		var inside := Rect2(Vector2.ZERO, Vector2(game.map.cols, game.map.rows))
		assert_false(
			inside.grow(2.0).has_point(start), "it comes out of the haze, seed %d" % map_seed
		)


func test_the_lips_open_where_the_feeder_joins_and_round_the_heartstone() -> void:
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var bed := _bed(game.map, game.routes)
		var lines := RoadBedBuilder.centrelines(game.routes)
		var join := lines[1][lines[1].size() - 1]
		var round := RoadBedBuilder.heart_yard(game.map, _flat)
		var yard := Vector2(round.x, round.y)
		var raised := 0
		for v in bed:
			var sim := _sim(v)
			var near_join := sim.distance_to(join) < 0.3
			var in_yard := sim.distance_to(yard) < round.z - LOOKS.LIP_WIDTH
			if (near_join or in_yard) and v.y > LOOKS.ROAD_LIFT + EPSILON:
				raised += 1
		assert_eq(raised, 0, "no lip across the join or the yard, seed %d" % map_seed)


## Under a flat block the yard fills the Heartstone's block; where part of the block stands on a
## higher terrace it shrinks to a round end in the road's last cell, so it never runs into it.
func test_the_heartstone_yard_keeps_to_the_road_level() -> void:
	var map := Game.create(1).map
	var block := map.heartstone
	var last := map.path[map.path.size() - 1]
	var flat_yard := RoadBedBuilder.heart_yard(map, _flat)
	var middle := Vector2(block.position) + Vector2(block.size) / 2.0
	assert_eq(Vector2(flat_yard.x, flat_yard.y), middle)
	assert_almost_eq(flat_yard.z, LOOKS.HEART_YARD_RADIUS, 1e-5)
	var terraced := func(cell: Vector2i) -> float: return float(map.height_at(cell)) * 0.45
	var capped := RoadBedBuilder.heart_yard(map, terraced)
	if map.height_at(block.position + Vector2i(0, 1)) != map.height_at(last):
		assert_eq(Vector2(capped.x, capped.y), Vector2(last) + Vector2(0.5, 0.5))
		assert_almost_eq(capped.z, LOOKS.HEART_CAP_RADIUS, 1e-5)
	var bed := RoadBedBuilder.bed_mesh(map, Game.create(1).routes, terraced)
	for v: Vector3 in bed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var sim := _sim(v)
		var cell := Vector2i(floori(sim.x), floori(sim.y))
		if block.has_point(cell):
			assert_lt(v.y, float(map.height_at(cell)) * 0.45 + 0.04, "no yard on the terrace")


func test_it_stands_on_the_terrain_it_is_given() -> void:
	var game := Game.create(3)
	var high := func(_cell: Vector2i) -> float: return 1.5
	var root := RoadBedBuilder.build(game.map, game.routes, high)
	var bed: Mesh = (root.get_node("RoadBed") as MeshInstance3D).mesh
	for v: Vector3 in bed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_between(v.y, 1.5, 1.5 + LOOKS.ROAD_LIFT + LOOKS.LIP_HEIGHT + EPSILON)
	for bridge in game.map.bridges:
		var top := RoadBedBuilder.deck_top(bridge, high)
		assert_almost_eq(top, 1.5 + LOOKS.ROAD_LIFT + LOOKS.DECK_LIFT, EPSILON)
	root.free()


func test_a_bridge_over_a_gorge_gets_trestle_legs() -> void:
	var game := Game.create(1)
	assert_false(game.map.bridges.is_empty(), "seed 1 has a bridge")
	var bridge_cell: Vector2i = game.map.bridges[0].cell
	var gorge := func(cell: Vector2i) -> float: return -1.2 if cell == bridge_cell else 0.0
	var flat := RoadBedBuilder.bridge_mesh(game.map, _flat)
	var deep := RoadBedBuilder.bridge_mesh(game.map, gorge)
	var flat_low := _lowest(flat)
	var deep_low := _lowest(deep)
	assert_gt(_triangles(deep), _triangles(flat), "legs added")
	assert_almost_eq(deep_low, -1.2, 0.03, "the legs reach the gorge floor")
	assert_gt(flat_low, -0.1)


func test_the_same_map_draws_the_same_road() -> void:
	var game := Game.create(42)
	var first := RoadBedBuilder.bed_mesh(game.map, game.routes, _flat)
	var second := RoadBedBuilder.bed_mesh(game.map, game.routes, _flat)
	assert_eq(
		first.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		second.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var a := RoadBedBuilder.bridge_mesh(game.map, _flat)
	var b := RoadBedBuilder.bridge_mesh(game.map, _flat)
	assert_eq(
		a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)


## Two meshes of one surface each, whatever the map: two draw calls (plus the bridges' shadow).
func test_the_road_is_two_draw_calls_and_a_few_thousand_triangles() -> void:
	var most_bed := 0
	var most_bridges := 0
	for map_seed in SEEDS:
		var game := Game.create(map_seed)
		var root := RoadBedBuilder.build(game.map, game.routes, _flat)
		assert_eq(root.get_child_count(), 2)
		var bed: Mesh = (root.get_node("RoadBed") as MeshInstance3D).mesh
		var bridges: Mesh = (root.get_node("Bridges") as MeshInstance3D).mesh
		assert_eq(bed.get_surface_count(), 1)
		assert_lte(bridges.get_surface_count(), 1)
		most_bed = maxi(most_bed, _triangles(bed))
		most_bridges = maxi(most_bridges, _triangles(bridges))
		root.free()
	gut.p("most triangles: bed %d, bridges %d" % [most_bed, most_bridges])
	assert_lt(most_bed, 4000, "the bed fits the terrain budget")
	assert_lt(most_bridges, 1200, "the bridges fit the terrain budget")


## How many points along the routes (route points and points between them) lie neither on a bed
## triangle nor on a bridge's deck.
func _off_bed(map: GameMap, routes: Array[Route]) -> int:
	var bed := _bed(map, routes)
	var buckets := _buckets(bed)
	var off := 0
	for route in routes:
		for p in route.xs.size():
			for s in SUBSTEPS:
				if p == route.xs.size() - 1 and s > 0:
					break
				var t := float(s) / float(SUBSTEPS)
				var q := mini(p + 1, route.xs.size() - 1)
				var at := Vector2(
					route.xs[p] + (route.xs[q] - route.xs[p]) * t,
					route.ys[p] + (route.ys[q] - route.ys[p]) * t
				)
				if _on_deck(map, at):
					continue
				var world := BoardSpace.point_to_world(at.x, at.y)
				if not _on_triangles(bed, buckets, Vector2(world.x, world.z)):
					off += 1
	return off


func _on_deck(map: GameMap, at: Vector2) -> bool:
	for bridge in map.bridges:
		var deck := RoadBedBuilder.deck_rect(bridge)
		# the planks, from one end to the other and from one edge to the other
		var trim := deck.size.y / 2.0 - LOOKS.DECK_WIDTH / 2.0
		var walk := deck.grow_individual(0.0, -trim, 0.0, -trim)
		if not bridge.horizontal:
			trim = deck.size.x / 2.0 - LOOKS.DECK_WIDTH / 2.0
			walk = deck.grow_individual(-trim, 0.0, -trim, 0.0)
		if walk.has_point(at):
			return true
	return false


## The bed's triangles as a flat list of their corners.
func _bed(map: GameMap, routes: Array[Route]) -> PackedVector3Array:
	var mesh := RoadBedBuilder.bed_mesh(map, routes, _flat)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var corners := PackedVector3Array()
	for i in indices:
		corners.append(vertices[i])
	return corners


## True when a bed point may be there: on a road cell, off the board, or in the Heartstone's block.
func _allowed(map: GameMap, at: Vector3) -> bool:
	var sim := _sim(at)
	var cell := Vector2i(floori(sim.x), floori(sim.y))
	if not map.in_bounds(cell):
		return true
	if map.heartstone.has_point(cell):
		return true
	return map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD


## A world point back in sim cells.
func _sim(at: Vector3) -> Vector2:
	var origin := BoardSpace.point_to_world(0.0, 0.0)
	return Vector2(at.x - origin.x, at.z - origin.z)


func _buckets(corners: PackedVector3Array) -> Dictionary:
	var buckets := {}
	for i in range(0, corners.size(), 3):
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for k in 3:
			var v := corners[i + k]
			low = Vector2(minf(low.x, v.x), minf(low.y, v.z))
			high = Vector2(maxf(high.x, v.x), maxf(high.y, v.z))
		for bx in range(floori(low.x), floori(high.x) + 1):
			for bz in range(floori(low.y), floori(high.y) + 1):
				var key := Vector2i(bx, bz)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append(i)
	return buckets


func _on_triangles(corners: PackedVector3Array, buckets: Dictionary, at: Vector2) -> bool:
	for i: int in buckets.get(Vector2i(floori(at.x), floori(at.y)), []):
		var a := Vector2(corners[i].x, corners[i].z)
		var b := Vector2(corners[i + 1].x, corners[i + 1].z)
		var c := Vector2(corners[i + 2].x, corners[i + 2].z)
		if Geometry2D.point_is_inside_triangle(at, a, b, c):
			return true
	return false


func _lowest(mesh: Mesh) -> float:
	var low := INF
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		low = minf(low, v.y)
	return low


func _triangles(mesh: Mesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_INDEX] != null:
		return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


## A route along `cells` rounded as #321 rounds it: each corner cell's centre becomes a quadratic
## Bezier with that centre as its control point, from one cell back to one cell on (the centres
## of the cells either side), or half a cell (the corner cell's edges) when a neighbouring cell is
## a corner too; eight points a full curve.
func _curved(cells: Array[Vector2i]) -> Route:
	var plain := Route.build(cells)
	var route := Route.new()
	route.xs.append(plain.xs[0])
	route.ys.append(plain.ys[0])
	var corner: Array[bool] = []
	for k in cells.size():
		var inner := k > 0 and k < cells.size() - 1
		corner.append(inner and cells[k + 1] - cells[k] != cells[k] - cells[k - 1])
	for k in cells.size():
		var at := Vector2(cells[k]) + Vector2(0.5, 0.5)
		if not corner[k]:
			route.xs.append(at.x)
			route.ys.append(at.y)
			continue
		var tight := corner[k - 1] or corner[k + 1]
		var leg := 0.5 if tight else 1.0
		var a := at - Vector2(cells[k] - cells[k - 1]) * leg
		var b := at + Vector2(cells[k + 1] - cells[k]) * leg
		var first := 0 if tight and not corner[k - 1] else 1
		var last := 8 if tight else 7
		for s in range(first, last + 1):
			var t := float(s) / 8.0
			var p := a.lerp(at, t).lerp(at.lerp(b, t), t)
			route.xs.append(p.x)
			route.ys.append(p.y)
	route.cumulative.append(0.0)
	for i in range(1, route.xs.size()):
		var step := Vector2(route.xs[i] - route.xs[i - 1], route.ys[i] - route.ys[i - 1]).length()
		route.cumulative.append(route.cumulative[i - 1] + step)
	route.total = route.cumulative[route.cumulative.size() - 1]
	return route
