## The balance tool's command line (#458): the boards, the pace and the defaults.
extends GutTest


func _parse(args: Array[String]) -> Dictionary:
	return BalanceArgs.parse(PackedStringArray(args))


func test_no_arguments_keep_the_old_defaults() -> void:
	var out := _parse([])
	assert_eq(out.error, "")
	assert_eq(out.seeds, BalanceArgs.DEFAULT_SEEDS)
	assert_eq(out.waves, BalanceArgs.DEFAULT_WAVES)
	assert_eq(out.profiles, BalanceArgs.PROFILES.PROFILE_IDS)
	assert_false(out.detail)
	assert_eq(out.board, "", "no board option plays the default board and prints no board line")
	assert_eq(out.pace, 0.0)


func test_every_named_board_is_accepted() -> void:
	for board in ["strip", "layout", "default"]:
		var out := _parse(["--board=" + board])
		assert_eq(out.error, "", board)
		assert_eq(out.board, board)


func test_an_unknown_board_is_an_error_that_names_the_choices() -> void:
	var out := _parse(["--board=tower"])
	assert_string_contains(out.error, "--board=tower")
	assert_string_contains(out.error, "unknown board")
	assert_string_contains(out.error, "strip|layout|default")


func test_an_empty_board_is_an_error() -> void:
	assert_ne(_parse(["--board="]).error, "")


func test_the_board_goes_with_the_other_options() -> void:
	var out := _parse(["--seeds=4,2", "--board=layout", "--waves=5", "--detail"])
	assert_eq(out.error, "")
	assert_eq(out.seeds, [4, 2] as Array[int])
	assert_eq(out.waves, 5)
	assert_eq(out.board, "layout")
	assert_true(out.detail)


func test_pace_is_refused_until_the_game_has_a_foe_pace() -> void:
	assert_false(BalanceArgs.PACE_AVAILABLE)
	var out := _parse(["--pace=0.55"])
	assert_string_contains(out.error, "--pace=0.55")
	assert_string_contains(out.error, "not available yet")


func test_a_bad_pace_says_what_is_wrong_with_it() -> void:
	for text in ["--pace=0", "--pace=-1", "--pace=fast", "--pace="]:
		var out := _parse([text])
		assert_string_contains(out.error, "pace must be a number above 0", text)


func test_the_usage_names_the_new_options() -> void:
	assert_string_contains(BalanceArgs.usage(), "--board=strip|layout|default")
	assert_string_contains(BalanceArgs.usage(), "--pace=")


func test_each_board_makes_its_own_game() -> void:
	var default_game := BalanceBoard.game_for("default", 1)
	var layout_game := BalanceBoard.game_for("layout", 1)
	assert_not_null(default_game)
	assert_not_null(layout_game)
	assert_eq(BalanceBoard.game_for("strip", 1).map.sockets.size(), default_game.map.sockets.size())
	assert_gt(layout_game.map.cols, default_game.map.cols, "the layout valley is the wider board")
