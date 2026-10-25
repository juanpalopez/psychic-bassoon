## The road beds and bridges (#325), on the diorama's own terrain (`TerrainField.top_at`) and the
## game's curved routes (`Route.build_curved`, #321): every point the foes walk lies on the bed or
## on a bridge's planks, the bed keeps to the road cells (within a tenth of a cell where a curve
## cuts an inner corner) and never sinks into the gorge, the bridges stand on `map.bridges` with
## their planks where the field stands foes and guards, the feeder is drawn to its join and no
## further, the lips open there, every triangle faces up, and the whole road is two draw calls.
extends GutTest

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
## 259 has two bridges, one of them on the feeder.
const SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 42, 99, 259, 7920]
## Points checked on each stretch between two route points (its start included).
const SUBSTEPS := 4
const EPSILON := 1e-4
## How far a curve's bed may reach past the road cells, where it cuts an inner corner.
const CORNER_TOLERANCE := 0.1
## How far the 2 cell bed may overhang the corner of a river cell at a bank (#446): the bed is
## wider than the bridge's cell, so beside a diagonal bank it runs up to 0.095 over the lip.
const RIVER_OVERHANG := 0.1
## Layout valley seeds (#458): a river two or three cells wide, crossed on two or three bridge
## cells side by side (2, 5 and 11 on three).
const LAYOUT_SEEDS: Array[int] = [1, 2, 3, 5, 11]


func _flat(_cell: Vector2i) -> float:
	return 0.0


## The game for a seed, its field, and the field's tops as the height callable.
func _setup(map_seed: int) -> Dictionary:
	var game := Game.create(map_seed)
	var field := TerrainField.from_map(game.map, game.routes)
	return {
		"game": game,
		"routes": game.routes,
		"map": game.map,
		"field": field,
		"top": Callable(field, "top_at"),
		"label": "seed %d" % map_seed,
	}


## The same for the layout valley (#458), with the routes the game would walk on it.
func _layout(map_seed: int) -> Dictionary:
	var map := MapGen.generate_layout_valley(map_seed)
	var field := TerrainField.from_map(map)
	return {
		"routes": field.routes,
		"map": map,
		"field": field,
		"top": Callable(field, "top_at"),
		"label": "layout seed %d" % map_seed,
	}


## Every setup the bed and bridge tests draw: the game board's seeds and the layout valley's.
func _setups() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for map_seed in SEEDS:
		all.append(_setup(map_seed))
	for map_seed in LAYOUT_SEEDS:
		all.append(_layout(map_seed))
	return all


func test_the_game_walks_curved_routes_and_the_valley_has_one_road_bridge() -> void:
	for map_seed in [1, 259, 7920]:
		var game := Game.create_on_strip_valley(map_seed)
		assert_true(game.routes[0].curved, "the game's routes are the curves of #321")
		# one road crossing (its bridge cells side by side; one on the strip valley's narrow river)
		var crossings := RoadBedBuilder.crossings(game.map)
		assert_eq(crossings.size(), 1, "the Bluewater Crossing's road bridge, seed %d" % map_seed)
		for bridge: GameMap.Bridge in crossings[0]:
			assert_gte(bridge.path_index, 0, "on the main road, not the feeder")


## The layout valley's river runs across the whole valley, two or three cells wide (owner,
## 2026-10-23): each lane crosses it once (the fork's two lanes, #481), on a bridge cell for each
## wet road cell, side by side, and the builder draws one bridge over each lane's cells (the hero
## crosses on its own bridge cells).
func test_the_layout_valley_crosses_its_river_on_bridge_cells_side_by_side() -> void:
	for map_seed in LAYOUT_SEEDS:
		var map := MapGen.generate_layout_valley(map_seed)
		var label := "layout seed %d" % map_seed
		assert_between(map.bridges.size(), 4, 6, label)
		# the hero's own bridge stays only where a row far from both lanes has river
		assert_lte(map.hero_bridges.size(), 3, label)
		var crossings := RoadBedBuilder.crossings(map)
		assert_eq(crossings.size(), 2, "one crossing a lane, " + label)
		var cells := 0
		for run: Array in crossings:
			cells += run.size()
			assert_between(run.size(), 2, 3, label)
		assert_eq(cells, map.bridges.size(), label)
		for run: Array in crossings:
			for k in run.size():
				var bridge: GameMap.Bridge = run[k]
				assert_gte(bridge.path_index, 0, "on its lane, " + label)
				if k > 0:
					var step := bridge.cell - (run[k - 1] as GameMap.Bridge).cell
					assert_eq(step.length_squared(), 1, "side by side, " + label)


