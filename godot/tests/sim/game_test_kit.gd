## Shared helpers for the game tests.
class_name GameTestKit
extends RefCounted

const MAP_RULES := preload("res://content/map_rules.gd")


## The index-th plot cell in reading order.
static func plot(game: GameState, index: int = 0) -> Vector2i:
	var cells: Array[Vector2i] = []
	for row in MAP_RULES.GRID_ROWS:
		for col in MAP_RULES.GRID_COLS:
			if game.map.tiles[row][col] == GameMap.Tile.PLOT:
				cells.append(Vector2i(col, row))
	return cells[index]


static func run(game: GameState, commands: Array[Command]) -> Array[GameEvent]:
	for command in commands:
		Game.submit(game, command)
	Game.tick(game)
	return game.events


static func build_at(type: String, cell: Vector2i) -> Command:
	return Command.build(type, cell.x, cell.y)
