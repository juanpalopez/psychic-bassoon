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


func test_a_pace_is_read_as_a_number_above_0() -> void:
	var out := _parse(["--pace=0.55"])
	assert_eq(out.error, "")
	assert_eq(out.pace, 0.55)
	assert_eq(_parse(["--pace=1.0"]).pace, 1.0)


func test_a_bad_pace_says_what_is_wrong_with_it() -> void:
	for text in ["--pace=0", "--pace=-1", "--pace=fast", "--pace="]:
		var out := _parse([text])
		assert_string_contains(out.error, "pace must be a number above 0", text)


func test_the_usage_names_the_new_options() -> void:
	assert_string_contains(BalanceArgs.usage(), "--board=strip|layout|default")
	assert_string_contains(BalanceArgs.usage(), "--pace=")


func _mean_road(board: String) -> float:
	var total := 0.0
	for map_seed in [1, 2, 3]:
		total += float(BalanceBoard.game_for(board, map_seed).map.path.size())
	return total / 3.0


func test_a_pace_is_set_on_the_map_of_every_board_before_any_foe() -> void:
	for board in ["strip", "layout", "default"]:
		var paced := BalanceBoard.game_for(board, 1, 0.5)
		assert_eq(paced.map.foe_pace, 0.5, board)
		assert_true(paced.foes.is_empty(), "no foe has spawned when the pace is set: " + board)
	assert_eq(BalanceBoard.game_for("strip", 1).map.foe_pace, 1.0, "no pace keeps the board's own")


func test_strip_is_the_strip_valley_whatever_the_default_board_is() -> void:
	for map_seed in [1, 2, 3]:
		var strip_game := BalanceBoard.game_for("strip", map_seed)
		var valley := MapGen.generate_valley(map_seed)
		assert_eq(strip_game.map.path, valley.path)
		assert_eq(strip_game.map.sockets.size(), valley.sockets.size())
		assert_eq(strip_game.map.cols, valley.cols)


func test_layout_is_a_different_and_shorter_road_than_the_strip() -> void:
	var strip_road := _mean_road("strip")
	var layout_road := _mean_road("layout")
	assert_gt(strip_road, 120.0, "the strip valley's road is about 150 cells")
	assert_lt(layout_road, 110.0, "the layout valley's road is about 83 cells")
	assert_gt(
		BalanceBoard.game_for("layout", 1).map.cols, BalanceBoard.game_for("strip", 1).map.cols
	)
