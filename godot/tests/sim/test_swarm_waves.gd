## Swarm waves (every 5th wave that is not a boss wave): more foes, a few orcs.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _rolls(wave: int, value: float) -> Array[float]:
	var rolls: Array[float] = []
	for i in WaveBuilder.count_for(wave):
		rolls.append(value)
	return rolls


func _types(orders: Array[SpawnOrder]) -> Array[String]:
	var types: Array[String] = []
	for order in orders:
		types.append(order.type)
	return types


func test_a_swarm_has_the_swarm_multiplier_times_the_usual_foes() -> void:
	assert_gt(WAVES.SWARM_COUNT_MULTIPLIER, 1.0, "swarms are bigger than a normal wave")
	for wave in [5, 15]:
		var usual := (
			(WAVES.BASE_COUNT + float(wave) * WAVES.COUNT_PER_WAVE) * WAVES.WAVE_SIZE_MULTIPLIER
		)
		assert_eq(
			WaveBuilder.count_for(wave), Rounding.half_up(usual * WAVES.SWARM_COUNT_MULTIPLIER)
		)
		assert_gt(WaveBuilder.count_for(wave), Rounding.half_up(usual))
	# by hand: 13 * 1.4 * 1.5 = 27.3 -> 27 and 27 * 1.4 * 1.5 = 56.7 -> 57
	assert_eq(WaveBuilder.count_for(5), 27)
	assert_eq(WaveBuilder.count_for(15), 57)


func test_other_waves_and_boss_waves_keep_the_usual_count() -> void:
	for wave in [1, 4, 6, 9, 10, 11, 14, 19, 20]:
		var usual := (
			(WAVES.BASE_COUNT + float(wave) * WAVES.COUNT_PER_WAVE) * WAVES.WAVE_SIZE_MULTIPLIER
		)
		assert_eq(WaveBuilder.count_for(wave), Rounding.half_up(usual), "wave %d" % wave)


func test_a_swarm_wave_is_goblins_with_a_few_orcs_by_its_own_threshold() -> void:
	for wave in [5, 15]:
		# the normal threshold 0.82 - 0.01 * wave, lowered for a swarm
		var threshold := 0.82 - 0.01 * float(wave) - WAVES.SWARM_ORC_THRESHOLD_DROP
		for order in WaveBuilder.compose(wave, _rolls(wave, threshold)):
			assert_eq(order.type, "scrapGoblin", "a roll at the threshold is a goblin")
		for order in WaveBuilder.compose(wave, _rolls(wave, threshold + 0.001)):
			assert_eq(order.type, "corrugatedOrc", "a roll just above it is an orc")
		var orders := WaveBuilder.compose(wave, _rolls(wave, 0.999))
		for order in orders:
			assert_eq(order.type, "corrugatedOrc", "a roll above it is an orc")
		var one := _rolls(wave, 0.0)
		one[2] = 0.999
		var types := _types(WaveBuilder.compose(wave, one))
		assert_eq(types.count("corrugatedOrc"), 1)
		assert_eq(types.size(), WaveBuilder.count_for(wave))
