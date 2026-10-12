## Builds the board for a seed. The same seed always gives the same map, and it
## draws only from its own stream, so other subsystems cannot shift it. At the
## original 9 by 13 board, with a detour, it equals the TypeScript sim's maps
## (`src/sim/map/mapgen.ts`, frozen as fixtures).
##
## The road generator draws a road that runs down a tall board. A wide board
## (more columns than rows, the GDD's 22 by 16) is made by drawing on the turned
## grid (16 columns by 22 rows) and turning the cells back, so the road crosses
## the long side from the left edge to the right.
class_name MapGen
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## A way to grow a second route beside a straight stretch of the main road.
class Detour:
	extends RefCounted
	## Indices in the main path where the detour leaves and where it rejoins.
	var from_index: int = 0
	var to_index: int = 0
	## The cells walked on the detour, in order, not including the two joins.
	var cells: Array[Vector2i] = []


## Builds the map for a seed on a board of `cols` by `rows` cells. With
## `with_detour` a second route may leave the main road, run beside it and rejoin.
## A road that leaves room for fewer than 12 sockets is drawn again.
static func generate(
	seed: int,
	cols: int = RULES.GRID_COLS,
	rows: int = RULES.GRID_ROWS,
	with_detour: bool = RULES.GAME_DETOUR,
	footprint: int = RULES.GAME_SOCKET_FOOTPRINT
) -> GameMap:
	var wide := cols > rows
	var tall_cols := rows if wide else cols
	var tall_rows := cols if wide else rows
	var rng := Rng.derive(seed, Streams.MAP)
	for attempt in RULES.MAX_ATTEMPTS:
		var path := _try_path(rng, tall_cols, tall_rows)
		if path.is_empty():
			continue
		var routes: Array = [path]
		if with_detour:
			var detour := _add_detour(path, rng, tall_cols, tall_rows)
			if not detour.is_empty():
				routes.append(detour)
		if wide:
			routes = _turned(routes)
		var map := GameMap.new()
		map.seed = seed
		map.cols = cols
		map.rows = rows
		map.footprint = footprint
		map.routes = routes
		map.path = routes[0]
		map.tiles = _tiles_for(routes, cols, rows)
		map.heartstone = _heartstone_block(map.path[map.path.size() - 1], cols, rows, footprint)
		# a road with too little room for the sockets is thrown away for another
		if not SocketPlacer.place(map):
			continue
		return map
	push_error("no valid map for seed %d in %d tries" % [seed, RULES.MAX_ATTEMPTS])
	return null


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
static func _try_path(rng: Rng, cols: int, rows: int) -> Array[Vector2i]:
	var col: int = RULES.START_MARGIN + rng.next_int(cols - 2 * RULES.START_MARGIN)
	var row := 0
	var cells: Array[Vector2i] = [Vector2i(col, row)]
	while row < rows - 1:
		var run := mini(RULES.MIN_RUN_DOWN + rng.next_int(RULES.RUN_DOWN_VARIANCE), rows - 1 - row)
		for i in run:
			row += 1
			cells.append(Vector2i(col, row))
		if row >= rows - 1:
			break
		var target := rng.next_int(cols)
		while absi(target - col) < RULES.MIN_TURN_COLUMNS:
			target = rng.next_int(cols)
		var step := signi(target - col)
		while col != target:
			col += step
			cells.append(Vector2i(col, row))
	if cells.size() >= rows + RULES.MIN_EXTRA_CELLS:
		return cells
	return []


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
