## The diorama on the forked layout valley (#481): the road forks at the Sunken Meadow and rejoins
## after the Crossing, so two crossings are drawn, each with its deck, the scatter keeps off both
## decks, the road bed covers the lower lane, and the terrain, scenery and surface caps still hold.
extends GutTest

const RULES := preload("res://content/valley/bluewater_region_rules.gd")
const DIORAMA_TEST := preload("res://tests/render/test_diorama.gd")
## A handful of layout seeds, seeds 124, 22 and 17 the ones nearest the terrain cap (#523: 135, 508
## and 572 triangles under it on seeds 1 to 200, as the forked bed is thinned).
const SEEDS: Array[int] = [1, 2, 3, 5, 7, 17, 22, 124]
## Points checked on each stretch between two route points.
const SUBSTEPS := 4
## How far the forked map's thinner bed may drift from the finer centreline (cells).
const BED_DEVIATION := 0.05


func after_each() -> void:
	BoardSpace.reset()


func _layout_board(map_seed: int) -> Board:
	var board := Board.new()
	board.build_on_ready = false
	add_child_autofree(board)
	board.show_map(MapGen.generate_layout_valley(map_seed))
	return board


func test_two_crossings_are_drawn_one_on_each_lane() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var map := board.map
		var label := "layout seed %d" % map_seed
		var runs := RoadBedBuilder.crossings(map)
		assert_eq(runs.size(), 2, label + ": two crossings")
		var lanes := {}
		var decks: Array[Rect2] = []
		for run: Array in runs:
			var first: GameMap.Bridge = run[0]
			lanes[first.route] = true
			for bridge: GameMap.Bridge in run:
				assert_eq(bridge.route, first.route, label + ": one lane per crossing")
				assert_false(map.hero_bridges.has(bridge.cell), label + ": no hero-only bridge")
			var deck := RoadBedBuilder.deck_rect(first, map.road_width)
			for bridge: GameMap.Bridge in run:
				deck = deck.merge(RoadBedBuilder.deck_rect(bridge, map.road_width))
			decks.append(deck)
		assert_eq(lanes.size(), 2, label + ": a crossing on each lane")
		assert_true(lanes.has(0), label + ": the main road is bridged")
		assert_false(decks[0].intersects(decks[1]), label + ": the decks are apart")
		assert_gte(
			absf(decks[0].get_center().y - decks[1].get_center().y),
			float(RULES.HERO_BRIDGE_MIN_ROW_GAP),
			label + ": at least the gap between the crossings"
		)
		_check_planks(board, runs, label)


## The Bridges surface has upward planks over each crossing's walkway.
func _check_planks(board: Board, runs: Array[Array], label: String) -> void:
	var map := board.map
	var arrays := (
		RoadBedBuilder
		. bridge_mesh(map, Callable(board.diorama.field, "top_at"))
		. surface_get_arrays(0)
	)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for run: Array in runs:
		var bridge: GameMap.Bridge = run[0]
		var deck := RoadBedBuilder.deck_rect(bridge, map.road_width)
		var planks := 0
		for i in range(0, vertices.size(), 3):
			if normals[i].y > 0.99 and deck.has_point(_sim(vertices[i])):
				planks += 1
		assert_gt(planks, 0, "%s: planks over the lane %d crossing" % [label, bridge.route])


func test_the_scatter_keeps_off_both_decks() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var map := board.map
		var decks: Array[Rect2] = []
		for bridge in map.bridges:
			decks.append(RoadBedBuilder.deck_rect(bridge, map.road_width))
		for placement in SceneryScatter.placements(board.diorama.field):
			for deck in decks:
				assert_false(
					deck.has_point(placement.at),
					"layout seed %d: %s at %s on a deck" % [map_seed, placement.kind, placement.at]
				)


