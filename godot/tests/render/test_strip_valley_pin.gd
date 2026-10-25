## The strip valley, which has no fork and no road band, keeps drawing exactly as it did (#523,
## #461): its road bed and bridges are pinned by a hash of their vertices (to a ten thousandth of
## a cell, so a last-bit difference in a float function on another platform does not move it),
## and its scatter by the count of its props and their triangles. Whoever changes the bed's default
## branch (`RoadBedBuilder._thin`, the ribbon, the clip at a bridge) or the scatter must change
## these on purpose, in a reviewed render change. Seed 259 has a second bridge, on the feeder.
extends GutTest

## seed -> [bed vertices, bed hash, bridge vertices, bridge hash, props, scatter triangles]
const PINS := {
	1:
	[
		12870,
		"f30f48459515ad3f5cf8fa57b530e765879cedf0e4556997352511c251548581",
		1500,
		"d7089cd942e95133461e74624e7f183135fc4c976f8ce5c341dfa68c445942fb",
		2689,
		24911,
	],
	259:
	[
		13920,
		"4d4fdeb2968a4e3ec9e759881bee01f9e1f628d83b0834ae5e93f3ebd2683550",
		1500,
		"8a243dbb4a2bae3bf36acd624c0c8a97cb35eaa6291c0b48590d72f5bc097237",
		2717,
		24626,
	],
}

## Planks to a crossing on the layout valley, where a crossing is two or three cells long (on the
## strip valley's one cell crossings the rounding of the plank count cannot show).
## seed -> plank tops counted inside each crossing's deck, in `RoadBedBuilder.crossings` order (a
## plank on the deck's edge may not count, so these are pins, not the plank counts themselves).
const PLANKS := {1: [23, 16], 2: [16, 16], 5: [16, 16]}


## The game board is the layout valley since #458; the pins below name the strip valley, which
## `Game.create_on_strip_valley` (and `--strip-valley`) still plays.
func test_the_game_board_is_the_layout_valley_and_not_the_pinned_strip() -> void:
	for map_seed: int in PINS:
		var board := Game.create(map_seed).map
		var layout := MapGen.generate_layout_valley(map_seed)
		var label := "seed %d" % map_seed
		assert_eq([board.cols, board.rows], [40, 24], label)
		assert_eq(board.routes, layout.routes, label + ": routes")
		assert_eq(board.sockets, layout.sockets, label + ": sockets")


func test_a_layout_crossing_has_the_planks_it_had() -> void:
	for map_seed: int in PLANKS:
		var map := MapGen.generate_layout_valley(map_seed)
		var field := TerrainField.from_map(map)
		var top := Callable(field, "top_at")
		var arrays := RoadBedBuilder.bridge_mesh(map, top).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var origin := BoardSpace.point_to_world(0.0, 0.0)
		var found: Array[int] = []
		for run: Array in RoadBedBuilder.crossings(map):
			var first: GameMap.Bridge = run[0]
			var deck := RoadBedBuilder.deck_rect(first, map.road_width)
			for bridge: GameMap.Bridge in run:
				deck = deck.merge(RoadBedBuilder.deck_rect(bridge, map.road_width))
			var height := RoadBedBuilder.deck_top(first, top)
			var corners := 0
			for i in vertices.size():
				var sim := Vector2(vertices[i].x - origin.x, vertices[i].z - origin.z)
				if (
					normals[i].y > 0.99
					and absf(vertices[i].y - height) < 1e-4
					and deck.has_point(sim)
				):
					corners += 1
			# a plank's top is two triangles
			found.append(int(corners / 6.0))
		assert_eq(found, PLANKS[map_seed], "planks per crossing, layout seed %d" % map_seed)


func test_the_strip_valley_draws_its_road_bed_and_bridges_as_pinned() -> void:
	for map_seed: int in PINS:
		var pin: Array = PINS[map_seed]
		var game := Game.create_on_strip_valley(map_seed)
		assert_true(game.map.forks.is_empty(), "no fork, seed %d" % map_seed)
		assert_eq(game.map.reach_band, 0.0, "no road band, seed %d" % map_seed)
		var field := TerrainField.from_map(game.map, game.routes)
		var top := Callable(field, "top_at")
		var bed := _digest(RoadBedBuilder.bed_mesh(game.map, game.routes, top))
		assert_eq(bed, [pin[0], pin[1]], "road bed, seed %d" % map_seed)
		var bridges := _digest(RoadBedBuilder.bridge_mesh(game.map, top))
		assert_eq(bridges, [pin[2], pin[3]], "bridges, seed %d" % map_seed)


func test_the_strip_valley_scatters_the_props_it_did() -> void:
	for map_seed: int in PINS:
		var pin: Array = PINS[map_seed]
		var game := Game.create_on_strip_valley(map_seed)
		var field := TerrainField.from_map(game.map, game.routes)
		var props := 0
		var triangles := 0
		for placement in SceneryScatter.placements(field):
			props += 1
			var light := not SceneryScatter.MIDDLE.has(placement.chunk)
			triangles += SceneryProps.triangles(placement.kind, light)
		assert_eq([props, triangles], [pin[4], pin[5]], "scatter, seed %d" % map_seed)


## The vertex count and the SHA-256 of the first surface's vertices in ten thousandths of a cell.
func _digest(mesh: ArrayMesh) -> Array:
	var rounded := PackedInt32Array()
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in vertices:
		rounded.append(roundi(v.x * 10000.0))
		rounded.append(roundi(v.y * 10000.0))
		rounded.append(roundi(v.z * 10000.0))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(rounded.to_byte_array())
	return [vertices.size(), hashing.finish().hex_encode()]
