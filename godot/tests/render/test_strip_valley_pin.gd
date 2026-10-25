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
