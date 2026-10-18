## Builds the board for a seed. The same seed always gives the same map, and it
## draws only from its own stream, so other subsystems cannot shift it. At the
## original 9 by 13 board, with a detour, it equals the TypeScript sim's maps
## (`web-three-final:src/sim/map/mapgen.ts`, frozen as fixtures).
##
## The road generator draws a road that runs down a tall board. A wide board
## (more columns than rows, the game's 32 by 20) is made by drawing on the turned
## grid (rows by columns) and turning the cells back, so the road crosses
## the long side from the left edge to the right.
class_name MapGen
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## The numbers that shape a board's road and its sockets: the classic ones (the fixtures' 9 by
## 13, the 16 by 11) or the valley's (a board at least `VALLEY_MIN_COLS` wide, #320).
class Shape:
	extends RefCounted
	var min_run_down: int = RULES.MIN_RUN_DOWN
	var run_down_variance: int = RULES.RUN_DOWN_VARIANCE
	var min_turn_columns: int = RULES.MIN_TURN_COLUMNS
	## 0: a turn may cross the whole board.
	var max_turn_columns: int = 0
	var min_extra_cells: int = RULES.MIN_EXTRA_CELLS
	var socket_min: int = RULES.SOCKET_MIN
	var socket_max: int = RULES.SOCKET_MAX


## The shape for a board of `cols` by `rows` cells.
static func shape_for(cols: int, _rows: int) -> Shape:
	var shape := Shape.new()
	if cols >= RULES.VALLEY_MIN_COLS:
		shape.min_run_down = RULES.VALLEY_MIN_RUN_DOWN
		shape.run_down_variance = RULES.VALLEY_RUN_DOWN_VARIANCE
		shape.min_turn_columns = RULES.VALLEY_MIN_TURN_COLUMNS
		shape.max_turn_columns = RULES.VALLEY_MAX_TURN_COLUMNS
		shape.min_extra_cells = RULES.VALLEY_MIN_EXTRA_CELLS
		shape.socket_min = RULES.VALLEY_SOCKET_MIN
		shape.socket_max = RULES.VALLEY_SOCKET_MAX
	return shape


## A way to grow a second route beside a straight stretch of the main road.
class Detour:
	extends RefCounted
	## Indices in the main path where the detour leaves and where it rejoins.
	var from_index: int = 0
	var to_index: int = 0
	## The cells walked on the detour, in order, not including the two joins.
	var cells: Array[Vector2i] = []


## Builds the map for a seed on a board of `cols` by `rows` cells. With
## `with_detour` a second route may leave the main road, run beside it and rejoin. With
## `second_source` (a wide board, no detour) a second spawn source may be added: a road from
## the top or bottom edge that joins the main road, as `routes[1]`.
## A road that leaves room for fewer than its shape's socket minimum is drawn again.
static func generate(
	seed: int,
	cols: int = RULES.GRID_COLS,
	rows: int = RULES.GRID_ROWS,
	with_detour: bool = RULES.GAME_DETOUR,
	footprint: int = RULES.GAME_SOCKET_FOOTPRINT,
	second_source: bool = RULES.GAME_SECOND_SOURCE
) -> GameMap:
	var wide := cols > rows
	var tall_cols := rows if wide else cols
	var tall_rows := cols if wide else rows
	var shape := shape_for(cols, rows)
	var rng := Rng.derive(seed, Streams.MAP)
	var feeder_rng := Rng.derive(seed, Streams.SECOND_SOURCE)
	for attempt in RULES.MAX_ATTEMPTS:
		var path := _try_path(rng, tall_cols, tall_rows, shape)
		if path.is_empty():
			continue
		var routes: Array = [path]
		if with_detour:
			var detour := _add_detour(path, rng, tall_cols, tall_rows)
			if not detour.is_empty():
				routes.append(detour)
		# the road a seed gets never depends on the second source: this road is judged as it
		# always was, and only then does the second road try to fit beside it
		var plain := _assemble(seed, cols, rows, footprint, wide, routes, {})
		# a road with too little room for the sockets is thrown away for another
		if not SocketPlacer.place(plain, shape.socket_min, shape.socket_max):
			continue
		if second_source and wide and not with_detour:
			for feeder in _feeders(path, feeder_rng, tall_cols, tall_rows):
				var with_feeder := routes.duplicate()
				with_feeder.append(feeder.route)
				var map := _assemble(seed, cols, rows, footprint, wide, with_feeder, feeder)
				if SocketPlacer.place(map, shape.socket_min, shape.socket_max):
					return map
		return plain
	push_error("no valid map for seed %d in %d tries" % [seed, RULES.MAX_ATTEMPTS])
	return null


