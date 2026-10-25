## `Game.create_on_strip_valley` is the board the mechanic tests name and `--strip-valley` plays:
## the 32 by 20 strip valley, at pace 1.0, with the Knight, while the default board is the layout
## valley since #458.
extends GutTest

const SEEDS := 20


func test_the_entry_plays_the_strip_valley_with_the_knight() -> void:
	for map_seed in range(1, SEEDS + 1):
		var game := Game.create_on_strip_valley(map_seed)
		var strip := MapGen.generate_valley(map_seed)
		assert_eq([game.map.cols, game.map.rows], [32, 20], "seed %d" % map_seed)
		assert_eq(game.map.path, strip.path, "seed %d" % map_seed)
		assert_eq(game.map.foe_pace, 1.0)
		assert_eq(
			game.route.total, Route.build_curved(strip.path).total, "the curve of the grid path"
		)
		assert_not_null(game.hero, "seed %d keeps the Knight" % map_seed)


func test_the_default_board_is_not_the_strip_valley() -> void:
	for map_seed in [1, 7, 42]:
		assert_eq(Game.create(map_seed).map.cols, 40)
		assert_eq(Game.create_on_strip_valley(map_seed).map.cols, 32)
