## Which foes a wave holds, in spawn order, and the pause after each. Expected
## counts and gaps are written out by hand from the formulas.
extends GutTest

const SEED := 42


func _build(wave: int) -> Array[SpawnOrder]:
	return WaveBuilder.build(wave, Rng.derive(SEED, Streams.WAVES))


func _types(orders: Array[SpawnOrder]) -> Array[String]:
	var out: Array[String] = []
	for order in orders:
		out.append(order.type)
	return out


func test_wave_1_has_seven_foes_all_goblins() -> void:
	# round(6 + 1.4) = 7
	var orders := _build(1)
	assert_eq(orders.size(), 7)
	for order in orders:
		assert_eq(order.type, "scrapGoblin")


func test_a_normal_wave_pauses_by_the_goblin_multiplier() -> void:
	# gap = max(0.32, 0.95 - 0.025 * 2) = 0.9, goblin multiplier 0.6
	for order in _build(2):
		assert_almost_eq(order.gap, 0.9 * 0.6, 1e-12)


func test_the_gap_between_foes_has_a_floor() -> void:
	# 0.95 - 0.025 * 40 is below the floor of 0.32
	for order in _build(40):
		if order.type == "scrapGoblin":
			assert_almost_eq(order.gap, 0.32 * 0.6, 1e-12)


func test_no_orcs_before_wave_4() -> void:
	for wave in [1, 2, 3]:
		for order in _build(wave):
			assert_ne(order.type, "corrugatedOrc", "wave %d" % wave)


func test_orcs_arrive_and_become_commoner_in_later_waves() -> void:
	var orcs_by_wave := {}
	for wave in [4, 8, 14, 19]:
		var count := 0
		for map_seed in 30:
			var rng := Rng.derive(map_seed, Streams.WAVES)
			for order in WaveBuilder.build(wave, rng):
				if order.type == "corrugatedOrc":
					count += 1
		orcs_by_wave[wave] = count
	assert_gt(orcs_by_wave[4], 0)
	assert_gt(orcs_by_wave[14], orcs_by_wave[4])


func test_every_fifth_wave_is_a_goblin_swarm_with_tight_gaps() -> void:
	# wave 5: round(6 + 7) = 13 foes, gap = 0.95 - 0.125 = 0.825, swarm multiplier 0.45
	var orders := _build(5)
	assert_eq(orders.size(), 13)
	for order in orders:
		assert_eq(order.type, "scrapGoblin")
		assert_almost_eq(order.gap, 0.825 * 0.45, 1e-12)


func test_every_tenth_wave_is_a_boss_wave_with_an_escort_and_the_golem() -> void:
	# wave 10: round(6 + 14) = 20 foes, plus the escort in front and the Golem behind
	var orders := _build(10)
	assert_eq(orders.size(), 22)
	assert_eq(orders[0].type, "corrugatedOrc")
	# gap = 0.95 - 0.25 = 0.7, the escort pauses twice as long
	assert_almost_eq(orders[0].gap, 0.7 * 2.0, 1e-12)
	assert_eq(orders[orders.size() - 1].type, "cardboardGolem")
	assert_almost_eq(orders[orders.size() - 1].gap, 1.0, 1e-12)
	var golems := 0
	for order in orders:
		if order.type == "cardboardGolem":
			golems += 1
	assert_eq(golems, 1)


func test_a_boss_wave_is_not_also_a_swarm() -> void:
	# wave 10 is a multiple of 5 and of 10: the boss rule wins
	assert_true(_types(_build(10)).has("corrugatedOrc") or _types(_build(10)).has("cardboardGolem"))
	assert_eq(_build(10).size(), 22)


func test_the_same_seed_gives_the_same_wave() -> void:
	for wave in [1, 4, 7, 10, 15, 20]:
		var a := _build(wave)
		var b := _build(wave)
		assert_eq(_types(a), _types(b))
		for i in a.size():
			assert_eq(a[i].gap, b[i].gap)


func test_a_wave_draws_exactly_one_float_per_normal_foe() -> void:
	# the boss escort and the Golem are not rolled, so wave 10 draws 20
	for wave in [1, 4, 5, 10]:
		var rng := Rng.derive(SEED, Streams.WAVES)
		var orders := WaveBuilder.build(wave, rng)
		var expected := Rng.derive(SEED, Streams.WAVES)
		var rolled := orders.size() - (2 if wave % 10 == 0 else 0)
		for i in rolled:
			expected.next_float()
		assert_eq(rng.state, expected.state, "wave %d" % wave)


