## A Board draws the map it is given and sizes BoardSpace to it (#480); freeing it gives the
## game board's size back, so no later test inherits a map's size.
extends GutTest

const RULES := preload("res://content/map_rules.gd")


## The board is static, so a test that names another board gives the game board back.
func after_each() -> void:
	BoardSpace.reset()


func test_a_board_showing_a_40_by_24_map_sizes_the_board_space_to_it() -> void:
	var board := Board.new()
	board.build_on_ready = false
	add_child_autofree(board)
	board.show_map(MapGen.generate(1, 40, 24))
	assert_eq(BoardSpace.size(), Vector2(40.0, 24.0))
	assert_eq(BoardSpace.cell_to_world(0, 0), Vector3(-19.5, 0.0, -11.5))


func test_a_board_that_leaves_the_tree_and_comes_back_takes_its_map_size_again() -> void:
	var board := Board.new()
	board.build_on_ready = false
	add_child_autofree(board)
	board.show_map(MapGen.generate(1, 40, 24))
	remove_child(board)
	assert_eq(BoardSpace.size(), Vector2(RULES.GRID_COLS, RULES.GRID_ROWS))
	add_child(board)
	assert_eq(BoardSpace.size(), Vector2(40.0, 24.0))


func test_freeing_the_board_gives_the_game_board_size_back() -> void:
	var board := Board.new()
	board.build_on_ready = false
	add_child(board)
	board.show_map(MapGen.generate(1, 40, 24))
	board.free()
	assert_eq(BoardSpace.size(), Vector2(RULES.GRID_COLS, RULES.GRID_ROWS))
