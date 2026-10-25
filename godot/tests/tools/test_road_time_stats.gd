## The pure helpers of the road-time measurement (#460).
extends GutTest

const STATS := preload("res://tools/road_time_stats.gd")
const FOES := preload("res://content/foes.gd")


func _floats(a: Array) -> Array[float]:
	var out: Array[float] = []
	out.assign(a)
	return out


func test_speed_scale_multiplies_only_the_value_it_is_given() -> void:
	assert_almost_eq(STATS.scaled_speed(1.6, 0.5), 0.8, 0.000001)
	assert_eq(STATS.scaled_speed(1.6, 1.0), 1.6)


func test_a_speed_scale_never_edits_the_foe_content() -> void:
	STATS.scaled_speed(FOES.DEFS["scrapGoblin"]["speed"], 0.5)
	assert_eq(FOES.DEFS["scrapGoblin"]["speed"], 1.6)


func test_percentiles_use_the_sorted_index_rule() -> void:
	var v := _floats([5.0, 1.0, 4.0, 2.0, 3.0, 9.0, 8.0, 7.0, 6.0, 10.0])
	assert_eq(STATS.percentile(v, 10), 2.0)
	assert_eq(STATS.median(v), 6.0)
	assert_eq(STATS.percentile(v, 90), 10.0)
	assert_eq(STATS.minimum(v), 1.0)


func test_percentile_of_nothing_is_zero() -> void:
	assert_eq(STATS.median(_floats([])), 0.0)
	assert_eq(STATS.minimum(_floats([])), 0.0)


func test_percentile_does_not_reorder_its_input() -> void:
	var v := _floats([3.0, 1.0, 2.0])
	STATS.median(v)
	assert_eq(v, _floats([3.0, 1.0, 2.0]))


func test_ratios_divide_by_the_strip_median() -> void:
	assert_eq(STATS.ratios(_floats([30.0, 60.0]), 60.0), _floats([0.5, 1.0]))


func test_ratios_against_no_strip_time_are_empty() -> void:
	assert_true(STATS.ratios(_floats([30.0]), 0.0).is_empty())


func test_the_gate_passes_a_median_inside_the_band_and_no_low_seed() -> void:
	assert_true(STATS.gate_passes(_floats([0.8, 0.95, 1.0, 1.05, 1.2])))


func test_the_gate_fails_a_median_below_90_percent() -> void:
	assert_false(STATS.gate_passes(_floats([0.8, 0.85, 0.89])))


func test_the_gate_fails_a_median_above_110_percent() -> void:
	assert_false(STATS.gate_passes(_floats([1.11, 1.2, 1.3])))


func test_the_gate_fails_one_seed_below_75_percent() -> void:
	assert_false(STATS.gate_passes(_floats([0.74, 0.95, 1.0, 1.05, 1.1])))


func test_the_gate_never_passes_an_empty_list() -> void:
	assert_false(STATS.gate_passes(_floats([])))
