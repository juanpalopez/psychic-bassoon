## The valley's terrain layer (#322): terrace heights, regions and a river with its bridge,
## built on a finished map (road and sockets placed) from its own stream, so it never moves the
## road or the sockets. Only boards with the valley shape get one; the classic boards stay flat
## (their heights are the socket levels) with no river.
##
## Heights come from a smooth value-noise field (random values on a coarse lattice, blended
## with a smoothstep, so only `+ - *` and `floor` are used) that rises away from the road (the
## valley), cut into terraces, then held down where the game needs it: the road and the river
## on the floor, low banks beside the road, each socket block on its own level. The river is
## the cheapest course down the board (it prefers low ground) through a road crossing drawn
## from the stream, where the road runs straight and the river crosses it straight on a bridge.
class_name TerrainGen
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
## Larger than any course's cost: a cell the river has not reached.
const UNREACHED := 1.0e30
const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## The cheapest courses from a start to every cell, flowing down a row at a time with side
## steps along a row: each reached cell's cost and the cell it came from (-1 at the start).
class Flow:
	extends RefCounted
	var best := PackedFloat64Array()
	var parent := PackedInt32Array()


## Fills `map.heights`, `map.regions`, `map.river` and `map.bridges`. Building it twice gives the
## same layer.
static func build(map: GameMap) -> void:
	map.heights = _levels_from_elevation(map)
	var meadow := PackedByteArray()
	meadow.resize(map.cols * map.rows)
	meadow.fill(GameMap.Region.MEADOW)
	map.regions = _rows_of(meadow, map)
	map.river = []
	map.bridges = []
	if map.cols < RULES.VALLEY_MIN_COLS:
		return
	var rng := Rng.derive(map.seed, Streams.TERRAIN)
	var field := _noise(rng, map.cols, map.rows)
	var detail := _noise(rng, map.cols, map.rows)
	var sockets := _socket_mask(map)
	var gaps := _road_gaps(map)
	_place_river(map, rng, field, gaps, sockets)
	var heights := _carve_heights(map, field, gaps, sockets)
	map.heights = _rows_of(heights, map)
	map.regions = _rows_of(_paint_regions(map, heights, detail, gaps, sockets), map)


## The classic layer: every cell at its socket level (0 off the sockets).
static func _levels_from_elevation(map: GameMap) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	for y in map.rows:
		var line := PackedByteArray()
		line.resize(map.cols)
		for x in map.cols:
			line[x] = map.elevation_at(Vector2i(x, y))
		out.append(line)
	return out


## A flat board-sized array (row after row) holding `value` in every cell.
static func _filled(map: GameMap, value: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(map.cols * map.rows)
	out.fill(value)
	return out


## A flat board-sized byte array cut into one `PackedByteArray` per row.
static func _rows_of(flat: PackedByteArray, map: GameMap) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	for y in map.rows:
		out.append(flat.slice(y * map.cols, (y + 1) * map.cols))
	return out


## 1 on the cells of every socket block, 0 elsewhere.
static func _socket_mask(map: GameMap) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.cols * map.rows)
	for anchor in map.sockets:
		for dy in map.footprint:
			for dx in map.footprint:
				out[(anchor.y + dy) * map.cols + anchor.x + dx] = 1
	return out


