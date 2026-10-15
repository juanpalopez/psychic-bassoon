## Where Ink Shamans appear in the waves.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _count(orders: Array[SpawnOrder]) -> int:
	var count := 0
	for order in orders:
		if order.type == WAVES.SUPPORT_FOE:
			count += 1
	return count


func _positions(orders: Array[SpawnOrder], type: String) -> Array[int]:
	var found: Array[int] = []
	for i in orders.size():
		if orders[i].type == type:
			found.append(i)
	return found


func _build(wave: int) -> Array[SpawnOrder]:
	return WaveBuilder.build(wave, Rng.derive(42, Streams.WAVES))


func test_no_shaman_before_its_wave() -> void:
	for wave in range(1, WAVES.SHAMAN_FROM_WAVE):
		assert_eq(_count(_build(wave)), 0, "wave %d" % wave)


func test_from_its_wave_on_there_is_one_and_more_as_waves_go_on() -> void:
	assert_eq(_count(_build(WAVES.SHAMAN_FROM_WAVE)), 1)
	assert_eq(_count(_build(WAVES.SHAMAN_FROM_WAVE + WAVES.SHAMAN_EVERY_WAVES)), 2)
	assert_eq(_count(_build(WAVES.SHAMAN_FROM_WAVE + 2 * WAVES.SHAMAN_EVERY_WAVES)), 3)


func test_a_shaman_replaces_a_foe_it_does_not_add_one() -> void:
	for wave in [7, 12, 17]:
		assert_eq(_build(wave).size(), WaveBuilder.count_for(wave) + (2 if wave % 10 == 0 else 0))


func test_the_shamans_sit_inside_the_wave_not_at_its_start_or_end() -> void:
	var orders := _build(12)
	var positions: Array[int] = []
	for i in orders.size():
		if orders[i].type == WAVES.SUPPORT_FOE:
			positions.append(i)
	assert_eq(positions.size(), 2)
	assert_gt(positions[0], 0)
	assert_lt(positions[1], orders.size() - 1)
	assert_lt(positions[0], positions[1])


func test_the_waves_stream_is_drawn_exactly_as_before() -> void:
	for wave in [7, 12, 17]:
		var rng := Rng.derive(42, Streams.WAVES)
		var orders := WaveBuilder.build(wave, rng)
		var expected := Rng.derive(42, Streams.WAVES)
		var rolled := orders.size() - (2 if wave % 10 == 0 else 0)
		for i in rolled:
			expected.next_float()
		WaveBuilder.group_sizes(wave, rolled, expected)
		assert_eq(rng.state, expected.state, "wave %d" % wave)


func test_a_boss_wave_keeps_its_escort_and_golem() -> void:
	var orders := _build(10)
	assert_eq(orders[0].type, "corrugatedOrc")
	assert_eq(orders[orders.size() - 1].type, "cardboardGolem")


func test_in_a_boss_wave_the_shamans_sit_between_the_escort_and_the_golem() -> void:
	for wave in [10, 20]:
		var orders := _build(wave)
		var shamans := _positions(orders, WAVES.SUPPORT_FOE)
		assert_gte(shamans.size(), 1, "wave %d" % wave)
		for at in shamans:
			assert_gt(at, 0, "not the escort, wave %d" % wave)
			assert_lt(at, orders.size() - 1, "not the Golem, wave %d" % wave)
		# the same even spread as any wave, shifted past the escort
		var rolled := orders.size() - 2
		var count: int = 1 + (wave - WAVES.SHAMAN_FROM_WAVE) / WAVES.SHAMAN_EVERY_WAVES
		for k in count:
			assert_eq(
				shamans[k], 1 + (k + 1) * rolled / (count + 1), "wave %d shaman %d" % [wave, k]
			)