## A map for these routes (in the tall grid when `wide`), before its sockets are placed.
static func _assemble(
	seed: int, cols: int, rows: int, footprint: int, wide: bool, routes: Array, feeder: Dictionary
) -> GameMap:
	var turned := _turned(routes) if wide else routes
	var map := GameMap.new()
	map.seed = seed
	map.cols = cols
	map.rows = rows
	map.footprint = footprint
	map.routes = turned
	map.path = turned[0]
	if not feeder.is_empty():
		map.feeder_length = feeder.length
		map.join_index = feeder.join_index
	map.tiles = _tiles_for(turned, cols, rows)
	map.heartstone = _heartstone_block(map.path[map.path.size() - 1], cols, rows, footprint)
	return map


## The Heartstone's footprint: the block of `footprint` cells that holds the
## road's last cell, pulled in to stay on the board. On the landscape board the
## road ends on the right edge, so the block ends there too; vertically it starts
## on the end's row and reaches down, or sits one row higher when the end is on
## the bottom row (just that one cell when the footprint is 1).
static func _heartstone_block(last: Vector2i, cols: int, rows: int, footprint: int) -> Rect2i:
	var anchor := Vector2i(mini(last.x, cols - footprint), mini(last.y, rows - footprint))
	return Rect2i(anchor, Vector2i(footprint, footprint))


## The routes with every cell's column and row swapped.
static func _turned(routes: Array) -> Array:
	var out: Array = []
	for route in routes:
		var cells: Array[Vector2i] = []
		for cell in route:
			cells.append(Vector2i(cell.y, cell.x))
		out.append(cells)
	return out


## One attempt at the main road. Returns an empty array when it came out short.
## The classic shape draws exactly the ported generator's numbers, so the fixtures still match.
static func _try_path(rng: Rng, cols: int, rows: int, shape: Shape = null) -> Array[Vector2i]:
	if shape == null:
		shape = Shape.new()
	var col: int = RULES.START_MARGIN + rng.next_int(cols - 2 * RULES.START_MARGIN)
	var row := 0
	var cells: Array[Vector2i] = [Vector2i(col, row)]
	while row < rows - 1:
		var run := mini(shape.min_run_down + rng.next_int(shape.run_down_variance), rows - 1 - row)
		for i in run:
			row += 1
			cells.append(Vector2i(col, row))
		if row >= rows - 1:
			break
		var target := _turn_target(rng, col, cols, shape)
		var step := signi(target - col)
		while col != target:
			col += step
			cells.append(Vector2i(col, row))
	if cells.size() >= rows + shape.min_extra_cells:
		return cells
	return []


## The column a sideways turn goes to: at least `min_turn_columns` away and, in the valley, at
## most `max_turn_columns` (drawn among the columns in that reach, so a cap costs no extra draws).
static func _turn_target(rng: Rng, col: int, cols: int, shape: Shape) -> int:
	if shape.max_turn_columns <= 0:
		var target := rng.next_int(cols)
		while absi(target - col) < shape.min_turn_columns:
			target = rng.next_int(cols)
		return target
	var reachable: Array[int] = []
	for target in cols:
		var gap := absi(target - col)
		if gap >= shape.min_turn_columns and gap <= shape.max_turn_columns:
			reachable.append(target)
	return reachable[rng.next_int(reachable.size())]


static func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Every detour that fits: a straight run of `DETOUR_MIN_RUN` or more cells is
## paralleled `DETOUR_OFFSET` cells to one side, joined by a one-cell connector
## at each end (so a plot is left between the roads). It must stay on the board
## and never touch the main road except at its two joins.
static func _detour_candidates(path: Array[Vector2i], cols: int, rows: int) -> Array[Detour]:
	var on_path := {}
	for cell in path:
		on_path[cell] = true
	var out: Array[Detour] = []
	var start := 0
	for i in range(1, path.size() + 1):
		var a := path[i - 1]
		var corner := path[start]
		if start + 1 >= path.size():
			continue
		var next := path[start + 1]
		var along_col := next.x == corner.x  # true: a vertical run
		var continues := false
		if i < path.size():
			var b := path[i]
			var same_line := b.x == corner.x if along_col else b.y == corner.y
			continues = same_line and _gap(a, b) == 1
		if continues:
			continue
		# the run is path[start .. i - 1]
		if i - start >= RULES.DETOUR_MIN_RUN:
			for side in [-1, 1]:
				for from_index in range(start + 1, i - 3):
					for to_index in range(from_index + 2, i - 1):
						var cells := _detour_cells(path, from_index, to_index, side, along_col)
						if _fits(cells, path, on_path, from_index, to_index, cols, rows):
							var detour := Detour.new()
							detour.from_index = from_index
							detour.to_index = to_index
							detour.cells = cells
							out.append(detour)
		# a corner cell ends one run and starts the next
		start = i - 1
	return out