func test_every_point_foes_walk_lies_on_the_bed_or_a_bridge() -> void:
	for setup in _setups():
		assert_eq(_off_bed(setup, setup.routes), 0, "walked points off the bed, " + setup.label)


func test_the_curves_built_from_the_cells_lie_on_the_bed_too() -> void:
	for map_seed in SEEDS:
		var setup := _setup(map_seed)
		var map: GameMap = setup.map
		var curved: Array[Route] = []
		for cells: Array[Vector2i] in map.routes:
			curved.append(Route.build_curved(cells))
		assert_eq(_off_bed(setup, curved), 0, "curve points off the bed, seed %d" % map_seed)
		# and every cell's own point, the one the sim stands for the cell
		var off := 0
		var bed := _bed(setup, curved)
		var buckets := _buckets(bed)
		for route in curved:
			for k in route.cell_points:
				var at := Vector2(route.xs[k], route.ys[k])
				var world := BoardSpace.point_to_world(at.x, at.y)
				if (
					not _on_deck(map, at)
					and not _on_triangles(bed, buckets, Vector2(world.x, world.z))
				):
					off += 1
		assert_eq(off, 0, "cell points off the bed, seed %d" % map_seed)


func test_the_bed_keeps_to_the_road_cells() -> void:
	# the layout valley's road is a diagonal spline over a staircase of cells; its band marks every
	# cell the bed touches as road (#469), so the bed has nothing to poke out of
	for setup in _setups():
		var map: GameMap = setup.map
		var bed := _bed(setup, setup.routes)
		var worst := 0.0
		for i in range(0, bed.size(), 3):
			var a := bed[i]
			var b := bed[i + 1]
			var c := bed[i + 2]
			for at: Vector3 in [
				a, b, c, (a + b + c) / 3.0, (a + b) / 2.0, (b + c) / 2.0, (a + c) / 2.0
			]:
				worst = maxf(worst, _past_the_road(map, at))
		assert_lt(worst, CORNER_TOLERANCE, "the bed leaves the road cells, %s" % setup.label)


func test_the_bed_never_sinks_into_the_gorge() -> void:
	for setup in _setups():
		var bed := _bed(setup, setup.routes)
		var lowest := INF
		for v in bed:
			lowest = minf(lowest, v.y)
		# every road cell and every bank of a bridge is on the valley floor
		assert_gte(lowest, 0.0, setup.label)


func test_the_bridges_stand_on_the_bridge_cells_with_foes_on_their_planks() -> void:
	var seen := 0
	for setup in _setups():
		var map_seed: int = (setup.map as GameMap).seed
		var map: GameMap = setup.map
		var field: TerrainField = setup.field
		var mesh := RoadBedBuilder.bridge_mesh(map, setup.top)
		if map.bridges.is_empty():
			assert_eq(mesh.get_surface_count(), 0, "no bridge without a river, seed %d" % map_seed)
			continue
		seen += map.bridges.size()
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var stray := 0
		for v in vertices:
			var on_one := false
			for bridge in map.bridges:
				if RoadBedBuilder.deck_rect(bridge, map.road_width).grow(0.05).has_point(_sim(v)):
					on_one = true
			stray += 0 if on_one else 1
		assert_eq(stray, 0, "bridge parts off the bridge cells, seed %d" % map_seed)
		for bridge in map.bridges:
			var label := "seed %d bridge %s" % [map_seed, bridge.cell]
			var deck := RoadBedBuilder.deck_rect(bridge, map.road_width)
			assert_true(deck.encloses(Rect2(Vector2(bridge.cell), Vector2.ONE)), label)
			assert_eq(map.tiles[bridge.cell.y][bridge.cell.x], GameMap.Tile.ROAD, label)
			var top := RoadBedBuilder.deck_top(bridge, setup.top)
			assert_almost_eq(
				top, field.surface_height(bridge.cell), 1e-6, "foes stand on the planks"
			)
			# the highest face looking up over the bridge cell's middle is the planks' top
			var middle := Vector2(bridge.cell) + Vector2(0.5, 0.5)
			var along := 0 if bridge.horizontal else 1
			var plank_top := -INF
			for i in vertices.size():
				var off := _sim(vertices[i]) - middle
				var half := RoadDimensions.deck_width(map.road_width) / 2.0
				var on_deck := absf(off[along]) < 0.2 and absf(off[1 - along]) < maxf(0.5, half)
				if normals[i].y > 0.99 and on_deck:
					plank_top = maxf(plank_top, vertices[i].y)
			assert_almost_eq(plank_top, top, 1e-4, label)
	assert_gte(seen, SEEDS.size() + 2 * LAYOUT_SEEDS.size(), "every seed has its road bridge")


