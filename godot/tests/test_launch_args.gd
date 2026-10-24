## The desktop flags that choose the layout valley and its seed (#513).
extends GutTest


func test_no_flag_means_no_layout_valley() -> void:
	assert_false(LaunchArgs.layout_valley(PackedStringArray(["--stress=80", "--fps"])))
	assert_false(LaunchArgs.layout_valley(PackedStringArray()))


func test_flag_is_read() -> void:
	assert_true(LaunchArgs.layout_valley(PackedStringArray(["--layout-valley"])))


func test_seed_is_read_or_null() -> void:
	assert_eq(LaunchArgs.seed_value(PackedStringArray(["--seed=7"])), 7)
	assert_eq(LaunchArgs.seed_value(PackedStringArray(["--seed=-3"])), -3)
	assert_null(LaunchArgs.seed_value(PackedStringArray(["--layout-valley"])))
	assert_null(LaunchArgs.seed_value(PackedStringArray(["--seed=abc"])))
	assert_null(LaunchArgs.seed_value(PackedStringArray(["--seed=12345678901234567"])))
	assert_eq(LaunchArgs.seed_value(PackedStringArray(["--seed=1", "--seed=2"])), 2)