static func _shift(cell: Vector2i, by: int, side: int, along_col: bool) -> Vector2i:
	if along_col:
		return Vector2i(cell.x + side * by, cell.y)
	return Vector2i(cell.x, cell.y + side * by)


static func _detour_cells(
	path: Array[Vector2i], from_index: int, to_index: int, side: int, along_col: bool
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.append(_shift(path[from_index], 1, side, along_col))
	for k in range(from_index, to_index + 1):
		cells.append(_shift(path[k], RULES.DETOUR_OFFSET, side, along_col))
	cells.append(_shift(path[to_index], 1, side, along_col))
	return cells


## True when the detour is on the board and clear of the main road, except at
## its two joins.
static func _fits(
	cells: Array[Vector2i],
	path: Array[Vector2i],
	on_path: Dictionary,
	from_index: int,
	to_index: int,
	cols: int,
	rows: int
) -> bool:
	for cell in cells:
		if cell.x < 0 or cell.x >= cols or cell.y < 0 or cell.y >= rows:
			return false
	var last_n := cells.size() - 1
	for n in cells.size():
		var d := cells[n]
		if on_path.has(d):
			return false
		for m in path.size():
			var g := _gap(d, path[m])
			var joins := (n == 0 and m == from_index) or (n == last_n and m == to_index)
			if not (g >= 2 or (g == 1 and joins)):
				return false
	return true


## Picks one detour (from the map's own stream) and returns the second route,
## or an empty array when none fits.
static func _add_detour(path: Array[Vector2i], rng: Rng, cols: int, rows: int) -> Array[Vector2i]:
	var candidates := _detour_candidates(path, cols, rows)
	if candidates.is_empty():
		return []
	var pick: Detour = candidates[rng.next_int(candidates.size())]
	var route: Array[Vector2i] = []
	route.append_array(path.slice(0, pick.from_index + 1))
	route.append_array(pick.cells)
	route.append_array(path.slice(pick.to_index))
	return route


## Every feeder that fits the main road, in an order drawn from its own stream, as
## `{route, length, join_index}` (the first that leaves room for the sockets is used). A feeder
## is a straight run along a row from the left or right edge of the tall grid (the top or
## bottom edge of the wide board) to the first main-road cell on that row. It stays two cells
## clear of the main road except at the join, the join is well inside the road, and the route
## is the feeder followed by the main road from the join on.
static func _feeders(path: Array[Vector2i], rng: Rng, cols: int, rows: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for side in [0, cols - 1]:
		var step := 1 if side == 0 else -1
		for row in range(RULES.FEEDER_ROW_MARGIN, rows - RULES.FEEDER_ROW_MARGIN):
			var candidate := _feeder_on_row(path, side, step, row, cols)
			if candidate.is_empty():
				continue
			var route: Array[Vector2i] = []
			route.append_array(candidate.cells)
			route.append_array(path.slice(candidate.join_index))
			(
				found
				. append(
					{
						"route": route,
						"length": candidate.cells.size(),
						"join_index": candidate.join_index,
					}
				)
			)
	for i in range(found.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := found[i]
		found[i] = found[j]
		found[j] = held
	return found


## The feeder along `row` from the edge column `side`, stepping `step` columns at a time, or an
## empty dictionary when it does not fit.
static func _feeder_on_row(
	path: Array[Vector2i], side: int, step: int, row: int, cols: int
) -> Dictionary:
	var cells: Array[Vector2i] = []
	var col := side
	var join_index := -1
	while join_index < 0:
		var at := path.find(Vector2i(col, row))
		if at >= 0:
			join_index = at
			break
		cells.append(Vector2i(col, row))
		col += step
		if col < 0 or col >= cols:
			return {}
	if cells.size() < RULES.FEEDER_MIN_CELLS:
		return {}
	var latest := mini(
		path.size() - RULES.FEEDER_JOIN_MARGIN, path.size() * RULES.FEEDER_JOIN_MAX_PERCENT / 100
	)
	if join_index < RULES.FEEDER_JOIN_MARGIN or join_index > latest:
		return {}
	var last := cells.size() - 1
	for n in cells.size():
		for m in path.size():
			var close := _gap(cells[n], path[m]) < RULES.FEEDER_CLEARANCE
			if close and not (n == last and m == join_index):
				return {}
	return {"cells": cells, "join_index": join_index}


static func _tiles_for(routes: Array, cols: int, rows: int) -> Array[PackedByteArray]:
	var tiles: Array[PackedByteArray] = []
	for row in rows:
		var line := PackedByteArray()
		line.resize(cols)
		line.fill(GameMap.Tile.PLOT)
		tiles.append(line)
	for route in routes:
		for cell in route:
			tiles[cell.y][cell.x] = GameMap.Tile.ROAD
	return tiles