func test_the_road_bed_covers_the_lower_lane() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var map := board.map
		var field := board.diorama.field
		var label := "layout seed %d" % map_seed
		assert_eq(map.routes.size(), field.routes.size(), label)
		var corners: PackedVector3Array = (
			RoadBedBuilder
			. bed_mesh(map, field.routes, Callable(field, "top_at"))
			. surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		var buckets := _buckets(corners)
		for fork in map.forks:
			var route: Route = field.routes[fork.route]
			var cells: Array[Vector2i] = map.routes[fork.route]
			var own := 0
			var off := 0
			# the branch's own cells: between the fork and the merge, off the main road
			for p in route.xs.size():
				var at := Vector2(route.xs[p], route.ys[p])
				if map.path.has(Vector2i(floori(at.x), floori(at.y))) or _on_deck(map, at):
					continue
				own += 1
				for s in SUBSTEPS:
					var q := mini(p + 1, route.xs.size() - 1)
					var t := float(s) / float(SUBSTEPS)
					var between := Vector2(
						at.x + (route.xs[q] - at.x) * t, at.y + (route.ys[q] - at.y) * t
					)
					var world := BoardSpace.point_to_world(between.x, between.y)
					if not _on_triangles(corners, buckets, Vector2(world.x, world.z)):
						if not _on_deck(map, between):
							off += 1
			assert_gt(own, 0, label + ": the lane has cells of its own")
			assert_gt(cells.size(), 0)
			assert_eq(off, 0, label + ": points of the lower lane off the bed")


func test_the_thinner_bed_stays_within_a_twentieth_of_a_cell_of_the_finer_line() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var fine := RoadBedBuilder.centrelines(board.diorama.field.routes, false)
		var coarse := RoadBedBuilder.centrelines(board.diorama.field.routes, true)
		var worst := 0.0
		var points_fine := 0
		var points_coarse := 0
		for line in fine:
			points_fine += line.size()
			for point in line:
				var best := INF
				for other in coarse:
					for k in other.size() - 1:
						var near := Geometry2D.get_closest_point_to_segment(
							point, other[k], other[k + 1]
						)
						best = minf(best, point.distance_to(near))
				worst = maxf(worst, best)
		for line in coarse:
			points_coarse += line.size()
		gut.p(
			(
				"layout seed %d: bed line %d points, was %d; deviation %.4f cells"
				% [map_seed, points_coarse, points_fine, worst]
			)
		)
		assert_lte(worst, BED_DEVIATION, "layout seed %d" % map_seed)
		assert_lt(points_coarse, points_fine, "layout seed %d: fewer points" % map_seed)


## The scatter keeps off the bed as it is drawn: the forked map's thinner (coarse) line, which lies
## up to 0.043 cell from the finer one the scatter keeps off (#523). A prop's footprint never
## reaches the bed's edge, wobble and keep-off left aside.
func test_the_scatter_keeps_clear_of_the_coarse_bed_edge() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var map := board.map
		var field := board.diorama.field
		var segments: Array[PackedVector2Array] = []
		for line in RoadBedBuilder.centrelines(field.routes, true):
			for k in line.size() - 1:
				segments.append(PackedVector2Array([line[k], line[k + 1]]))
		var half := map.road_width / 2.0
		var worst := INF
		for placement in SceneryScatter.placements(field):
			var nearest := INF
			for segment in segments:
				var closest := Geometry2D.get_closest_point_to_segment(
					placement.at, segment[0], segment[1]
				)
				nearest = minf(nearest, placement.at.distance_to(closest))
			worst = minf(worst, nearest - half - placement.radius)
			assert_gt(
				nearest - half,
				placement.radius,
				(
					"layout seed %d: %s at %s reaches the bed"
					% [map_seed, placement.kind, placement.at]
				)
			)
		gut.p(
			(
				"layout seed %d: scatter clear of the coarse bed edge by at least %.3f"
				% [map_seed, worst]
			)
		)


func test_the_forked_valley_keeps_to_the_diorama_budgets() -> void:
	for map_seed in SEEDS:
		var board := _layout_board(map_seed)
		var diorama := board.diorama
		var terraces := diorama.builder("Terraces")
		var ground: int = (
			terraces.triangles
			+ diorama.builder("Water").triangles
			+ diorama.builder("RoadBeds").triangles
		)
		var label := "layout seed %d" % map_seed
		var scatter: int = diorama.builder("Scatter").triangles
		(
			gut
			. p(
				(
					"%s: terrain and road beds %d of %d (headroom %d), scatter %d of %d, surfaces %d of %d"
					% [
						label,
						ground,
						DIORAMA_TEST.TERRAIN_TRIANGLES,
						DIORAMA_TEST.TERRAIN_TRIANGLES - ground,
						scatter,
						DIORAMA_TEST.SCENERY_TRIANGLES,
						diorama.surface_count(),
						DIORAMA_TEST.LAYOUT_SURFACES,
					]
				)
			)
		)
		assert_lte(ground, DIORAMA_TEST.TERRAIN_TRIANGLES, label + ": terrain and road beds")
		assert_lte(scatter, DIORAMA_TEST.SCENERY_TRIANGLES, label + ": scenery")
		assert_lte(diorama.surface_count(), DIORAMA_TEST.LAYOUT_SURFACES, label + ": surfaces")


## A world point back in sim cells.
func _sim(at: Vector3) -> Vector2:
	var origin := BoardSpace.point_to_world(0.0, 0.0)
	return Vector2(at.x - origin.x, at.z - origin.z)


## True on a bridge's deck.
func _on_deck(map: GameMap, at: Vector2) -> bool:
	for bridge in map.bridges:
		if RoadBedBuilder.deck_rect(bridge, map.road_width).has_point(at):
			return true
	return false


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
