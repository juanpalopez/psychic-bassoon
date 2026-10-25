## What the layout valley board (`Game.create_on_layout_valley`) is, pinned beside the strip
## valley's facts, so the #458 flip (the game board plays the layout valley) moves as few tests
## as possible.
extends GutTest

const LAYOUT := preload("res://content/valley/layout_rules.gd")
const PROFILES := preload("res://content/bot_profiles.gd")

var _seeds: Array[int] = []


func before_all() -> void:
	for map_seed in range(1, 21):
		_seeds.append(map_seed)
	# the two seeds of 3001..3300 that reach the 31-socket top of the range
	_seeds.append_array([3063, 3218])


func test_the_layout_board_is_40_by_24_with_the_knight() -> void:
	for map_seed in _seeds:
		var game := Game.create_on_layout_valley(map_seed)
		assert_not_null(game, "seed %d" % map_seed)
		assert_eq([game.map.cols, game.map.rows], [40, 24], "seed %d" % map_seed)
		assert_not_null(game.hero, "the Knight, seed %d" % map_seed)


func test_the_routes_are_a_feeder_and_a_fork_with_two_sources() -> void:
	for map_seed in _seeds:
		var map := Game.create_on_layout_valley(map_seed).map
		assert_eq(map.routes.size(), 3, "A, the feeder, B, seed %d" % map_seed)
		assert_eq(map.sources.size(), 2, "seed %d" % map_seed)
		assert_eq(Array(map.sources[0]), [0, 2], "seed %d" % map_seed)
		assert_eq(Array(map.sources[1]), [1], "seed %d" % map_seed)


func test_two_road_crossings_and_no_hero_only_bridge() -> void:
	for map_seed in _seeds:
		var map := Game.create_on_layout_valley(map_seed).map
		var routes: Array[int] = []
		for bridge in map.bridges:
			if not routes.has(bridge.route):
				routes.append(bridge.route)
		routes.sort()
		assert_eq(
			routes,
			[0, 2] as Array[int],
			"the road crosses the river on routes 0 and 2, seed %d" % map_seed
		)
		assert_true(map.hero_bridges.is_empty(), "no hero bridge, seed %d" % map_seed)


func test_sockets_stay_between_24_and_31() -> void:
	for map_seed in _seeds:
		var count := Game.create_on_layout_valley(map_seed).map.sockets.size()
		assert_between(count, 24, 31, "seed %d" % map_seed)


func test_the_layout_board_takes_its_foe_pace_from_the_content() -> void:
	for map_seed in _seeds:
		var map := Game.create_on_layout_valley(map_seed).map
		assert_eq(map.foe_pace, LAYOUT.FOE_PACE, "seed %d" % map_seed)


func test_waves_start_and_ticks_run() -> void:
	for map_seed in [1, 2, 3]:
		var game := Game.create_on_layout_valley(map_seed)
		Game.submit(game, Command.launch_wave())
		for i in 90:
			Game.tick(game)
		assert_eq(game.wave, 1, "wave 1 started, seed %d" % map_seed)
		assert_false(game.over, "seed %d" % map_seed)


func test_a_scripted_bot_plays_three_waves() -> void:
	for map_seed in [1, 2]:
		var result := BalanceBoard.play("layout", map_seed, PROFILES.PROFILES.mix, 3)
		assert_false(result.is_empty(), "seed %d" % map_seed)
		assert_eq(result.waves_cleared, 3, "seed %d" % map_seed)
		assert_eq(result.rejected, 0, "no rejected command, seed %d" % map_seed)
