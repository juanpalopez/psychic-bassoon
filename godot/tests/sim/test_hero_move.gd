extends GutTest

## The Knight on the game board and its move command (#450).

const HEROES := preload("res://content/heroes.gd")
const SEED := 42


func _valley() -> GameState:
	return Game.create(SEED)


func _knight_on_open_board() -> GameState:
	var game := Game.create(SEED, 16, 11)
	Heroes.place(game, HEROES.KNIGHT)
	return game


func _centre(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)


func _at(game: GameState) -> Vector2:
	return Vector2(game.hero.x, game.hero.y)


func _kinds(events: Array[GameEvent]) -> Array[GameEvent.Kind]:
	var kinds: Array[GameEvent.Kind] = []
	for event in events:
		kinds.append(event.kind)
	return kinds


func _move(game: GameState, cell: Vector2i) -> Array[GameEvent]:
	return GameTestKit.run(game, [Command.move_hero(cell.x, cell.y)] as Array[Command])


## Ticks until the hero arrives (at most `limit`), returning how many it took.
func _walk(game: GameState, limit: int) -> int:
	for count in limit:
		Game.tick(game)
		if _kinds(game.events).has(GameEvent.Kind.HERO_ARRIVED):
			return count + 1
	return -1


func test_the_game_board_starts_with_the_knight_at_full_health() -> void:
	var game := _valley()
	assert_not_null(game.hero)
	assert_eq(game.hero.type, HEROES.KNIGHT)
	assert_eq(game.hero.hp, float(HEROES.DEFS[HEROES.KNIGHT].hp))
	assert_true(game.hero.path.is_empty())
	assert_true(game.map.is_walkable(game.hero.cell))
	assert_eq(_at(game), _centre(game.hero.cell))


func test_the_knight_starts_on_the_road_at_the_heartstone() -> void:
	var game := _valley()
	var road := game.map.path
	var index := road.find(game.hero.cell)
	assert_gt(index, -1)
	for later in range(index + 1, road.size()):
		assert_false(game.map.is_walkable(road[later]), "%s" % road[later])


func test_a_mechanic_board_has_no_hero_unless_a_test_places_one() -> void:
	assert_null(Game.create(SEED, 16, 11).hero)
	assert_not_null(_knight_on_open_board().hero)


func test_the_knight_takes_no_id_from_the_towers() -> void:
	assert_eq(_valley().next_id, Game.create(SEED, 16, 11).next_id)


func test_a_move_is_ordered_then_walked_to_the_cell_centre() -> void:
	var game := _knight_on_open_board()
	var to := game.hero.cell + Vector2i(-3, 2)
	var events := _move(game, to)
	assert_true(_kinds(events).has(GameEvent.Kind.HERO_ORDERED))
	assert_gt(_walk(game, 600), 0)
	assert_eq(game.hero.cell, to)
	assert_eq(_at(game), _centre(to))
	assert_true(game.hero.path.is_empty())


func test_the_knight_walks_at_its_speed() -> void:
	var game := _knight_on_open_board()
	var from := _at(game)
	_move(game, game.hero.cell + Vector2i(-6, 0))
	for count in 10:
		Game.tick(game)
	# the order's own tick walks too, so 11 ticks of walking along one row
	var walked := absf(game.hero.x - from.x)
	var expected: float = float(HEROES.DEFS[HEROES.KNIGHT].speed) * 11.0 * Game.TICK_SECONDS
	assert_almost_eq(walked, expected, 0.000001)
	assert_eq(game.hero.y, from.y)


func test_the_arrival_tick_matches_the_walk_length() -> void:
	var game := _knight_on_open_board()
	_move(game, game.hero.cell + Vector2i(-4, 0))
	var speed: float = HEROES.DEFS[HEROES.KNIGHT].speed
	var ticks := int(ceil(4.0 / (speed * Game.TICK_SECONDS)))
	# the order's tick is the first of them; float steps may need one tick more
	var took := _walk(game, 600) + 1
	assert_between(took, ticks, ticks + 1)


func test_a_new_order_replaces_the_walk() -> void:
	var game := _knight_on_open_board()
	var start := game.hero.cell
	_move(game, start + Vector2i(-6, 0))
	for count in 5:
		Game.tick(game)
	var second := start + Vector2i(0, 3)
	_move(game, second)
	assert_gt(_walk(game, 600), 0)
	assert_eq(game.hero.cell, second)
	assert_true(game.hero.path.is_empty())


