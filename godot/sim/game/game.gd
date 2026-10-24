## The game's public entry: create it from a seed, submit commands, run ticks.
##
## Ported from `web-three-final:src/sim/game/game.ts`. Player actions arrive only as commands,
## queued by `submit` and run, in order, at the start of the next `tick`.
class_name Game
extends RefCounted

const RULES := preload("res://content/game_rules.gd")
const MAP_RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const HEROES := preload("res://content/heroes.gd")

## Length of every simulation tick, in seconds. It never changes.
const TICK_SECONDS := 1.0 / RULES.TICK_RATE


## Creates the game for a seed, on tick 0.
static func create(
	seed: int,
	cols: int = MAP_RULES.GRID_COLS,
	rows: int = MAP_RULES.GRID_ROWS,
	with_detour: bool = MAP_RULES.GAME_DETOUR,
	footprint: int = MAP_RULES.GAME_SOCKET_FOOTPRINT,
	second_source: bool = MAP_RULES.GAME_SECOND_SOURCE
) -> GameState:
	var game_map := _map_for(seed, cols, rows, with_detour, footprint, second_source)
	# every run on the game board starts with the Knight (owner, 2026-10-22); a mechanic test
	# places it on its own board when it needs it
	var on_game_board := _is_game_board(cols, rows, with_detour, footprint, second_source)
	return from_map(seed, game_map, with_detour, on_game_board)


## Creates the game on a map that is already made, on tick 0 (`create` calls it, and a test
## plays a hand-made map with it). `with_detour` is the old random lane; `with_hero` places the
## starting hero.
static func from_map(
	seed: int, map: GameMap, with_detour: bool = false, with_hero: bool = false
) -> GameState:
	var game := GameState.new()
	game.seed = seed
	game.map = map
	# the valley board walks curves through the road's corners (#321); the classic boards keep
	# the grid route their tests pin
	game.routes = Route.for_map(game.map)
	game.route = game.routes[0]
	var block := game.map.heartstone
	var heart_x := float(block.position.x) + float(block.size.x) / 2.0
	var heart_y := float(block.position.y) + float(block.size.y) / 2.0
	for route in game.routes:
		var start := route.position_at(0.0)
		game.air_routes.append(Route.straight(start.x, start.y, heart_x, heart_y))
	# foes pick a lane at random only on the old detour; the second source is by wave and group
	game.random_lanes = with_detour and game.routes.size() > 1
	if game.map.feeder_length > 0:
		game.second_offset = Route.join_offset(
			game.routes[0], game.routes[1], game.map.feeder_length, game.map.join_index
		)
	game.buttons = RULES.START_BUTTONS
	game.heartstone_health = RULES.START_HEARTSTONE_HEALTH
	game.rng = Rng.derive(seed, Streams.WAVES)
	game.route_rng = Rng.derive(seed, Streams.ROUTES)
	if with_hero:
		Heroes.place(game, HEROES.START_HERO)
	return game


## The game board (32 by 20, one road, 2x2 sockets, a second spawn source) is the sectioned
## valley (#381); any other board is the route-first generator, which the mechanic tests and the
## frozen fixtures name. The valley falls back to the route-first map if its sections cannot be
## made to pass (the stitcher has already logged why).
static func _map_for(
	seed: int, cols: int, rows: int, with_detour: bool, footprint: int, second_source: bool
) -> GameMap:
	if _is_game_board(cols, rows, with_detour, footprint, second_source):
		return MapGen.game_map(seed)
	return MapGen.generate(seed, cols, rows, with_detour, footprint, second_source)


## The game board: 32 by 20, one road, 2x2 sockets and a second spawn source.
static func _is_game_board(
	cols: int, rows: int, with_detour: bool, footprint: int, second_source: bool
) -> bool:
	return (
		cols == MAP_RULES.GRID_COLS
		and rows == MAP_RULES.GRID_ROWS
		and footprint == MAP_RULES.GAME_SOCKET_FOOTPRINT
		and second_source
		and not with_detour
	)


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
	if not game.over and not game.won:
		Heroes.step(game)
		WaveRunner.step_spawners(game)
		Combat.step(game)
		if not game.over:
			WaveRunner.settle(game)
	game.tick_count += 1