func test_a_deck_rests_on_the_higher_bank() -> void:
	var map := Game.create(1).map
	var bridge: GameMap.Bridge = map.bridges[0]
	var step := Vector2i(1, 0) if bridge.horizontal else Vector2i(0, 1)
	var low_bank := bridge.cell - step
	var banks := func(cell: Vector2i) -> float: return 0.2 if cell == low_bank else 0.5
	var top := RoadBedBuilder.deck_top(bridge, banks)
	assert_almost_eq(top, 0.5 + TerrainField.ROAD_HEIGHT, 1e-6)


func test_the_bed_stops_at_the_gorge_and_the_deck_covers_its_ends() -> void:
	for setup in _setups():
		var map_seed: int = (setup.map as GameMap).seed
		var map: GameMap = setup.map
		var bed := _bed(setup, setup.routes)
		var wet := 0
		for v in bed:
			var sim := _sim(v)
			for cell in map.river:
				var inset := Vector2(RIVER_OVERHANG, RIVER_OVERHANG)
				if Rect2(Vector2(cell) + inset, Vector2.ONE - inset * 2.0).has_point(sim):
					wet += 1
		assert_eq(wet, 0, "no bed over the river, seed %d" % map_seed)
		# the bed runs to each bank's edge, under the deck's end, on every road over the bridge
		# (the first and last of a crossing's bridge cells)
		for run in RoadBedBuilder.crossings(map):
			var ends := {-1.0: run[0], 1.0: run[run.size() - 1]}
			for end: float in [-1.0, 1.0]:
				var bridge: GameMap.Bridge = ends[end]
				var along := 0 if bridge.horizontal else 1
				var middle := Vector2(bridge.cell) + Vector2(0.5, 0.5)
				var found := false
				for v in bed:
					var sim := _sim(v)
					var gap := (sim[along] - middle[along]) * end
					var half := maxf(0.5, map.road_width / 2.0)
					if absf(sim[1 - along] - middle[1 - along]) < half and absf(gap - 0.5) < 0.02:
						found = true
						break
				assert_true(found, "the bed reaches the bank, seed %d %s" % [map_seed, bridge.cell])


func test_the_feeder_is_drawn_to_its_join_and_no_further() -> void:
	for map_seed in SEEDS:
		var setup := _setup(map_seed)
		var game: GameState = setup.game
		var map: GameMap = setup.map
		var lines := RoadBedBuilder.centrelines(game.routes)
		assert_eq(lines.size(), game.routes.size(), "one line a route, seed %d" % map_seed)
		var main := _line_of(game.routes[0])
		var feeder := lines[1]
		var end := feeder[feeder.size() - 1]
		# (a curve near the join differs from the main road's by less than the join epsilon)
		var off_main := _distance_to(end, main)
		assert_lt(off_main, LOOKS.JOIN_EPSILON, "it ends on the main road, seed %d" % map_seed)
		# past its run-out (straight, `ROAD_RUN_OUT` long) it is about as long as the feeder from
		# its spawn point to its join cell
		var second := game.routes[1]
		var drawn := -LOOKS.ROAD_RUN_OUT
		for k in feeder.size() - 1:
			drawn += feeder[k].distance_to(feeder[k + 1])
		var to_join := second.cumulative[second.cell_points[map.feeder_length]]
		assert_between(drawn, to_join - 0.5, to_join + 3.0, "seed %d" % map_seed)
		# both roads come out of the haze, past the diorama's margin
		for line in lines:
			assert_gte(_out(map, line[0]), float(TerrainField.MARGIN), "seed %d" % map_seed)


