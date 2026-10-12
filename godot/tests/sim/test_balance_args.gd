## The balance tool's command line: a mistyped flag is an error, not a quiet
## run of the wrong inputs.
extends GutTest


func test_no_arguments_give_the_defaults() -> void:
	var args := BalanceArgs.parse(PackedStringArray())
	assert_eq(args.error, "")
	assert_eq(args.seeds, [1, 2, 3, 4, 5, 6, 7, 8] as Array[int])
	assert_eq(args.profiles, ["spoolOnly", "mortarHeavy", "mix"] as Array[String])
	assert_eq(args.waves, 20)
	assert_false(args.detail)


func test_every_option_can_be_set() -> void:
	var args := BalanceArgs.parse(
		PackedStringArray(["--seeds=3,9", "--profiles=mix", "--waves=12", "--detail"])
	)
	assert_eq(args.error, "")
	assert_eq(args.seeds, [3, 9] as Array[int])
	assert_eq(args.profiles, ["mix"] as Array[String])
	assert_eq(args.waves, 12)
	assert_true(args.detail)


func test_negative_seeds_are_fine() -> void:
	assert_eq(BalanceArgs.parse(PackedStringArray(["--seeds=-7,0"])).seeds, [-7, 0] as Array[int])


func test_bad_input_is_an_error_with_a_message() -> void:
	for bad in [
		"--seeds=abc",
		"--seeds=",
		"--seeds=1,,2",
		"--seeds=1.5",
		"--profiles=foo",
		"--profiles=",
		"--waves=0",
		"--waves=-3",
		"--waves=x",
		"--wave=30",
		"--detail=yes",
		"seeds=1",
	]:
		var args := BalanceArgs.parse(PackedStringArray([bad]))
		assert_ne(args.error, "", bad)


func test_the_error_names_the_bad_argument() -> void:
	assert_string_contains(BalanceArgs.parse(PackedStringArray(["--wave=30"])).error, "--wave=30")
	assert_string_contains(BalanceArgs.parse(PackedStringArray(["--profiles=foo"])).error, "foo")


func test_the_usage_text_names_every_option() -> void:
	for option in ["--seeds", "--profiles", "--waves", "--detail"]:
		assert_string_contains(BalanceArgs.usage(), option)
