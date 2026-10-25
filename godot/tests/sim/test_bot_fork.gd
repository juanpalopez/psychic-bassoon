## The scripted bot on a board where the road forks (#458): it ranks the sockets over the
## cells of every lane foes walk, each cell once, and a board without a fork is ranked on the main
## road as before.
extends GutTest

const PROFILES := preload("res://content/bot_profiles.gd")


func _bot(profile_id: String = "spoolOnly") -> ScriptedBot:
	return ScriptedBot.new(PROFILES.PROFILES[profile_id])


## The fork board with three sockets: one beside the main road only, one beside the shared
## tail, one beside the branch only. Read on the main road alone the first is the best.
func _fork_game(sockets: Array[Vector2i]) -> GameState:
	var map := ForkKit.curved_map()
	map.sockets = sockets
	var game := ForkKit.game(1, map)
	game.buttons = 1000
	return game


func _first_socket(game: GameState) -> Vector2i:
	var bot := _bot()
	for i in 2:
		bot.act(game)
		Game.tick(game)
	return Vector2i(game.towers[0].col, game.towers[0].row)


func test_its_first_tower_reaches_the_most_road_of_both_lanes_of_a_fork() -> void:
	var game := _fork_game([ForkKit.MAIN_SOCKET, ForkKit.TAIL_SOCKET, ForkKit.BRANCH_SOCKET])
	assert_eq(
		_first_socket(game),
		ForkKit.BRANCH_SOCKET,
		"5 branch cells beat 3 main ones, and the shared tail counts once"
	)


func test_a_board_without_a_fork_still_ranks_on_the_main_road() -> void:
	var map := ForkKit.map_without_fork()
	map.sockets = [ForkKit.BRANCH_SOCKET, ForkKit.MAIN_SOCKET, ForkKit.TAIL_SOCKET]
	var game := ForkKit.game(1, map)
	game.buttons = 1000
	assert_eq(_first_socket(game), ForkKit.MAIN_SOCKET, "the branch socket reaches no road")


func test_every_cell_of_a_lane_weighs_the_same() -> void:
	# 3 main-road cells beat 2 branch cells; a double weight on the branch would flip it
	var game := _fork_game([ForkKit.MAIN_SOCKET, Vector2i(9, 0)])
	assert_eq(_first_socket(game), ForkKit.MAIN_SOCKET)


func test_the_reach_band_widens_the_reach_the_sockets_are_ranked_by() -> void:
	# 3 cells against 1 without the band's margin, 5 against 6 with it
	var map := ForkKit.curved_map()
	map.sockets = [Vector2i(4, 0), Vector2i(1, 1)]
	map.reach_band = 2.0
	var game := ForkKit.game(1, map)
	game.buttons = 1000
	assert_eq(_first_socket(game), Vector2i(1, 1))