func test_the_lips_open_where_the_feeder_joins_and_round_the_heartstone() -> void:
	for map_seed in SEEDS:
		var setup := _setup(map_seed)
		var game: GameState = setup.game
		var bed := _bed(setup, game.routes)
		var lines := RoadBedBuilder.centrelines(game.routes)
		var join := lines[1][lines[1].size() - 1]
		var round := RoadBedBuilder.heart_yard(game.map, setup.top)
		var yard := Vector2(round.x, round.y)
		var raised := 0
		for v in bed:
			var sim := _sim(v)
			var near_join := sim.distance_to(join) < 0.3
			var in_yard := sim.distance_to(yard) < round.z - LOOKS.LIP_WIDTH
			if (near_join or in_yard) and v.y > LOOKS.BED_LIFT + EPSILON:
				raised += 1
		assert_eq(raised, 0, "no lip across the join or the yard, seed %d" % map_seed)


## The field levels the Heartstone's block with the road, so the yard fills the block; where a
## block stands on two terraces it shrinks to a round end in the road's last cell.
func test_the_heartstone_yard_keeps_to_the_road_level() -> void:
	var setup := _setup(1)
	var map: GameMap = setup.map
	var block := map.heartstone
	var last := map.path[map.path.size() - 1]
	var levelled := RoadBedBuilder.heart_yard(map, setup.top)
	assert_eq(Vector2(levelled.x, levelled.y), Vector2(block.position) + Vector2(block.size) / 2.0)
	assert_almost_eq(levelled.z, LOOKS.HEART_YARD_RADIUS, 1e-5)
	var terraced := func(cell: Vector2i) -> float: return float(map.height_at(cell)) * 0.75
	var capped := RoadBedBuilder.heart_yard(map, terraced)
	if map.height_at(block.position + Vector2i(0, 1)) != map.height_at(last):
		assert_eq(Vector2(capped.x, capped.y), Vector2(last) + Vector2(0.5, 0.5))
		assert_almost_eq(capped.z, LOOKS.HEART_CAP_RADIUS, 1e-5)
	var routes := (setup.game as GameState).routes
	var bed := RoadBedBuilder.bed_mesh(map, routes, terraced)
	for v: Vector3 in bed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var sim := _sim(v)
		var cell := Vector2i(floori(sim.x), floori(sim.y))
		if block.has_point(cell):
			assert_lt(v.y, float(map.height_at(cell)) * 0.75 + 0.04, "no yard on the terrace")


func test_it_stands_on_the_terrain_it_is_given() -> void:
	var game := Game.create(3)
	var high := func(_cell: Vector2i) -> float: return 1.5
	var bed := RoadBedBuilder.bed_mesh(game.map, game.routes, high)
	for v: Vector3 in bed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_between(v.y, 1.5, 1.5 + LOOKS.BED_LIFT + LOOKS.LIP_HEIGHT + EPSILON)
	# the bed lies under where the foes walk; only its lips rise above
	assert_lt(LOOKS.BED_LIFT, TerrainField.ROAD_HEIGHT)


func test_a_bridge_over_the_gorge_gets_trestle_legs_to_its_floor() -> void:
	for setup: Dictionary in [_setup(1), _layout(1), _layout(259)]:
		var map: GameMap = setup.map
		var flat := RoadBedBuilder.bridge_mesh(map, _flat)
		var deep := RoadBedBuilder.bridge_mesh(map, setup.top)
		assert_gt(_triangles(deep), _triangles(flat), "legs added, " + setup.label)
		# the legs reach the floor; a post whose corner of the bank the river bites into stands
		# on the floor too, sunk a little into it
		var floor_y := TerrainField.GORGE_FLOOR
		assert_between(_lowest(deep), floor_y - 0.06, floor_y + 0.03, setup.label)
		assert_gt(_lowest(flat), -0.1)
		# a bent of legs stands in every bridge cell's gorge
		var vertices: PackedVector3Array = deep.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for bridge in map.bridges:
			var feet := 0
			for v in vertices:
				var sim := _sim(v)
				# legs stand out across the road, in the cells beside the bridge cell
				var along := 0 if bridge.horizontal else 1
				var across := absf(sim[1 - along] - (float(bridge.cell[1 - along]) + 0.5))
				var in_bent := floori(sim[along]) == bridge.cell[along]
				var reach := RoadDimensions.trestle_out(map.road_width) + 0.5
				if in_bent and across < reach and v.y < TerrainField.GORGE_FLOOR + 0.05:
					feet += 1
			assert_gt(feet, 0, "legs in %s, %s" % [bridge.cell, setup.label])


