## The debug entry that plays the layout valley (#513), and the default board it must not move.
extends GutTest

const SEED := 1


func test_layout_valley_game_is_40_by_24_with_the_knight() -> void:
	var game := Game.create_on_layout_valley(SEED)
	assert_not_null(game)
	assert_eq(game.map.cols, 40)
	assert_eq(game.map.rows, 24)
	assert_eq(game.seed, SEED)
	assert_not_null(game.hero, "the Knight starts on the layout valley too")


func test_same_seed_gives_the_same_game() -> void:
	var a := Game.create_on_layout_valley(SEED)
	var b := Game.create_on_layout_valley(SEED)
	assert_eq(a.map.sockets.size(), b.map.sockets.size())
	assert_eq(a.map.path, b.map.path)
	assert_eq(a.rng.state, b.rng.state)


func test_default_board_is_unchanged() -> void:
	var game := Game.create(SEED)
	var expected := Game.from_map(SEED, MapGen.game_map(SEED), false, true)
	assert_eq(game.map.cols, expected.map.cols)
	assert_eq(game.map.path, expected.map.path)
	assert_eq(game.rng.state, expected.rng.state)
	assert_ne(game.map.cols, 40, "the default board is not the layout valley")
