## The routes foes walk on a map, as the game and the diorama both build them (`Route.for_map`,
## #461), and where a road that enters from the board's east edge spawns: past that edge on the
## road's own row, so nobody walks over the cells above it (the layout valley's feeder may start
## on the east edge, #411).
extends GutTest

const RULES := preload("res://content/map_rules.gd")
## Layout valley seeds on the 40 by 24 board (#480); the feeder starts on the top row there, and the
## test holds wherever a start is.
const LAYOUT_SEEDS: Array[int] = [1, 2, 3, 5, 6, 8, 10, 11]
## Sub-points checked on the stretch from the spawn point to the first cell.
const SUBSTEPS := 16


func test_the_game_walks_the_routes_for_its_map() -> void:
	for map_seed in [1, 2, 3]:
		var game := Game.create(map_seed)
		_assert_same(Route.for_map(game.map), game.routes, "game board, seed %d" % map_seed)
	var classic := Game.create(4, 16, 11)
	_assert_same(Route.for_map(classic.map), classic.routes, "classic board")


func test_the_layout_valley_is_the_layout_stitched_with_its_regions() -> void:
	for map_seed in [1, 42, 2026]:
		var layout := ValleyLayout.generate(
			map_seed, ValleyLayout.LAYOUT.COLS, ValleyLayout.LAYOUT.ROWS
		)
		var expected := ValleyStitcher.build(
			map_seed,
			ValleyLayout.LAYOUT.COLS,
			ValleyLayout.LAYOUT.ROWS,
			ValleyLayout.sections(),
			layout
		)
		var map := MapGen.generate_layout_valley(map_seed)
		assert_eq(map.path, expected.path, "seed %d road" % map_seed)
		assert_eq(map.sockets, expected.sockets, "seed %d sockets" % map_seed)
		assert_eq(map.routes, expected.routes, "seed %d routes" % map_seed)


func test_a_road_from_the_east_edge_spawns_past_it_on_its_row() -> void:
	var cells: Array[Vector2i] = [Vector2i(9, 3), Vector2i(9, 4), Vector2i(8, 4)]
	var curve := RoadCurve.from_cells(cells)
	var route := Route.build_from_curve(cells, curve, 10)
	assert_eq(Vector2(route.xs[0], route.ys[0]), Vector2(10.0 + RULES.SPAWN_OFFSET, 3.5))
	# a road on the top row still comes down from above, and without the board's width the
	# spawn is where it always was
	var top: Array[Vector2i] = [Vector2i(9, 0), Vector2i(9, 1)]
	var down := Route.build_from_curve(top, RoadCurve.from_cells(top), 10)
	assert_eq(Vector2(down.xs[0], down.ys[0]), Vector2(9.5, -RULES.SPAWN_OFFSET))
	var unknown := Route.build_from_curve(cells, curve)
	assert_eq(Vector2(unknown.xs[0], unknown.ys[0]), Vector2(9.5, -RULES.SPAWN_OFFSET))


func test_foes_reach_the_first_road_cell_only_over_road_or_off_the_board() -> void:
	for map_seed in LAYOUT_SEEDS:
		var map := MapGen.generate_layout_valley(map_seed)
		var routes := Route.for_map(map)
		for index in routes.size():
			var route := routes[index]
			var first := route.cell_points[0]
			for p in first:
				for s in SUBSTEPS:
					var t := float(s) / float(SUBSTEPS)
					var x := route.xs[p] + (route.xs[p + 1] - route.xs[p]) * t
					var y := route.ys[p] + (route.ys[p + 1] - route.ys[p]) * t
					var cell := Vector2i(floori(x), floori(y))
					var fine := (
						not map.in_bounds(cell) or map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD
					)
					assert_true(fine, "seed %d route %d walks over %s" % [map_seed, index, cell])


func _assert_same(got: Array[Route], want: Array[Route], label: String) -> void:
	assert_eq(got.size(), want.size(), label)
	for i in mini(got.size(), want.size()):
		assert_eq(got[i].xs, want[i].xs, "%s route %d" % [label, i])
		assert_eq(got[i].ys, want[i].ys, "%s route %d" % [label, i])
		assert_eq(got[i].cell_points, want[i].cell_points, "%s route %d" % [label, i])
