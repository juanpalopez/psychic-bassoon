## The game's public entry: create it from a seed, submit commands, run ticks.
##
## Ported from `src/sim/game/game.ts`. Player actions arrive only as commands,
## queued by `submit` and run, in order, at the start of the next `tick`.
class_name Game
extends RefCounted

const RULES := preload("res://content/game_rules.gd")
const MAP_RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")

## Length of every simulation tick, in seconds. It never changes.
const TICK_SECONDS := 1.0 / RULES.TICK_RATE


## Creates the game for a seed, on tick 0.
static func create(seed: int) -> GameState:
	var game := GameState.new()
	game.seed = seed
	game.map = MapGen.generate(seed)
	for cells in game.map.routes:
		game.routes.append(Route.build(cells))
	game.route = game.routes[0]
	game.gold = RULES.START_GOLD
	game.lives = RULES.START_LIVES
	game.rng = Rng.derive(seed, Streams.WAVES)
	game.route_rng = Rng.derive(seed, Streams.ROUTES)
	return game


## Queues a command for the next tick. Does not change the game itself.
static func submit(game: GameState, command: Command) -> void:
	game.pending.append(command)


## Runs one fixed simulation tick: queued commands first, in order, then the
## systems. Mutates `game` in place.
static func tick(game: GameState) -> void:
	game.events = []
	var commands := game.pending
	game.pending = []
	for command in commands:
		_apply(game, command)
	game.tick_count += 1


static func _reject(game: GameState, command: Command, reason: GameEvent.RejectReason) -> void:
	game.events.append(GameEvent.rejected(command, reason))


## Towers go on sockets only.
static func _is_socket(game: GameState, col: int, row: int) -> bool:
	return game.map.is_socket(Vector2i(col, row))


static func _find_tower(game: GameState, id: int) -> Tower:
	for tower in game.towers:
		if tower.id == id:
			return tower
	return null


static func _build(game: GameState, command: Command) -> void:
	if not TOWERS.DEFS.has(command.tower):
		return _reject(game, command, GameEvent.RejectReason.UNKNOWN_TOWER)
	if not _is_socket(game, command.col, command.row):
		return _reject(game, command, GameEvent.RejectReason.NOT_A_SOCKET)
	for other in game.towers:
		if other.col == command.col and other.row == command.row:
			return _reject(game, command, GameEvent.RejectReason.OCCUPIED)
	var cost: int = TOWERS.DEFS[command.tower].cost[0]
	if game.gold < cost:
		return _reject(game, command, GameEvent.RejectReason.NOT_ENOUGH_GOLD)
	game.gold -= cost
	var tower := Tower.new()
	tower.id = game.next_id
	game.next_id += 1
	tower.type = command.tower
	tower.col = command.col
	tower.row = command.row
	tower.invested = cost
	game.towers.append(tower)
	var event := GameEvent.of(GameEvent.Kind.TOWER_BUILT)
	event.tower_id = tower.id
	game.events.append(event)


static func _upgrade(game: GameState, command: Command) -> void:
	var tower := _find_tower(game, command.tower_id)
	if tower == null:
		return _reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	var costs: Array = TOWERS.DEFS[tower.type].cost
	if tower.level + 1 >= costs.size():
		return _reject(game, command, GameEvent.RejectReason.MAX_LEVEL)
	var cost: int = costs[tower.level + 1]
	if game.gold < cost:
		return _reject(game, command, GameEvent.RejectReason.NOT_ENOUGH_GOLD)
	game.gold -= cost
	tower.invested += cost
	tower.level += 1
	var event := GameEvent.of(GameEvent.Kind.TOWER_UPGRADED)
	event.tower_id = tower.id
	event.level = tower.level
	game.events.append(event)


static func _sell(game: GameState, command: Command) -> void:
	var tower := _find_tower(game, command.tower_id)
	if tower == null:
		return _reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	var refund := int(floor(float(tower.invested) * RULES.SELL_REFUND))
	game.gold += refund
	game.towers.erase(tower)
	var event := GameEvent.of(GameEvent.Kind.TOWER_SOLD)
	event.tower_id = tower.id
	event.refund = refund
	game.events.append(event)


static func _launch_wave(game: GameState, command: Command) -> void:
	if game.running and not game.spawners.is_empty():
		return _reject(game, command, GameEvent.RejectReason.WAVE_IN_PROGRESS)
	var early_bonus := 0
	if game.running:
		early_bonus = RULES.EARLY_CALL_BASE + game.wave * RULES.EARLY_CALL_PER_WAVE
	game.gold += early_bonus
	game.wave += 1
	game.running = true
	# the wave's spawner is created by the waves context (Phase 4, step 5)
	var event := GameEvent.of(GameEvent.Kind.WAVE_LAUNCHED)
	event.wave = game.wave
	event.early_bonus = early_bonus
	game.events.append(event)


static func _apply(game: GameState, command: Command) -> void:
	if game.over:
		return _reject(game, command, GameEvent.RejectReason.GAME_OVER)
	match command.kind:
		Command.Kind.BUILD:
			_build(game, command)
		Command.Kind.UPGRADE:
			_upgrade(game, command)
		Command.Kind.SELL:
			_sell(game, command)
		Command.Kind.LAUNCH_WAVE:
			_launch_wave(game, command)