## Over a river two cells wide the deck rests on the banks past both bridge cells, so every
## cell of the crossing has the same deck top, on the banks' level.
func test_a_crossing_of_several_cells_rests_on_the_banks_past_it() -> void:
	var setup := _layout(1)
	var map: GameMap = setup.map
	var run: Array = RoadBedBuilder.crossings(map)[0]
	for bridge: GameMap.Bridge in run:
		assert_almost_eq(RoadBedBuilder.deck_top(bridge, setup.top), TerrainField.ROAD_HEIGHT, 1e-6)
	var first: GameMap.Bridge = run[0]
	var step := Vector2i(1, 0) if first.horizontal else Vector2i(0, 1)
	var high_bank := first.cell - step
	var banks := func(cell: Vector2i) -> float:
		if cell == high_bank:
			return 0.75
		return float(setup.top.call(cell))
	for bridge: GameMap.Bridge in run:
		assert_almost_eq(
			RoadBedBuilder.deck_top(bridge, banks), 0.75 + TerrainField.ROAD_HEIGHT, 1e-6
		)


func test_every_triangle_faces_up_or_out() -> void:
	for setup: Dictionary in [_setup(1), _setup(259), _layout(1), _layout(259)]:
		var map_seed: int = (setup.map as GameMap).seed
		var map: GameMap = setup.map
		var arrays := RoadBedBuilder.bed_mesh(map, setup.routes, setup.top).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var wrong := 0
		for i in range(0, vertices.size(), 3):
			var normal := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i])
			# Godot's front faces are clockwise: seen from above, the cross product points down
			if normal.length() > 1e-9 and normal.y >= 0.0:
				wrong += 1
		assert_eq(wrong, 0, "bed triangles wound away from the sky, seed %d" % map_seed)
		assert_eq(_wrongly_wound(arrays), 0, "and against their normals, seed %d" % map_seed)
		var bridges := RoadBedBuilder.bridge_mesh(map, setup.top).surface_get_arrays(0)
		assert_eq(_wrongly_wound(bridges), 0, "bridge facets wound inward, seed %d" % map_seed)


func test_the_same_map_draws_the_same_road() -> void:
	var setup := _setup(42)
	var game: GameState = setup.game
	var first := RoadBedBuilder.bed_mesh(game.map, game.routes, setup.top)
	var second := RoadBedBuilder.bed_mesh(game.map, game.routes, setup.top)
	assert_eq(
		first.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		second.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var a := RoadBedBuilder.bridge_mesh(game.map, setup.top)
	var b := RoadBedBuilder.bridge_mesh(game.map, setup.top)
	assert_eq(
		a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)


## Two meshes of one surface each, whatever the map: two draw calls (plus the bridges' shadow).
func test_the_road_is_two_draw_calls_and_a_few_thousand_triangles() -> void:
	var most_bed := 0
	var most_bridges := 0
	for setup in _setups():
		var root := RoadBedBuilder.build(setup.map, setup.routes, setup.top)
		assert_eq(root.get_child_count(), 2)
		var bed: Mesh = (root.get_node("RoadBed") as MeshInstance3D).mesh
		var bridges: Mesh = (root.get_node("Bridges") as MeshInstance3D).mesh
		assert_eq(bed.get_surface_count(), 1)
		assert_lte(bridges.get_surface_count(), 1)
		most_bed = maxi(most_bed, _triangles(bed))
		most_bridges = maxi(most_bridges, _triangles(bridges))
		root.free()
	gut.p("most triangles: bed %d, bridges %d" % [most_bed, most_bridges])
	assert_lt(most_bed, 5500, "the bed fits the terrain and road budget")
	# the layout valley draws two bridges since the fork's second lane (#481): 1,636 at most
	assert_lt(most_bridges, 2500, "the bridges fit it too")


func test_the_diorama_slot_draws_the_road_from_the_field() -> void:
	var setup := _setup(259)
	var slot := RoadBedSlot.new()
	add_child_autofree(slot)
	slot.build(setup.field)
	assert_not_null(slot.get_node_or_null("RoadBed"))
	assert_not_null(slot.get_node_or_null("Bridges"))
	assert_eq(slot.surfaces, 2)
	assert_gt(slot.triangles, 1000)
	assert_false("material" in slot, "the slot keeps its own looks")


## How many points along the routes (route points and points between them) lie neither on a bed
## triangle nor on a bridge's planks.
func _off_bed(setup: Dictionary, routes: Array[Route]) -> int:
	var map: GameMap = setup.map
	var bed := _bed(setup, routes)
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


## True on a bridge's planks: from one end of the deck to the other, edge to edge.
func _on_deck(map: GameMap, at: Vector2) -> bool:
	for bridge in map.bridges:
		var deck := RoadBedBuilder.deck_rect(bridge, map.road_width)
		var trim := deck.size.y / 2.0 - LOOKS.DECK_WIDTH / 2.0
		var walk := deck.grow_individual(0.0, -trim, 0.0, -trim)
		if not bridge.horizontal:
			trim = deck.size.x / 2.0 - LOOKS.DECK_WIDTH / 2.0
			walk = deck.grow_individual(-trim, 0.0, -trim, 0.0)
		if walk.has_point(at):
			return true
	return false


## The bed's triangles as a flat list of their corners, on the field's tops.
func _bed(setup: Dictionary, routes: Array[Route]) -> PackedVector3Array:
	var mesh := RoadBedBuilder.bed_mesh(setup.map, routes, setup.top)
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


## How far a bed point lies outside every cell it may be on (a road cell, any cell off the board,
## the Heartstone's block): 0 inside one, else the distance to the nearest.
func _past_the_road(map: GameMap, at: Vector3) -> float:
	var sim := _sim(at)
	var cell := Vector2i(floori(sim.x), floori(sim.y))
	if not map.in_bounds(cell) or map.heartstone.has_point(cell) or _road(map, cell):
		return 0.0
	var best := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, dy)
			if map.in_bounds(near) and not _road(map, near) and not map.heartstone.has_point(near):
				continue
			var rect := Rect2(Vector2(near), Vector2.ONE)
			best = minf(best, sim.distance_to(sim.clamp(rect.position, rect.end)))
	return best


