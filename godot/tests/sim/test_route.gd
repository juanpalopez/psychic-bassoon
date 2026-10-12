## Routes: the line foes walk, from the spawn point through every path cell.
extends GutTest

const RULES := preload("res://content/map_rules.gd")
const EPSILON := 1e-9
const FIXTURE := "res://../fixtures/routes.json"


func _straight_down(length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for row in length:
		cells.append(Vector2i(3, row))
	return cells


func test_route_starts_above_the_first_cell() -> void:
	var route := Route.build(_straight_down(3))
	assert_eq(route.xs[0], 3.5)
	assert_eq(route.ys[0], -0.45)
	assert_eq(route.xs[1], 3.5)
	assert_eq(route.ys[1], 0.5)


func test_cumulative_distance_adds_the_spawn_gap_and_one_per_step() -> void:
	var route := Route.build(_straight_down(4))
	assert_eq(route.cumulative[0], 0.0)
	assert_almost_eq(route.cumulative[1], 0.95, EPSILON)
	assert_almost_eq(route.total, 0.95 + 3.0, EPSILON)


func test_every_generated_route_has_the_expected_length() -> void:
	for seed in range(1, 60):
		var map := MapGen.generate(seed, RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		for cells in map.routes:
			var route := Route.build(cells)
			assert_almost_eq(route.total, 0.95 + float(cells.size() - 1), EPSILON, "seed %d" % seed)
			assert_eq(route.xs.size(), cells.size() + 1)


func test_position_at_walks_along_the_route() -> void:
	var route := Route.build(_straight_down(4))
	var start := route.position_at(0.0)
	assert_eq(start.x, 3.5)
	assert_eq(start.y, -0.45)
	var middle := route.position_at(0.95 + 1.5)
	assert_almost_eq(middle.y, 0.5 + 1.5, EPSILON)
	var end := route.position_at(1000.0)
	assert_almost_eq(end.y, 3.5, EPSILON)
	var before := route.position_at(-5.0)
	assert_eq(before.y, -0.45)


func test_route_needs_at_least_one_cell() -> void:
	var route := Route.build([] as Array[Vector2i])
	assert_null(route)
	assert_push_error("a route needs at least one cell")


func _bits_hex(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var hex := ""
	for i in range(7, -1, -1):
		hex += "%02x" % bytes[i]
	return hex


func _from_bits(hex: String) -> float:
	var bytes := PackedByteArray()
	bytes.resize(8)
	for i in 8:
		bytes[7 - i] = ("0x" + hex.substr(i * 2, 2)).hex_to_int()
	return bytes.decode_double(0)


func _bits_of(values: PackedFloat64Array) -> Array:
	var out := []
	for value in values:
		out.append(_bits_hex(value))
	return out


func test_routes_match_the_typescript_bits() -> void:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURE))
	var entries: Array = JSON.parse_string(text)
	assert_eq(entries.size(), 12)
	for entry in entries:
		var map := MapGen.generate(int(entry.seed), RULES.LEGACY_COLS, RULES.LEGACY_ROWS, true, 1)
		assert_eq(map.routes.size(), entry.routes.size(), "route count, seed %d" % entry.seed)
		for r in entry.routes.size():
			var want: Dictionary = entry.routes[r]
			var route := Route.build(map.routes[r])
			var label := "seed %d route %d" % [entry.seed, r]
			assert_eq(_bits_of(route.xs), want.xs, "xs, " + label)
			assert_eq(_bits_of(route.ys), want.ys, "ys, " + label)
			assert_eq(_bits_of(route.cumulative), want.cumulative, "cumulative, " + label)
			assert_eq(_bits_hex(route.total), want.total, "total, " + label)
			for sample in want.samples:
				var at := route.position_at(_from_bits(sample[0]))
				assert_eq(_bits_hex(at.x), sample[1], "x at %s, %s" % [sample[0], label])
				assert_eq(_bits_hex(at.y), sample[2], "y at %s, %s" % [sample[0], label])
