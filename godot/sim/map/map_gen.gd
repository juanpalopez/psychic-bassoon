## Builds the board for a seed. The same seed always gives the same map, and
## equals the TypeScript sim's (`src/sim/map/mapgen.ts`): it draws only from
## its own stream, so other subsystems cannot shift it.
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


## Builds the map for a seed.
static func generate(seed: int) -> GameMap:
	var rng := Rng.derive(seed, Streams.MAP)
	for attempt in RULES.MAX_ATTEMPTS:
		var path := _try_path(rng)
		if path.is_empty():
			continue
		var map := GameMap.new()
		map.seed = seed
		map.path = path
		map.routes = [path]
		var detour := _add_detour(path, rng)
		if not detour.is_empty():
			map.routes.append(detour)
		map.tiles = _tiles_for(map.routes)
		SocketPlacer.place(map)
		return map
	push_error("no valid map for seed %d in %d tries" % [seed, RULES.MAX_ATTEMPTS])
	return null


## One attempt at the main road. Returns an empty array when it came out short.
static func _try_path(rng: Rng) -> Array[Vector2i]:
	var col: int = RULES.START_MARGIN + rng.next_int(RULES.GRID_COLS - 2 * RULES.START_MARGIN)
	var row := 0
	var cells: Array[Vector2i] = [Vector2i(col, row)]
	while row < RULES.GRID_ROWS - 1:
		var run := mini(
			RULES.MIN_RUN_DOWN + rng.next_int(RULES.RUN_DOWN_VARIANCE), RULES.GRID_ROWS - 1 - row
		)
		for i in run:
			row += 1
			cells.append(Vector2i(col, row))
		if row >= RULES.GRID_ROWS - 1:
			break
		var target := rng.next_int(RULES.GRID_COLS)
		while absi(target - col) < RULES.MIN_TURN_COLUMNS:
			target = rng.next_int(RULES.GRID_COLS)
		var step := signi(target - col)
		while col != target:
			col += step
			cells.append(Vector2i(col, row))
	if cells.size() >= RULES.GRID_ROWS + RULES.MIN_EXTRA_CELLS:
		return cells
	return []


static func _gap(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Every detour that fits: a straight run of `DETOUR_MIN_RUN` or more cells is
## paralleled `DETOUR_OFFSET` cells to one side, joined by a one-cell connector
## at each end (so a plot is left between the roads). It must stay on the board
## and never touch the main road except at its two joins.
static func _detour_candidates(path: Array[Vector2i]) -> Array[Detour]:
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
						if _fits(cells, path, on_path, from_index, to_index):
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
	to_index: int
) -> bool:
	for cell in cells:
		if cell.x < 0 or cell.x >= RULES.GRID_COLS or cell.y < 0 or cell.y >= RULES.GRID_ROWS:
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
static func _add_detour(path: Array[Vector2i], rng: Rng) -> Array[Vector2i]:
	var candidates := _detour_candidates(path)
	if candidates.is_empty():
		return []
	var pick: Detour = candidates[rng.next_int(candidates.size())]
	var route: Array[Vector2i] = []
	route.append_array(path.slice(0, pick.from_index + 1))
	route.append_array(pick.cells)
	route.append_array(path.slice(pick.to_index))
	return route


static func _tiles_for(routes: Array) -> Array[PackedByteArray]:
	var tiles: Array[PackedByteArray] = []
	for row in RULES.GRID_ROWS:
		var line := PackedByteArray()
		line.resize(RULES.GRID_COLS)
		line.fill(GameMap.Tile.PLOT)
		tiles.append(line)
	for route in routes:
		for cell in route:
			tiles[cell.y][cell.x] = GameMap.Tile.ROAD
	return tiles