func _road(map: GameMap, cell: Vector2i) -> bool:
	return map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD


## A world point back in sim cells.
func _sim(at: Vector3) -> Vector2:
	var origin := BoardSpace.point_to_world(0.0, 0.0)
	return Vector2(at.x - origin.x, at.z - origin.z)


## How far a point lies outside the board (cells, 0 on it), along the nearer axis's gap.
func _out(map: GameMap, at: Vector2) -> float:
	var dx := maxf(maxf(-at.x, at.x - float(map.cols)), 0.0)
	var dy := maxf(maxf(-at.y, at.y - float(map.rows)), 0.0)
	return maxf(dx, dy)


func _line_of(route: Route) -> PackedVector2Array:
	var line := PackedVector2Array()
	for i in route.xs.size():
		line.append(Vector2(route.xs[i], route.ys[i]))
	return line


func _distance_to(point: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for k in line.size() - 1:
		var closest := Geometry2D.get_closest_point_to_segment(point, line[k], line[k + 1])
		best = minf(best, point.distance_to(closest))
	return best


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


## How many facets of an unindexed surface are wound with their front away from their normal
## (Godot's front faces are clockwise seen from the side the normal points to).
func _wrongly_wound(arrays: Array) -> int:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var wrong := 0
	for i in range(0, vertices.size(), 3):
		var turn := (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i])
		if turn.dot(normals[i]) >= 0.0:
			wrong += 1
	return wrong


func _lowest(mesh: Mesh) -> float:
	var low := INF
	for v: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		low = minf(low, v.y)
	return low


func _triangles(mesh: Mesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


func test_the_bed_is_as_wide_as_the_maps_road_width() -> void:
	assert_eq(LOOKS.ROAD_WIDTH, GameMap.new().road_width, "the old boards keep their look")
	var s := _setup(1)
	var map: GameMap = s["map"]
	var narrow := RoadBedBuilder.bed_mesh(map, s["game"].routes, s["top"]).get_aabb()
	map.road_width = 2.4
	var wide := RoadBedBuilder.bed_mesh(map, s["game"].routes, s["top"]).get_aabb()
	assert_gt(wide.get_volume(), 0.0)
	assert_gt(wide.size.x * wide.size.z, narrow.size.x * narrow.size.z, "a wider bed spreads out")
	# the bed vertices reach half the width (plus the lip) from the centre line
	var vertices: PackedVector3Array = (
		RoadBedBuilder
		. bed_mesh(map, s["game"].routes, s["top"])
		. surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	var line := RoadBedBuilder.centrelines(s["game"].routes)[0]
	var far := 0.0
	for v in vertices:
		far = maxf(far, RoadBedBuilder._distance_to_line(Vector2(v.x, v.z), _world_line(line)))
	assert_gt(far, 2.4 / 2.0 - 0.05)


func _world_line(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in line:
		var w := BoardSpace.point_to_world(p.x, p.y)
		out.append(Vector2(w.x, w.z))
	return out
