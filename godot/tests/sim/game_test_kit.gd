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


## The plain values of a game that must match between two games of one seed.
## Replays use the same idea (Phase 4, step 6); everything here is an int, a
## bool, a string or a float, so it survives JSON.
static func snapshot(game: GameState) -> Dictionary:
	var towers := []
	for tower in game.towers:
		towers.append(
			[
				tower.id,
				tower.type,
				tower.level,
				tower.col,
				tower.row,
				tower.invested,
				tower.cooldown
			]
		)
	var routes := []
	for route in game.map.routes:
		var cells := []
		for cell in route:
			cells.append([cell.x, cell.y])
		routes.append(cells)
	return {
		"seed": game.seed,
		"tick": game.tick_count,
		"gold": game.gold,
		"lives": game.lives,
		"wave": game.wave,
		"running": game.running,
		"over": game.over,
		"towers": towers,
		"routes": routes,
		"rngState": game.rng.state,
		"routeRngState": game.route_rng.state,
		"nextId": game.next_id,
		"pending": game.pending.size(),
		"events": game.events.size(),
	}
