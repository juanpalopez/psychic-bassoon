## Towers are built on sockets only (the GDD replaces free building).
extends GutTest

const MAP_RULES := preload("res://content/map_rules.gd")
const SEED := 42
const REASON := GameEvent.RejectReason


func assert_rejected_by(events: Array[GameEvent], command: Command, reason: REASON) -> void:
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(events[0].command, command)
	assert_eq(events[0].reason, reason)


func test_build_on_plain_ground_is_rejected_only_sockets_take_towers() -> void:
	var game := Game.create_on_strip_valley(SEED)
	var ground := Vector2i(-1, -1)
	for row in MAP_RULES.GRID_ROWS:
		for col in MAP_RULES.GRID_COLS:
			var cell := Vector2i(col, row)
			if game.map.tiles[row][col] == GameMap.Tile.PLOT and not game.map.is_socket(cell):
				ground = cell
	assert_ne(ground, Vector2i(-1, -1), "this seed has ground that is not a socket")
	var command := GameTestKit.build_at("spoolGuard", ground)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NOT_A_SOCKET)
	assert_eq(game.towers.size(), 0)


func test_every_socket_accepts_a_tower() -> void:
	var game := Game.create_on_strip_valley(SEED)
	game.buttons = 100000
	for cell in game.map.sockets:
		GameTestKit.run(game, [GameTestKit.build_at("spoolGuard", cell)])
	assert_eq(game.towers.size(), game.map.sockets.size())