func test_building_wave_after_wave_keeps_one_stream_going() -> void:
	# the game builds each wave from the same stream when it launches
	var rng := Rng.derive(SEED, Streams.WAVES)
	var first := WaveBuilder.build(1, rng)
	var second := WaveBuilder.build(2, rng)
	assert_eq(first.size(), 7)
	assert_eq(second.size(), 9)
	var fresh := Rng.derive(SEED, Streams.WAVES)
	for i in 16:
		fresh.next_float()
	assert_eq(rng.state, fresh.state)


func test_waves_grow_in_size() -> void:
	var previous := 0
	for wave in range(1, 30):
		var count := _build(wave).size()
		assert_gte(count + 2, previous, "wave %d" % wave)
		previous = count


## `count_for(wave)` rolls, all with the same value.
func _rolls(wave: int, value: float) -> Array[float]:
	var rolls: Array[float] = []
	for i in WaveBuilder.count_for(wave):
		rolls.append(value)
	return rolls


## The rolls of a wave with the first one set.
func _first_roll(wave: int, value: float) -> Array[float]:
	var rolls := _rolls(wave, 0.0)
	rolls[0] = value
	return rolls


func test_the_count_is_6_plus_1_point_4_per_wave_rounded() -> void:
	assert_eq(WaveBuilder.count_for(1), 7)
	assert_eq(WaveBuilder.count_for(2), 9)
	assert_eq(WaveBuilder.count_for(5), 13)
	assert_eq(WaveBuilder.count_for(10), 20)
	assert_eq(WaveBuilder.count_for(15), 27)


func test_a_roll_above_the_threshold_makes_an_orc_and_an_orc_waits_longer() -> void:
	# wave 8: threshold 0.82 - 0.08 = 0.74; gap 0.95 - 0.2 = 0.75; orc multiplier 1.4
	var orders := WaveBuilder.compose(8, _rolls(8, 0.9))
	assert_eq(orders.size(), 17)
	for order in orders:
		assert_eq(order.type, "corrugatedOrc")
		assert_almost_eq(order.gap, 0.75 * 1.4, 1e-12)


func test_the_orc_decision_at_the_threshold_boundary() -> void:
	# wave 4: threshold 0.82 - 0.04 = 0.78 (a hair under it in 64-bit floats, so test
	# either side of it, not the exact value)
	assert_eq(WaveBuilder.compose(4, _first_roll(4, 0.781))[0].type, "corrugatedOrc")
	assert_eq(WaveBuilder.compose(4, _first_roll(4, 0.779))[0].type, "scrapGoblin")
	assert_eq(WaveBuilder.compose(4, _first_roll(4, 0.5))[0].type, "scrapGoblin")


func test_no_roll_makes_an_orc_before_wave_4() -> void:
	for wave in [1, 2, 3]:
		for order in WaveBuilder.compose(wave, _rolls(wave, 0.99)):
			assert_eq(order.type, "scrapGoblin", "wave %d" % wave)
	for order in WaveBuilder.compose(4, _rolls(4, 0.99)):
		assert_eq(order.type, "corrugatedOrc")


func test_the_orc_threshold_stops_falling_at_wave_20() -> void:
	# 0.82 - min(0.2, 0.01 * w): 0.62 from wave 20 on, so waves 21, 23 and 31 agree
	for wave in [21, 23, 31]:
		for order in WaveBuilder.compose(wave, _rolls(wave, 0.63)):
			assert_eq(order.type, "corrugatedOrc", "wave %d at 0.63" % wave)
		for order in WaveBuilder.compose(wave, _rolls(wave, 0.61)):
			assert_eq(order.type, "scrapGoblin", "wave %d at 0.61" % wave)


func test_a_swarm_wave_ignores_the_rolls() -> void:
	for wave in [5, 15]:
		for order in WaveBuilder.compose(wave, _rolls(wave, 0.99)):
			assert_eq(order.type, "scrapGoblin")


func test_a_boss_wave_holds_the_rolled_foes_between_the_escort_and_the_golem() -> void:
	var rolls := _rolls(10, 0.1)
	rolls[3] = 0.9
	var orders := WaveBuilder.compose(10, rolls)
	assert_eq(orders.size(), 22)
	for i in orders.size():
		var expected := "scrapGoblin"
		# the escort comes first, so the roll at index 3 lands at order 4
		if i == 0 or i == 4:
			expected = "corrugatedOrc"
		if i == 21:
			expected = "cardboardGolem"
		assert_eq(orders[i].type, expected, "order %d" % i)
