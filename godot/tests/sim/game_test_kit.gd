## Shared helpers for the game tests.
class_name GameTestKit
extends RefCounted


## The index-th socket of the map (they are in reading order).
static func socket(game: GameState, index: int = 0) -> Vector2i:
	return game.map.sockets[index]


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
				tower.cooldown,
				tower.target_id
			]
		)
	var foes := []
	for foe in game.foes:
		foes.append(
			[
				foe.id,
				foe.type,
				foe.route,
				foe.hp,
				foe.speed,
				foe.reward,
				foe.armor,
				foe.slow,
				foe.distance,
				foe.x,
				foe.y
			]
		)
	var spawners := []
	for spawner in game.spawners:
		var queue := []
		for order in spawner.queue:
			queue.append([order.type, order.gap])
		spawners.append([spawner.wave, spawner.timer, queue])
	var routes := []
	for route in game.map.routes:
		var cells := []
		for cell in route:
			cells.append([cell.x, cell.y])
		routes.append(cells)
	return {
		"seed": game.seed,
		"tick": game.tick_count,
		"buttons": game.buttons,
		"kingdom_health": game.kingdom_health,
		"wave": game.wave,
		"running": game.running,
		"over": game.over,
		"towers": towers,
		"routes": routes,
		"foes": foes,
		"spawners": spawners,
		"rngState": game.rng.state,
		"routeRngState": game.route_rng.state,
		"nextId": game.next_id,
		"pending": game.pending.size(),
		"events": game.events.size(),
	}
