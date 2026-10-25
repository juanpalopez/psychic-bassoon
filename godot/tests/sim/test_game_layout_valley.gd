## The layout valley as an entry (#513) and as the default board (#458), with its fallback chain.
## Its layout board facts are in test_layout_board.gd.
extends GutTest

const LAYOUT := preload("res://content/valley/layout_rules.gd")
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


func test_the_default_board_is_the_layout_valley() -> void:
	var game := Game.create(SEED)
	var layout := Game.create_on_layout_valley(SEED)
	assert_eq(game.map.cols, 40)
	assert_eq(game.map.rows, 24)
	assert_eq(game.map.path, layout.map.path)
	assert_eq(game.map.sockets, layout.map.sockets)
	assert_eq(game.map.foe_pace, LAYOUT.FOE_PACE, "the pace reaches the game board")
	assert_eq(game.rng.state, layout.rng.state)
	assert_not_null(game.hero)


func test_the_fallbacks_are_asked_in_order_and_warn_not_error() -> void:
	var asked: Array[int] = []
	var builders: Array[Callable] = [
		func(_s: int) -> GameMap:
			asked.append(0)
			return null,
		func(s: int) -> GameMap:
			asked.append(1)
			return GameMap.new(),
		func(_s: int) -> GameMap:
			asked.append(2)
			return null,
	]
	var map := MapGen.first_map(7, builders)
	assert_not_null(map)
	assert_eq(asked, [0, 1], "the first map that is made ends the search")
	var none: Array[Callable] = [func(_s: int) -> GameMap: return null]
	assert_null(MapGen.first_map(7, none))