func test_a_move_on_the_valley_crosses_the_river_only_on_a_bridge() -> void:
	var game := _valley()
	var to: Vector2i = game.map.path[0]
	_move(game, to)
	var seen := {}
	for count in 3000:
		Game.tick(game)
		seen[game.hero.cell] = true
		if game.hero.path.is_empty():
			break
	assert_eq(game.hero.cell, to)
	for cell in seen:
		if game.map.river.has(cell):
			var bridged: bool = (
				game.map.hero_bridges.has(cell)
				or game.map.bridges.any(
					func(bridge: GameMap.Bridge) -> bool: return bridge.cell == cell
				)
			)
			assert_true(bridged, "%s" % cell)


func test_a_move_without_a_hero_is_rejected() -> void:
	var game := Game.create(SEED, 16, 11)
	var events := _move(game, Vector2i(2, 2))
	assert_eq(events.size(), 1)
	assert_eq(events[0].reason, GameEvent.RejectReason.NO_HERO)


func test_a_move_to_water_or_off_the_board_is_rejected() -> void:
	var game := _valley()
	var wet := Vector2i(-1, -1)
	for cell in game.map.river:
		if not game.map.is_walkable(cell) and not game.map.hero_bridges.has(cell):
			wet = cell
			break
	assert_ne(wet, Vector2i(-1, -1))
	for cell in [wet, Vector2i(-1, 0), Vector2i(game.map.cols, 0)]:
		var events := _move(game, cell)
		assert_eq(events.size(), 1, "%s" % cell)
		assert_eq(events[0].reason, GameEvent.RejectReason.NOT_WALKABLE, "%s" % cell)


func test_a_move_to_a_walled_off_cell_is_rejected() -> void:
	var game := _knight_on_open_board()
	var pocket := Vector2i(1, 1)
	for step in HeroGraph.NEIGHBOURS:
		var wall := pocket + step
		game.hero_graph.open[wall.y * game.hero_graph.cols + wall.x] = 0
	var events := _move(game, pocket)
	assert_eq(events.size(), 1)
	assert_eq(events[0].reason, GameEvent.RejectReason.UNREACHABLE)


func test_a_move_after_the_game_is_over_is_rejected() -> void:
	var game := _valley()
	game.over = true
	var events := _move(game, game.hero.cell)
	assert_eq(events[0].reason, GameEvent.RejectReason.GAME_OVER)


func test_the_same_seed_and_orders_walk_the_same_way() -> void:
	var first := _valley()
	var second := _valley()
	var to: Vector2i = first.map.path[0]
	for game in [first, second]:
		_move(game, to)
		for count in 200:
			Game.tick(game)
	assert_eq(_at(first), _at(second))
	assert_eq(first.hero.cell, second.hero.cell)
	assert_eq(first.hero.path, second.hero.path)


func test_repeating_an_order_mid_walk_keeps_the_hero_walking() -> void:
	# a drag or a double tap sends the same order again before a cell is walked; the hero must
	# carry on, not go back to the cell it left (#455 review)
	var game := _knight_on_open_board()
	var from := _at(game)
	var to := game.hero.cell + Vector2i(-6, 0)
	for count in 60:
		_move(game, to)
	var expected: float = float(HEROES.DEFS[HEROES.KNIGHT].speed) * 60.0 * Game.TICK_SECONDS
	assert_almost_eq(from.x - game.hero.x, expected, 0.000001)


func test_a_new_order_mid_walk_goes_back_only_when_its_way_turns() -> void:
	var game := _knight_on_open_board()
	var start := game.hero.cell
	_move(game, start + Vector2i(-6, 0))
	for count in 5:
		Game.tick(game)
	# still on the first leg, now sent down: it finishes nothing and turns back to its cell
	_move(game, start + Vector2i(0, 3))
	assert_eq(game.hero.path[0], start)


func test_the_order_event_names_the_target_cell_centre() -> void:
	var game := _knight_on_open_board()
	var to := game.hero.cell + Vector2i(-2, 1)
	var events := _move(game, to)
	for event in events:
		if event.kind == GameEvent.Kind.HERO_ORDERED:
			assert_eq(Vector2(event.x, event.y), _centre(to))


func test_an_order_to_its_own_cell_arrives_at_once() -> void:
	var game := _knight_on_open_board()
	var kinds := _kinds(_move(game, game.hero.cell))
	assert_true(kinds.has(GameEvent.Kind.HERO_ORDERED))
	assert_true(kinds.has(GameEvent.Kind.HERO_ARRIVED))


func test_the_hero_stops_when_the_game_is_won_or_over() -> void:
	for flag in ["won", "over"]:
		var game := _knight_on_open_board()
		_move(game, game.hero.cell + Vector2i(-6, 0))
		var at := _at(game)
		game.set(flag, true)
		for count in 30:
			Game.tick(game)
		assert_eq(_at(game), at, flag)


func test_a_move_after_the_game_is_won_is_rejected() -> void:
	var game := _valley()
	game.won = true
	var events := _move(game, game.hero.cell)
	assert_eq(events[0].reason, GameEvent.RejectReason.GAME_WON)