## A smooth field in [0, 1) over the board: random values every `TERRAIN_NOISE_CELL` cells,
## blended between them with a smoothstep.
static func _noise(rng: Rng, cols: int, rows: int) -> PackedFloat64Array:
	var step := float(RULES.TERRAIN_NOISE_CELL)
	var lattice_cols := int(floor(float(cols) / step)) + 2
	var lattice_rows := int(floor(float(rows) / step)) + 2
	var lattice := PackedFloat64Array()
	for k in lattice_cols * lattice_rows:
		lattice.append(rng.next_float())
	var out := PackedFloat64Array()
	for y in rows:
		var fy := (float(y) + 0.5) / step
		var j := int(floor(fy))
		var v := _smooth(fy - float(j))
		for x in cols:
			var fx := (float(x) + 0.5) / step
			var i := int(floor(fx))
			var u := _smooth(fx - float(i))
			var a := lattice[j * lattice_cols + i]
			var b := lattice[j * lattice_cols + i + 1]
			var c := lattice[(j + 1) * lattice_cols + i]
			var d := lattice[(j + 1) * lattice_cols + i + 1]
			var top := a + (b - a) * u
			var bottom := c + (d - c) * u
			out.append(top + (bottom - top) * v)
	return out


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Each cell's distance to the nearest road cell (Chebyshev, so the eight cells round a road
## cell are 1), by a breadth-first walk.
static func _road_gaps(map: GameMap) -> PackedInt32Array:
	var gaps := _filled(map, map.cols + map.rows)
	var queue := PackedInt32Array()
	for y in map.rows:
		for x in map.cols:
			if map.tiles[y][x] == GameMap.Tile.ROAD:
				gaps[y * map.cols + x] = 0
				queue.append(y * map.cols + x)
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var x := at % map.cols
		var y := (at - x) / map.cols
		for ny in range(maxi(0, y - 1), mini(map.rows, y + 2)):
			for nx in range(maxi(0, x - 1), mini(map.cols, x + 2)):
				var next := ny * map.cols + nx
				if gaps[next] > gaps[at] + 1:
					gaps[next] = gaps[at] + 1
					queue.append(next)
	return gaps


## Terraces from the field (rising away from the road), then the game's rules on top: the road
## and the river on the floor, low banks beside the road, each socket block on its own level,
## and no lone pit or spike.
static func _carve_heights(
	map: GameMap, field: PackedFloat64Array, gaps: PackedInt32Array, sockets: PackedByteArray
) -> PackedByteArray:
	var top: int = RULES.TERRAIN_LEVELS - 1
	var weight: float = RULES.TERRAIN_VALLEY_WEIGHT
	var reach := float(RULES.TERRAIN_VALLEY_REACH)
	var heights := PackedByteArray()
	heights.resize(map.cols * map.rows)
	var fixed := PackedByteArray()
	fixed.resize(map.cols * map.rows)
	for i in heights.size():
		var rise := minf(float(gaps[i]), reach) / reach
		var shape := field[i] * (1.0 - weight) + rise * weight
		var level := clampi(int(floor(shape * float(RULES.TERRAIN_LEVELS))), 0, top)
		if gaps[i] <= 1:
			level = mini(level, RULES.TERRAIN_ROADSIDE_MAX)
		if gaps[i] == 0:
			level = 0
			fixed[i] = 1
		heights[i] = level
	for cell in map.river:
		heights[cell.y * map.cols + cell.x] = 0
		fixed[cell.y * map.cols + cell.x] = 1
	for y in map.rows:
		for x in map.cols:
			if sockets[y * map.cols + x] == 1:
				heights[y * map.cols + x] = map.elevation_at(Vector2i(x, y))
				fixed[y * map.cols + x] = 1
	_smooth_lone_cells(map, heights, fixed, gaps)
	return heights


## A cell with no side neighbour within one terrace is pulled to one terrace from its nearest
## neighbour (a bank cell no higher than `TERRAIN_ROADSIDE_MAX`). Fixed cells (road, river,
## sockets) never move; the passes stop once nothing does.
static func _smooth_lone_cells(
	map: GameMap, heights: PackedByteArray, fixed: PackedByteArray, gaps: PackedInt32Array
) -> void:
	for pass_index in RULES.TERRAIN_SMOOTH_PASSES:
		var moved := false
		for y in map.rows:
			for x in map.cols:
				var at := y * map.cols + x
				if fixed[at] == 1:
					continue
				var here: int = heights[at]
				var nearest := -1
				var gap := RULES.TERRAIN_LEVELS
				for side in SIDES:
					var nx := x + side.x
					var ny := y + side.y
					if nx < 0 or nx >= map.cols or ny < 0 or ny >= map.rows:
						continue
					var there: int = heights[ny * map.cols + nx]
					if absi(there - here) < gap:
						gap = absi(there - here)
						nearest = there
				if gap <= 1 or nearest < 0:
					continue
				var level := nearest + 1 if here > nearest else nearest - 1
				if gaps[at] <= 1:
					level = mini(level, RULES.TERRAIN_ROADSIDE_MAX)
				if level != here:
					heights[at] = level
					moved = true
		if not moved:
			return


