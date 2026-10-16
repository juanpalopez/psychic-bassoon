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
				tower.target_id,
				tower.spec,
				tower.ability_cooldown
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
				foe.y,
				foe.engaged_guard_id,
				foe.attack_cooldown,
				foe.bleed_dps,
				foe.bleed_timer,
				foe.armor_strip,
				foe.freeze_timer,
				foe.blind,
				foe.blind_timer,
				foe.miss_tally,
				foe.cut_stacks,
				foe.cut_slow,
				foe.cut_timer
			]
		)
	var guards := []
	for guard in game.guards:
		guards.append(
			[
				guard.id,
				guard.tent_id,
				guard.hp,
				guard.max_hp,
				guard.armor,
				guard.damage,
				guard.cooldown,
				guard.post,
				guard.alive,
				guard.respawn_timer,
				guard.foe_id,
				guard.base_max_hp,
				guard.hp_bonus,
				guard.shield_hp,
				guard.shield_timer,
				guard.wall_timer
			]
		)
	var zones := []
	for zone in game.zones:
		zones.append(
			[
				zone.id,
				zone.kind,
				zone.tower_id,
				zone.x,
				zone.y,
				zone.route,
				zone.distance,
				zone.radius,
				zone.pull,
				zone.slow,
				zone.planes,
				zone.damage,
				zone.splash,
				zone.every,
				zone.clock,
				zone.timer
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
		"won": game.won,
		"tick": game.tick_count,
		"buttons": game.buttons,
		"heartstone_health": game.heartstone_health,
		"wave": game.wave,
		"running": game.running,
		"over": game.over,
		"towers": towers,
		"routes": routes,
		"foes": foes,
		"spawners": spawners,
		"guards": guards,
		"zones": zones,
		"rngState": game.rng.state,
		"routeRngState": game.route_rng.state,
		"nextId": game.next_id,
		"pending": game.pending.size(),
		"events": game.events.size(),
	}
