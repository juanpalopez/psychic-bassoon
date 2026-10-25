## Selecting the hero, sending it somewhere and seeing where it goes (#335).
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")
const PHONE_POINTS_PER_PIXEL := 0.54


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	main.points_per_pixel = PHONE_POINTS_PER_PIXEL
	add_child_autofree(main)
	await get_tree().process_frame
	return main


func _open_cell_far_from(game: GameState, from: Vector2i) -> Vector2i:
	var best := from
	for y in game.map.rows:
		for x in game.map.cols:
			var cell := Vector2i(x, y)
			if game.hero_graph.is_open(cell) and game.hero_graph.steps(from, cell) > 4:
				return cell
	return best


## The top of a cell's tile, where a tap on it lands.
func _surface_point(main: Node, cell: Vector2i) -> Vector3:
	var at := BoardSpace.cell_to_world(cell.x, cell.y)
	at.y = main._board.surface_height(cell)
	return at


func test_a_tap_on_the_hero_selects_it() -> void:
	var main := await _main()
	assert_false(main.hero_selected())
	main._on_tap(main._hero_on_screen(main.game().hero))
	assert_true(main.hero_selected())


func test_a_tap_on_a_walkable_cell_sends_the_selected_hero_by_command() -> void:
	var main := await _main()
	var game: GameState = main.game()
	main._on_tap(main._hero_on_screen(game.hero))
	var goal := _open_cell_far_from(game, game.hero.cell)
	assert_ne(goal, game.hero.cell)
	main._on_tap(main._camera.unproject_position(_surface_point(main, goal)))
	assert_eq(game.pending.size(), 1, "one command waits for the tick")
	var order := game.pending[0] as Command
	assert_eq(order.kind, Command.Kind.MOVE_HERO)
	assert_eq(Vector2i(order.col, order.row), goal, "it goes to the cell that was tapped")


func test_an_order_while_paused_says_it_waits_for_the_resume() -> void:
	var main := await _main()
	var game: GameState = main.game()
	main._speed.paused = true
	main._on_tap(main._hero_on_screen(game.hero))
	var goal := _open_cell_far_from(game, game.hero.cell)
	main._on_tap(main._camera.unproject_position(_surface_point(main, goal)))
	assert_eq((main.get_node("Hud/Message") as Label).text, "Paused: orders run when you resume")


func test_the_hero_rejections_have_words() -> void:
	for reason in [
		GameEvent.RejectReason.NO_HERO,
		GameEvent.RejectReason.NOT_WALKABLE,
		GameEvent.RejectReason.UNREACHABLE,
		GameEvent.RejectReason.HERO_FALLEN,
	]:
		assert_ne(RejectText.of(reason), "That did not work")


func test_the_walk_and_its_target_are_drawn_once_the_order_runs() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var goal := _open_cell_far_from(game, game.hero.cell)
	Game.submit(game, Command.move_hero(goal.x, goal.y))
	Game.tick(game)
	await get_tree().process_frame
	assert_true(main._hero_view.target_shown())
	assert_gt(HeroView.walk_points(game.hero.path, main._board.surface_height).size(), 1)


func test_a_tap_away_from_the_hero_does_nothing_to_it_when_it_is_not_selected() -> void:
	var main := await _main()
	main._on_tap(Vector2(5.0, 5.0))
	assert_false(main.hero_selected())
	assert_eq(main.game().pending.size(), 0)