## Forest on the higher ground away from the road, rocks on the high terraces, dirt patches
## beside the road, meadow elsewhere; the road, the sockets and the river stay meadow (clear).
static func _paint_regions(
	map: GameMap,
	heights: PackedByteArray,
	detail: PackedFloat64Array,
	gaps: PackedInt32Array,
	sockets: PackedByteArray
) -> PackedByteArray:
	var clear := sockets.duplicate()
	for cell in map.river:
		clear[cell.y * map.cols + cell.x] = 1
	var out := PackedByteArray()
	out.resize(map.cols * map.rows)
	for i in out.size():
		var region := GameMap.Region.MEADOW
		var n := detail[i]
		if gaps[i] == 0 or clear[i] == 1:
			region = GameMap.Region.MEADOW
		elif heights[i] >= RULES.ROCKS_MIN_LEVEL and n < RULES.ROCKS_BELOW:
			region = GameMap.Region.ROCKS
		elif gaps[i] >= RULES.FOREST_ROAD_GAP and n > RULES.FOREST_ABOVE:
			region = GameMap.Region.FOREST
		elif gaps[i] <= RULES.DIRT_ROAD_GAP and n < RULES.DIRT_BELOW:
			region = GameMap.Region.DIRT
		out[i] = region
	return out


## Picks a road crossing with the stream and runs the cheapest course from the top edge down to
## it and on from it to the bottom edge; the next crossing is tried when no course reaches one,
## up to `RIVER_CROSSING_TRIES`. A map may end up without a river when none fits.
static func _place_river(
	map: GameMap,
	rng: Rng,
	field: PackedFloat64Array,
	gaps: PackedInt32Array,
	sockets: PackedByteArray
) -> void:
	var keep_off := _river_keep_off(map, sockets)
	var blocked := keep_off.duplicate()
	for i in blocked.size():
		if gaps[i] == 0:
			blocked[i] = 1
	var crossings := _crossings(map, keep_off, blocked)
	for i in range(crossings.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := crossings[i]
		crossings[i] = crossings[j]
		crossings[j] = held
	var cost := PackedFloat64Array()
	for i in field.size():
		var step: float = RULES.RIVER_STEP_COST + field[i] * RULES.RIVER_HIGH_GROUND_COST
		if gaps[i] == 1:
			step += RULES.RIVER_ROADSIDE_COST
		cost.append(step)
	for k in mini(crossings.size(), RULES.RIVER_CROSSING_TRIES):
		var bridge := crossings[k]
		var above := bridge - Vector2i(0, 1)
		var below := bridge + Vector2i(0, 1)
		var upper := _flow(map, blocked, cost, Vector2i(-1, 0), above.y)
		if upper.best[above.y * map.cols + above.x] >= UNREACHED:
			continue
		var lower := _flow(map, blocked, cost, below, map.rows - 1)
		var mouth := _cheapest_on_row(map, lower, map.rows - 1)
		if mouth < 0:
			continue
		var course := _course(map, upper, above.y * map.cols + above.x)
		course.append(bridge)
		course.append_array(_course(map, lower, mouth))
		map.river = course
		var span := GameMap.Bridge.new()
		span.cell = bridge
		span.horizontal = true
		span.path_index = map.path.find(bridge)
		map.bridges = [span]
		return


## 1 on the cells the river must keep off: the sockets, the Heartstone, the cells near a spawn
## and the columns within `RIVER_EDGE_MARGIN` of the left and right edges.
static func _river_keep_off(map: GameMap, sockets: PackedByteArray) -> PackedByteArray:
	var out := sockets.duplicate()
	var margin: int = RULES.RIVER_EDGE_MARGIN
	for y in map.rows:
		for x in map.cols:
			var cell := Vector2i(x, y)
			var off := x < margin or x >= map.cols - margin or map.heartstone.has_point(cell)
			for route in map.routes:
				var start: Vector2i = route[0]
				if absi(x - start.x) + absi(y - start.y) < RULES.RIVER_SPAWN_GAP:
					off = true
			if off:
				out[y * map.cols + x] = 1
	return out


## The main-road cells the river can cross straight: the road runs left to right through the
## cell and is one cell wide there, and the cells above and below are free for the river.
static func _crossings(
	map: GameMap, keep_off: PackedByteArray, blocked: PackedByteArray
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(1, map.path.size() - 1):
		var cell := map.path[i]
		if cell.y < 1 or cell.y > map.rows - 2:
			continue
		if map.path[i - 1] != cell - Vector2i(1, 0) or map.path[i + 1] != cell + Vector2i(1, 0):
			continue
		var at := cell.y * map.cols + cell.x
		if keep_off[at] == 1 or blocked[at - map.cols] == 1 or blocked[at + map.cols] == 1:
			continue
		out.append(cell)
	return out


## The cheapest courses from `start` (or from every free cell of its row when `start.x` is -1)
## down to `last_row`, never through a blocked cell.
static func _flow(
	map: GameMap, blocked: PackedByteArray, cost: PackedFloat64Array, start: Vector2i, last_row: int
) -> Flow:
	var flow := Flow.new()
	flow.best.resize(map.cols * map.rows)
	flow.best.fill(UNREACHED)
	flow.parent.resize(map.cols * map.rows)
	flow.parent.fill(-1)
	for x in map.cols:
		var at := start.y * map.cols + x
		if blocked[at] == 0 and (start.x < 0 or start.x == x):
			flow.best[at] = cost[at]
	for y in range(start.y, last_row + 1):
		var row := y * map.cols
		if y > start.y:
			for x in map.cols:
				var at := row + x
				if blocked[at] == 0 and flow.best[at - map.cols] < UNREACHED:
					flow.best[at] = flow.best[at - map.cols] + cost[at]
					flow.parent[at] = at - map.cols
		for x in range(1, map.cols):
			_relax(flow, blocked, cost, row + x, row + x - 1)
		for x in range(map.cols - 2, -1, -1):
			_relax(flow, blocked, cost, row + x, row + x + 1)
	return flow


## Reaches `at` from its side neighbour `from` when that is cheaper.
static func _relax(
	flow: Flow, blocked: PackedByteArray, cost: PackedFloat64Array, at: int, from: int
) -> void:
	if blocked[at] == 1 or flow.best[from] >= UNREACHED:
		return
	if flow.best[from] + cost[at] < flow.best[at]:
		flow.best[at] = flow.best[from] + cost[at]
		flow.parent[at] = from


## The cheapest reached cell of `row` (the leftmost among equals), or -1 when none is reached.
static func _cheapest_on_row(map: GameMap, flow: Flow, row: int) -> int:
	var pick := -1
	for x in map.cols:
		var at := row * map.cols + x
		if flow.best[at] < UNREACHED and (pick < 0 or flow.best[at] < flow.best[pick]):
			pick = at
	return pick


## The cells of a course from its start to `end`, in flowing order.
static func _course(map: GameMap, flow: Flow, end: int) -> Array[Vector2i]:
	var back: Array[Vector2i] = []
	var at := end
	while at >= 0:
		var x := at % map.cols
		back.append(Vector2i(x, (at - x) / map.cols))
		at = flow.parent[at]
	back.reverse()
	return back
