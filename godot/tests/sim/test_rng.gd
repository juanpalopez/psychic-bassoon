## The GDScript PRNG must match the TypeScript fixtures exactly.
extends GutTest

const FIXTURE := "res://../fixtures/prng.json"
const BOUND := 6
const RANGE_MIN := 0.8
const RANGE_MAX := 3.2


func _fixtures() -> Array:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(FIXTURE))
	return JSON.parse_string(text)


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


func test_json_float_parsing_is_not_bit_exact() -> void:
	# Godot's JSON parser can misround the last bit of a float. So the fixture
	# floats are only checked within a tiny tolerance, and exact comparisons use
	# floatBits. Fixtures that carry floats without bits need the same care.
	var inexact := 0
	for entry in _fixtures():
		for i in entry.floats.size():
			var exact := _from_bits(entry.floatBits[i])
			assert_almost_eq(entry.floats[i], exact, 1e-15)
			if _bits_hex(entry.floats[i]) != entry.floatBits[i]:
				inexact += 1
	assert_gt(inexact, 0, "if this fails the parser is exact: simplify the tests")


func test_next_float_matches_the_fixture() -> void:
	for entry in _fixtures():
		var rng := Rng.create(int(entry.seed))
		for i in entry.floats.size():
			assert_eq(
				_bits_hex(rng.next_float()), entry.floatBits[i], "seed %d draw %d" % [entry.seed, i]
			)


func test_next_int_matches_the_fixture() -> void:
	for entry in _fixtures():
		var rng := Rng.create(int(entry.seed))
		for i in entry.ints6.size():
			assert_eq(rng.next_int(BOUND), int(entry.ints6[i]), "seed %d draw %d" % [entry.seed, i])


func test_next_range_matches_the_fixture() -> void:
	for entry in _fixtures():
		# the range draws use the same stream as the floats, so the exact
		# expected value comes from the float bits, not from the parsed text
		var rng := Rng.create(int(entry.seed))
		for i in entry.ranges.size():
			var unit := _from_bits(entry.floatBits[i])
			var expected := RANGE_MIN + unit * (RANGE_MAX - RANGE_MIN)
			var got := rng.next_range(RANGE_MIN, RANGE_MAX)
			assert_eq(_bits_hex(got), _bits_hex(expected), "seed %d draw %d" % [entry.seed, i])
			assert_almost_eq(got, float(entry.ranges[i]), 1e-12)


func test_derive_matches_the_fixture() -> void:
	for entry in _fixtures():
		for derived in entry.derived:
			var rng := Rng.derive(int(entry.seed), int(derived.stream))
			assert_eq(
				rng.state, int(derived.state), "seed %d stream %d" % [entry.seed, derived.stream]
			)


func test_stream_ids_are_frozen() -> void:
	assert_eq(Streams.MAP, 0)
	assert_eq(Streams.WAVES, 1)
	assert_eq(Streams.ROUTES, 2)
	assert_eq(Streams.SCENERY, 100)


func test_negative_seed_wraps_to_32_bits() -> void:
	assert_eq(Rng.create(-1).state, 4294967295)


func test_clone_continues_independently() -> void:
	var rng := Rng.create(42)
	rng.next_float()
	var copy := rng.clone()
	assert_eq(copy.next_float(), rng.next_float())
	copy.next_float()
	assert_ne(copy.state, rng.state)


func test_next_int_stays_in_bounds() -> void:
	var rng := Rng.create(7)
	for i in 1000:
		var value := rng.next_int(BOUND)
		assert_between(value, 0, BOUND - 1)


func test_pick_returns_a_member() -> void:
	var rng := Rng.create(7)
	var items := ["a", "b", "c"]
	for i in 50:
		assert_has(items, rng.pick(items))
