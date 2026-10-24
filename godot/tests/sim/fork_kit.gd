## A hand-made map where the road forks (#481): the helpers for the fork tests.
##
## No generated map forks yet, so the tests build one. It is a small mechanic board, 14 by 8
## cells, with grid routes (no curves): the main road along row 4, a branch that leaves it at
## cell 3 and rejoins at cell 9 by way of row 2, and a feeder from the south that joins at cell 5.
class_name ForkKit
extends RefCounted

const COLS := 14
const ROWS := 8
const MAIN_ROW := 4
const BRANCH_ROW := 2
const FORK_CELL := 3
const MERGE_CELL := 9
const FEEDER_ROW := 6
const FEEDER_JOIN := 5
## Sockets for the guard tests: one beside the branch, one beside the main road's stretch that
## the branch runs parallel to, one beside the tail they share, and one near the branch's guards.
const BRANCH_SOCKET := Vector2i(6, 1)
const MAIN_SOCKET := Vector2i(6, 6)
const TAIL_SOCKET := Vector2i(11, 6)
const AURA_SOCKET := Vector2i(7, 3)
## Equally near the main road and the branch (both rows are one cell from its middle).
const TIE_SOCKET := Vector2i(6, 3)
## A board this wide draws curved routes (`Route.for_map`): the branch's corners at the fork and
## the merge round, so its line differs from the main road's for a few cells there.
const CURVED_COLS := 24


## The map with a fork: routes `[main, feeder, branch]` and sources `[[0, 2], [1]]`.
static func map(cols: int = COLS) -> GameMap:
	var map := GameMap.new()
	map.cols = cols
	map.rows = ROWS
	map.heartstone = Rect2i(cols - 1, MAIN_ROW, 1, 1)
	for x in cols:
		map.path.append(Vector2i(x, MAIN_ROW))
	var feeder: Array[Vector2i] = []
	for x in range(0, FEEDER_JOIN + 1):
		feeder.append(Vector2i(x, FEEDER_ROW))
	feeder.append(Vector2i(FEEDER_JOIN, FEEDER_ROW - 1))
	map.feeder_length = feeder.size()
	map.join_index = FEEDER_JOIN
	var second: Array[Vector2i] = feeder.duplicate()
	second.append_array(map.path.slice(FEEDER_JOIN))
	var branch: Array[Vector2i] = []
	for x in range(0, FORK_CELL + 1):
		branch.append(Vector2i(x, MAIN_ROW))
	for y in range(MAIN_ROW - 1, BRANCH_ROW - 1, -1):
		branch.append(Vector2i(FORK_CELL, y))
	for x in range(FORK_CELL + 1, MERGE_CELL):
		branch.append(Vector2i(x, BRANCH_ROW))
	for y in range(BRANCH_ROW, MAIN_ROW):
		branch.append(Vector2i(MERGE_CELL, y))
	branch.append_array(map.path.slice(MERGE_CELL))
	map.routes = [map.path, second, branch]
	map.sources = [PackedInt32Array([0, 2]), PackedInt32Array([1])]
	var fork := GameMap.Fork.new()
	fork.route = 2
	fork.fork_index = FORK_CELL
	fork.merge_index = MERGE_CELL
	fork.branch_length = branch.size() - map.path.size() + (MERGE_CELL - FORK_CELL - 1)
	map.forks = [fork]
	map.sockets = [BRANCH_SOCKET, MAIN_SOCKET, TAIL_SOCKET, AURA_SOCKET, TIE_SOCKET]
	return map


## The map on a board wide enough for curved routes.
static func curved_map() -> GameMap:
	return map(CURVED_COLS)


## The same map without the fork: no branch route, no sources.
static func map_without_fork() -> GameMap:
	var map := map()
	map.routes.remove_at(2)
	map.sources = []
	map.forks = []
	return map


## A game on `map` that cannot be lost in the few waves a test plays.
static func game(map_seed: int = 1, on: GameMap = null) -> GameState:
	var game := Game.from_map(map_seed, on if on != null else map())
	game.heartstone_health = 1000000
	return game


## Launches wave `wave` and ticks until everything is spawned; returns each foe's route
## index, in spawn order, read the tick it appeared.
static func routes_spawned(game: GameState, wave: int) -> Array[int]:
	game.wave = wave - 1
	Game.submit(game, Command.launch_wave())
	var seen := {}
	var routes: Array[int] = []
	while not game.spawners.is_empty() or routes.is_empty():
		Game.tick(game)
		for foe in game.foes:
			if not seen.has(foe.id):
				seen[foe.id] = true
				routes.append(foe.route)
	return routes


## A game on the forked map (or `on`) with Buttons to spare and a Guard Tent on `anchor`.
static func game_with_tent(anchor: Vector2i, map_seed: int = 1, on: GameMap = null) -> GameState:
	var game := game(map_seed, on)
	game.buttons = 100000
	GameTestKit.run(game, [Command.build("guardTent", anchor.x, anchor.y)])
	return game


## The index in the branch route of the first cell it shares with the main road again.
static func branch_merge_cell(game: GameState) -> int:
	var fork := game.map.forks[0]
	return fork.fork_index + 1 + fork.branch_length
