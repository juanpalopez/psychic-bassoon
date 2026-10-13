## A wave's foes walk in groups of Fibonacci sizes (1, 2, 3, 5, 8, 13, 21), chosen
## from the wave's seed, with tight spacing inside a group and a pause between them.
extends GutTest

const WAVES := preload("res://content/waves.gd")
const SEED := 42


func _sizes(wave: int, total: int, map_seed: int = SEED) -> Array[int]:
	return WaveBuilder.group_sizes(wave, total, Rng.derive(map_seed, Streams.WAVES))


func _sum(sizes: Array[int]) -> int:
	var total := 0
	for size in sizes:
		total += size
	return total


func test_the_sizes_are_the_fibonacci_numbers_up_to_21() -> void:
	assert_eq(WAVES.GROUP_SIZES, [1, 2, 3, 5, 8, 13, 21])


func test_a_waves_groups_add_up_to_its_foes_and_are_fibonacci() -> void:
	for wave in [1, 4, 9, 13, 20]:
		for total in [1, 7, 20, 48, 57]:
			for map_seed in range(1, 12):
				var sizes := _sizes(wave, total, map_seed)
				assert_eq(_sum(sizes), total, "wave %d, %d foes, seed %d" % [wave, total, map_seed])
				for size in sizes:
					assert_true(WAVES.GROUP_SIZES.has(size), "%d is a Fibonacci size" % size)


func test_the_biggest_group_a_wave_may_have_rises_with_the_wave() -> void:
	# waves 1 to 3: up to 5, from 4: 8, from 8: 13, from 13: 21
	var expected := {1: 5, 3: 5, 4: 8, 7: 8, 8: 13, 12: 13, 13: 21, 20: 21}
	for wave in expected:
		var biggest := 0
		for map_seed in range(1, 60):
			for size in _sizes(wave, 60, map_seed):
				biggest = maxi(biggest, size)
		assert_lte(biggest, expected[wave], "wave %d never has a bigger group" % wave)
		assert_eq(
			biggest, expected[wave], "and over many seeds the cap is reached at wave %d" % wave
		)


func test_the_same_seed_gives_the_same_groups_and_seeds_differ() -> void:
	assert_eq(_sizes(15, 57), _sizes(15, 57))
	var different := false
	for map_seed in range(1, 12):
		different = different or _sizes(15, 57, map_seed) != _sizes(15, 57)
	assert_true(different)


func test_a_group_draws_one_float_from_the_waves_stream() -> void:
	var rng := Rng.derive(SEED, Streams.WAVES)
	var sizes := WaveBuilder.group_sizes(12, 40, rng)
	var expected := Rng.derive(SEED, Streams.WAVES)
	# one draw per group; a group that had to be cut down to fit still drew once
	for i in sizes.size():
		expected.next_float()
	assert_eq(rng.state, expected.state)


func test_foes_inside_a_group_follow_closely_and_the_last_one_waits_for_the_next_group() -> void:
	for wave in [3, 8, 14]:
		var orders := WaveBuilder.build(wave, Rng.derive(SEED, Streams.WAVES))
		var pause := maxf(
			WAVES.GROUP_PAUSE_MIN, WAVES.GROUP_PAUSE_BASE - float(wave) * WAVES.GROUP_PAUSE_PER_WAVE
		)
		var tight := 0
		var pauses := 0
		for order in orders:
			if is_equal_approx(order.gap, WAVES.GROUP_SPACING):
				tight += 1
			elif is_equal_approx(order.gap, pause):
				pauses += 1
		assert_eq(
			tight + pauses, orders.size(), "wave %d: every gap is a spacing or a pause" % wave
		)
		assert_gt(tight, pauses, "wave %d: most foes follow closely" % wave)
		assert_gt(pauses, 0)


func _group_ends(orders: Array[SpawnOrder]) -> Array[float]:
	# the pauses between groups are the gaps that are not the tight spacing
	var ends: Array[float] = []
	for order in orders:
		if not is_equal_approx(order.gap, WAVES.GROUP_SPACING):
			ends.append(order.gap)
	return ends


func test_the_pause_between_groups_is_written_out_and_has_a_floor() -> void:
	# 2.4 - 0.05 * wave, never under 1.0: 2.3 at wave 2, 1.45 at wave 19, the floor 1.0 at wave
	# 33 (not boss waves: their escort and Golem have gaps of their own)
	for entry in [[2, 2.3], [19, 1.45], [28, 1.0], [33, 1.0]]:
		var ends := _group_ends(WaveBuilder.build(entry[0], Rng.derive(SEED, Streams.WAVES)))
		assert_gt(ends.size(), 0, "wave %d has groups" % entry[0])
		for gap in ends:
			assert_almost_eq(gap, entry[1], 1e-9, "wave %d" % entry[0])


func test_a_boss_wave_keeps_its_escort_in_front_and_the_golem_behind_the_groups() -> void:
	var orders := WaveBuilder.build(10, Rng.derive(SEED, Streams.WAVES))
	assert_eq(orders[0].type, "corrugatedOrc")
	assert_eq(orders[orders.size() - 1].type, "cardboardGolem")
	# the escort's and the Golem's own gaps are kept, not turned into group gaps (the Golem
	# is last, so nothing waits after it; the time before it is the last group's pause)
	var gap := maxf(WAVES.GAP_MIN, WAVES.GAP_BASE - 10.0 * WAVES.GAP_PER_WAVE)
	assert_almost_eq(orders[0].gap, gap * WAVES.GAP_BOSS_ESCORT, 1e-9)
	assert_almost_eq(orders[orders.size() - 1].gap, WAVES.GOLEM_GAP, 1e-9)
	assert_eq(orders.size(), WaveBuilder.count_for(10) + 2)


func test_waves_are_bigger_by_the_size_multiplier() -> void:
	assert_almost_eq(WAVES.WAVE_SIZE_MULTIPLIER, 1.4, 1e-12)
	# round((6 + 1.4 * w) * 1.4); swarm waves times 1.5 on top
	assert_eq(WaveBuilder.count_for(1), 10)
	assert_eq(WaveBuilder.count_for(2), 12)
	assert_eq(WaveBuilder.count_for(10), 28)
	assert_eq(WaveBuilder.count_for(16), 40)
	assert_eq(WaveBuilder.count_for(5), 27)
	assert_eq(WaveBuilder.count_for(15), 57)
	assert_eq(WaveBuilder.count_for(20), 48)
