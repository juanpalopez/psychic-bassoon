## Where Razor Moths appear in the waves.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _build(wave: int) -> Array[SpawnOrder]:
	return WaveBuilder.build(wave, Rng.derive(42, Streams.WAVES))


func _positions(orders: Array[SpawnOrder], type: String) -> Array[int]:
	var found: Array[int] = []
	for i in orders.size():
		if orders[i].type == type:
			found.append(i)
	return found


func _expected(wave: int) -> int:
	var rolled := WaveBuilder.count_for(wave)
	return maxi(WAVES.MOTH_MIN, rolled * WAVES.MOTH_PERCENT / 100)


func test_no_moths_before_their_wave() -> void:
	for wave in range(1, WAVES.MOTH_FROM_WAVE):
		assert_eq(_positions(_build(wave), WAVES.AIR_FOE).size(), 0, "wave %d" % wave)


func test_from_their_wave_a_share_of_each_wave_flies() -> void:
	for wave in [9, 11, 14, 17]:
		assert_eq(_positions(_build(wave), WAVES.AIR_FOE).size(), _expected(wave), "wave %d" % wave)


func test_a_moth_replaces_a_foe_and_never_a_shaman_or_the_boss() -> void:
	for wave in [9, 12, 17, 20]:
		var orders := _build(wave)
		var rolled := WaveBuilder.count_for(wave)
		assert_eq(orders.size(), rolled + (2 if wave % 10 == 0 else 0), "wave %d" % wave)
		var shamans := _positions(orders, WAVES.SUPPORT_FOE)
		assert_gte(shamans.size(), 1, "the shamans are still there")
		for at in _positions(orders, WAVES.AIR_FOE):
			assert_false(shamans.has(at))
	var boss := _build(20)
	assert_eq(boss[0].type, "corrugatedOrc")
	assert_eq(boss[boss.size() - 1].type, "cardboardGolem")


func test_the_waves_stream_is_drawn_as_before() -> void:
	for wave in [9, 14, 20]:
		var rng := Rng.derive(42, Streams.WAVES)
		var orders := WaveBuilder.build(wave, rng)
		var expected := Rng.derive(42, Streams.WAVES)
		var rolled := orders.size() - (2 if wave % 10 == 0 else 0)
		for i in rolled:
			expected.next_float()
		WaveBuilder.group_sizes(wave, rolled, expected)
		assert_eq(rng.state, expected.state, "wave %d" % wave)