static func reject(game: GameState, command: Command, reason: GameEvent.RejectReason) -> void:
	game.events.append(GameEvent.rejected(command, reason))


## Towers go on sockets only.
static func _is_socket(game: GameState, col: int, row: int) -> bool:
	return game.map.is_socket(Vector2i(col, row))


static func find_tower(game: GameState, id: int) -> Tower:
	for tower in game.towers:
		if tower.id == id:
			return tower
	return null


static func _build(game: GameState, command: Command) -> void:
	if not TOWERS.DEFS.has(command.tower):
		return reject(game, command, GameEvent.RejectReason.UNKNOWN_TOWER)
	if not _is_socket(game, command.col, command.row):
		return reject(game, command, GameEvent.RejectReason.NOT_A_SOCKET)
	for other in game.towers:
		if other.col == command.col and other.row == command.row:
			return reject(game, command, GameEvent.RejectReason.OCCUPIED)
	var cost: int = TOWERS.DEFS[command.tower].cost[0]
	if game.buttons < cost:
		return reject(game, command, GameEvent.RejectReason.NOT_ENOUGH_BUTTONS)
	game.buttons -= cost
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
	if TOWERS.DEFS[tower.type].get("guards", false):
		Barracks.raise_guards(game, tower)


static func _upgrade(game: GameState, command: Command) -> void:
	var tower := find_tower(game, command.tower_id)
	if tower == null:
		return reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	var costs: Array = TOWERS.DEFS[tower.type].cost
	if tower.level + 1 >= costs.size():
		return reject(game, command, GameEvent.RejectReason.MAX_LEVEL)
	var cost: int = costs[tower.level + 1]
	if game.buttons < cost:
		return reject(game, command, GameEvent.RejectReason.NOT_ENOUGH_BUTTONS)
	game.buttons -= cost
	tower.invested += cost
	tower.level += 1
	if TOWERS.DEFS[tower.type].get("guards", false):
		Barracks.level_up(game, tower)
	var event := GameEvent.of(GameEvent.Kind.TOWER_UPGRADED)
	event.tower_id = tower.id
	event.level = tower.level
	game.events.append(event)


static func _sell(game: GameState, command: Command) -> void:
	var tower := find_tower(game, command.tower_id)
	if tower == null:
		return reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	var refund := int(floor(float(tower.invested) * RULES.SELL_REFUND))
	game.buttons += refund
	game.towers.erase(tower)
	Barracks.release_guards(game, tower)
	var event := GameEvent.of(GameEvent.Kind.TOWER_SOLD)
	event.tower_id = tower.id
	event.refund = refund
	game.events.append(event)


static func _launch_wave(game: GameState, command: Command) -> void:
	# the run ends when the win wave is cleared, so no wave comes after it
	if game.wave >= RULES.WIN_WAVE:
		return reject(game, command, GameEvent.RejectReason.FINAL_WAVE)
	if game.running and not game.spawners.is_empty():
		return reject(game, command, GameEvent.RejectReason.WAVE_IN_PROGRESS)
	var early_bonus := 0
	if game.running:
		early_bonus = RULES.EARLY_CALL_BASE + game.wave * RULES.EARLY_CALL_PER_WAVE
	game.buttons += early_bonus
	game.wave += 1
	game.running = true
	WaveRunner.start(game)
	var event := GameEvent.of(GameEvent.Kind.WAVE_LAUNCHED)
	event.wave = game.wave
	event.early_bonus = early_bonus
	game.events.append(event)


static func _apply(game: GameState, command: Command) -> void:
	if game.won:
		return reject(game, command, GameEvent.RejectReason.GAME_WON)
	if game.over:
		return reject(game, command, GameEvent.RejectReason.GAME_OVER)
	match command.kind:
		Command.Kind.BUILD:
			_build(game, command)
		Command.Kind.UPGRADE:
			_upgrade(game, command)
		Command.Kind.SELL:
			_sell(game, command)
		Command.Kind.LAUNCH_WAVE:
			_launch_wave(game, command)
		Command.Kind.CHOOSE_SPEC:
			Specs.choose(game, command)
		Command.Kind.ACTIVATE_ABILITY:
			Specs.activate(game, command)
		Command.Kind.MOVE_HERO:
			Heroes.order(game, command)
