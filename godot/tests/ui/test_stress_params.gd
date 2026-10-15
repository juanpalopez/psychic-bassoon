## The page parameters of the phone check: ?stress=80 and ?fps.
extends GutTest


func test_a_whole_number_is_the_foe_count() -> void:
	assert_eq(StressParams.foes("80"), 80)
	assert_eq(StressParams.foes("1"), 1)


func test_nothing_wrong_or_missing_is_zero() -> void:
	for value in [null, "", "abc", "-5", "0", "8.5", "80x", " 80"]:
		assert_eq(StressParams.foes(value), 0, str(value))


func test_the_count_is_capped() -> void:
	assert_eq(StressParams.foes("100000"), StressParams.MAX_FOES)
	assert_eq(StressParams.foes("%d" % StressParams.MAX_FOES), StressParams.MAX_FOES)


func test_fps_is_on_when_the_parameter_is_there_unless_it_says_zero() -> void:
	assert_true(StressParams.fps_on(""), "?fps")
	assert_true(StressParams.fps_on("1"))
	assert_false(StressParams.fps_on(null))
	assert_false(StressParams.fps_on("0"))


func test_leading_zeros_count_but_a_long_string_does_not() -> void:
	assert_eq(StressParams.foes("080"), 80)
	assert_eq(StressParams.foes("0000080"), 0, "more than six characters is ignored")
