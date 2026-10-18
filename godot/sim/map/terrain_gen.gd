## The valley's terrain layer (#322): terrace heights, regions and a river with its bridges,
## built on a finished map (road and sockets placed) from its own stream, so it never moves the
## road or the sockets. Only boards with the valley shape get one; the classic boards stay flat
## (their heights are the socket levels) with no river.
##
## Heights come from a smooth value-noise field (random values on a coarse lattice, blended
## with a smoothstep, so only `+ - *` and `floor` are used) that rises away from the road (the
## valley), cut into terraces, then set where the game needs it: the road and the river on the
## floor, low banks beside the road, each socket block on its own level with the ground round it
## raised to one terrace below it. The river is the cheapest course down the board over the
## same field (it seeks low ground), crossing the road only on bridges it meets head on.
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


## A road cell a bridge can span and the step the river takes across it: down, or left or right.
class Span:
	extends RefCounted
	var cell := Vector2i.ZERO
	var step := Vector2i.ZERO


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
	var floors := _plinth_floors(map, gaps)
	_place_river(map, field, gaps, sockets)
	var heights := _carve_heights(map, field, gaps, sockets, floors)
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


## The least height of each cell beside a socket block (0 elsewhere): one terrace below the
## block, and no higher than `TERRAIN_ROADSIDE_MAX` on the road's banks, so a block on level 2
## rises from a slope instead of standing alone as a plinth. The road itself has none.
static func _plinth_floors(map: GameMap, gaps: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.cols * map.rows)
	for anchor in map.sockets:
		var least := map.elevation_at(anchor) - 1
		if least <= 0:
			continue
		for y in range(maxi(0, anchor.y - 1), mini(map.rows, anchor.y + map.footprint + 1)):
			for x in range(maxi(0, anchor.x - 1), mini(map.cols, anchor.x + map.footprint + 1)):
				var at := y * map.cols + x
				if gaps[at] == 0:
					continue
				var floor_here := least
				if gaps[at] <= 1:
					floor_here = mini(floor_here, RULES.TERRAIN_ROADSIDE_MAX)
				out[at] = maxi(out[at], floor_here)
	return out


## Terraces from the field (rising away from the road), then the game's rules on top: the road
## and the river on the floor, low banks beside the road, each socket block on its own level
## with the ground round it raised to its floor, and no lone pit or spike.
static func _carve_heights(
	map: GameMap,
	field: PackedFloat64Array,
	gaps: PackedInt32Array,
	sockets: PackedByteArray,
	floors: PackedByteArray
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
		level = maxi(level, floors[i])
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
	_smooth_lone_cells(map, heights, fixed, gaps, floors)
	return heights


## A cell with no side neighbour within one terrace is pulled to one terrace from its nearest
## neighbour (a bank cell no higher than `TERRAIN_ROADSIDE_MAX`, a cell beside a socket block
## no lower than its floor). Fixed cells (road, river, sockets) never move; the passes stop once
## nothing does.
static func _smooth_lone_cells(
	map: GameMap,
	heights: PackedByteArray,
	fixed: PackedByteArray,
	gaps: PackedInt32Array,
	floors: PackedByteArray
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
				level = maxi(level, floors[at])
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


## The cheapest course from the top edge to the bottom edge. It flows down a row at a time
## with side steps along a row, and crosses a road only on a bridge: a straight five-cell step
## (approach, entry, the road cell, outlet, departure) across a straight stretch one cell wide,
## so it meets the bridge head on. The cells beside an entry or an outlet (the bridge's
## diagonals) and the entries and outlets themselves are never walked otherwise, so the river
## never presses against the road at a bridge. A map may end up without a river when no course
## fits.
static func _place_river(
	map: GameMap, field: PackedFloat64Array, gaps: PackedInt32Array, sockets: PackedByteArray
) -> void:
	var keep_off := _river_keep_off(map, sockets)
	var walk := keep_off.duplicate()
	for i in walk.size():
		if gaps[i] == 0:
			walk[i] = 1
	var spans := _spans(map, keep_off, walk)
	var cost := PackedFloat64Array()
	for i in field.size():
		var step: float = RULES.RIVER_STEP_COST + field[i] * RULES.RIVER_HIGH_GROUND_COST
		if gaps[i] == 1:
			step += RULES.RIVER_ROADSIDE_COST
		cost.append(step)
	# the search alone may walk past a bridge it uses (onto its diagonals, or onto its entry or
	# outlet a second time), or wall in a raised socket block with river; the bridge or the
	# cells are taken out and the search runs again
	for pass_index in RULES.RIVER_SEARCH_PASSES:
		var usable: Array[Span] = []
		for span in spans:
			var approach := span.cell - span.step * 2
			var departure := span.cell + span.step * 2
			if walk[_index(map, approach)] == 0 and walk[_index(map, departure)] == 0:
				usable.append(span)
		var flow := _flow(map, walk, cost, usable)
		var mouth := _cheapest_on_row(map, flow, map.rows - 1)
		if mouth < 0:
			return
		var course := _course(map, flow, mouth)
		var crowding := _crowding(map, course, gaps)
		var moat := _plinth_moat(map, course, gaps)
		if crowding.is_empty() and moat.is_empty():
			map.river = course
			break
		# a crowded bridge is dropped (another may fit); a moat cell is kept off
		for cell in crowding:
			for k in range(spans.size() - 1, -1, -1):
				var gap := spans[k].cell - cell
				if absi(gap.x) <= 1 and absi(gap.y) <= 1:
					spans.remove_at(k)
		for cell in moat:
			walk[_index(map, cell)] = 1
	if map.river.is_empty():
		return
	var bridges: Array[GameMap.Bridge] = []
	for i in range(1, map.river.size() - 1):
		var cell := map.river[i]
		if gaps[cell.y * map.cols + cell.x] != 0:
			continue
		var bridge := GameMap.Bridge.new()
		bridge.cell = cell
		# the river steps down onto a bridge over a road that runs left to right
		bridge.horizontal = map.river[i - 1].x == cell.x
		bridge.path_index = map.path.find(cell)
		bridges.append(bridge)
	map.bridges = bridges


## The cells of a course that crowd one of its bridges: a cell beside the bridge's entry or
## outlet, or a cell the course passes twice (an entry or outlet walked again outside the span).
static func _crowding(
	map: GameMap, course: Array[Vector2i], gaps: PackedInt32Array
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var count := {}
	for cell in course:
		count[cell] = count.get(cell, 0) + 1
	for i in range(1, course.size() - 1):
		var cell := course[i]
		if gaps[_index(map, cell)] != 0:
			continue
		var flow_dir := course[i] - course[i - 1]
		var side := Vector2i(flow_dir.y, flow_dir.x)
		for k in [-1, 1]:
			for next: Vector2i in [cell + flow_dir * k + side, cell + flow_dir * k - side]:
				if count.has(next) and not out.has(next):
					out.append(next)
	for cell in course:
		if count[cell] > 1 and not out.has(cell):
			out.append(cell)
	return out


## The river cells of a course beside a socket block on level 2 or higher that would leave the
## block with nothing but road and river round it (a lone plinth over the valley floor).
static func _plinth_moat(
	map: GameMap, course: Array[Vector2i], gaps: PackedInt32Array
) -> Array[Vector2i]:
	var on_course := {}
	for cell in course:
		on_course[cell] = true
	var out: Array[Vector2i] = []
	for anchor in map.sockets:
		if map.elevation_at(anchor) < 2:
			continue
		var moat: Array[Vector2i] = []
		var held := false
		for k in map.footprint:
			for cell: Vector2i in [
				anchor + Vector2i(k, -1),
				anchor + Vector2i(k, map.footprint),
				anchor + Vector2i(-1, k),
				anchor + Vector2i(map.footprint, k),
			]:
				if not map.in_bounds(cell) or map.is_socket_cell(cell):
					continue
				if on_course.has(cell):
					moat.append(cell)
				elif gaps[_index(map, cell)] != 0:
					held = true
		if not held:
			out.append_array(moat)
	return out


## 1 on the cells the river must keep off: the sockets, the inside cell of every road turn
## (where the curved road bed widens), the Heartstone, the cells near a spawn and the columns
## within `RIVER_EDGE_MARGIN` of the left and right edges. With the game's numbers the
## Heartstone always lies inside the right-hand margin; it is kept off in its own right so a
## smaller margin cannot put the river on it.
static func _river_keep_off(map: GameMap, sockets: PackedByteArray) -> PackedByteArray:
	var out := sockets.duplicate()
	for route in map.routes:
		for i in range(1, route.size() - 1):
			var cell: Vector2i = route[i]
			var inside: Vector2i = route[i - 1] + route[i + 1] - cell
			if inside != cell and map.in_bounds(inside):
				out[inside.y * map.cols + inside.x] = 1
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


## The road cells a bridge can span, each as (x, y, and the step the river takes across it):
## the road runs straight through the cell and is one cell wide there, and the four cells in
## line with the step on either side (entry, outlet, approach and departure) are on the board
## and off the road and the keep-off cells. Across a road running left to right the river steps
## down; across a road running up or down it steps left or right (the search finds which way is
## downstream). Any route may be spanned, the second road (the feeder) too.
static func _spans(
	map: GameMap, keep_off: PackedByteArray, blocked: PackedByteArray
) -> Array[Span]:
	var out: Array[Span] = []
	var seen := {}
	for route in map.routes:
		for i in range(1, route.size() - 1):
			var cell: Vector2i = route[i]
			var along: Vector2i = route[i + 1] - cell
			if route[i - 1] != cell - along or keep_off[cell.y * map.cols + cell.x] == 1:
				continue
			var across := Vector2i(absi(along.y), absi(along.x))
			for flow_dir: Vector2i in [across, -across]:
				# a cell on two routes (the main road after the feeder joins) is listed once
				var key := _index(map, cell) * 3 + signi(flow_dir.x) + 1
				if flow_dir.y < 0 or seen.has(key):
					continue
				var free := true
				for k in [-2, -1, 1, 2]:
					var next: Vector2i = cell + flow_dir * k
					if not map.in_bounds(next) or blocked[next.y * map.cols + next.x] == 1:
						free = false
				if free:
					var span := Span.new()
					span.cell = cell
					span.step = flow_dir
					seen[key] = true
					out.append(span)
	return out


## The cheapest courses from every free cell of the top row down to every cell: down a row, a
## side step along a row, or a bridge span from its approach to its departure (down for a
## bridge on a road running left to right, along the row for one on a road running up or
## down). The side steps and the spans along a row are relaxed until the row settles.
static func _flow(
	map: GameMap, walk: PackedByteArray, cost: PackedFloat64Array, spans: Array[Span]
) -> Flow:
	var flow := Flow.new()
	flow.best.resize(map.cols * map.rows)
	flow.best.fill(UNREACHED)
	flow.parent.resize(map.cols * map.rows)
	flow.parent.fill(-1)
	var down_spans: Array[Span] = []
	var row_spans: Array[Span] = []
	for span in spans:
		if span.step.x == 0:
			down_spans.append(span)
		else:
			row_spans.append(span)
	for x in map.cols:
		if walk[x] == 0:
			flow.best[x] = cost[x]
	for y in map.rows:
		var row := y * map.cols
		if y > 0:
			for x in map.cols:
				var at := row + x
				if walk[at] == 0 and flow.best[at - map.cols] < UNREACHED:
					flow.best[at] = flow.best[at - map.cols] + cost[at]
					flow.parent[at] = at - map.cols
		for span in down_spans:
			if span.cell.y + 2 == y:
				_relax_span(map, flow, cost, span)
		var changed := true
		while changed:
			changed = false
			for x in range(1, map.cols):
				changed = _relax(flow, walk, cost, row + x, row + x - 1) or changed
			for x in range(map.cols - 2, -1, -1):
				changed = _relax(flow, walk, cost, row + x, row + x + 1) or changed
			for span in row_spans:
				if span.cell.y == y:
					changed = _relax_span(map, flow, cost, span) or changed
	return flow


## Reaches `at` from its side neighbour `from` when that is cheaper; true when it did.
static func _relax(
	flow: Flow, walk: PackedByteArray, cost: PackedFloat64Array, at: int, from: int
) -> bool:
	if walk[at] == 1 or flow.best[from] >= UNREACHED:
		return false
	if flow.best[from] + cost[at] < flow.best[at]:
		flow.best[at] = flow.best[from] + cost[at]
		flow.parent[at] = from
		return true
	return false


## Reaches a span's departure from its approach, over the bridge, when that is cheaper; true
## when it did. The span costs its four cells past the approach plus `RIVER_BRIDGE_COST`.
static func _relax_span(map: GameMap, flow: Flow, cost: PackedFloat64Array, span: Span) -> bool:
	var flow_dir := span.step
	var cell := span.cell
	var from := _index(map, cell - flow_dir * 2)
	if flow.best[from] >= UNREACHED:
		return false
	var total: float = flow.best[from] + RULES.RIVER_BRIDGE_COST
	for k in [-1, 0, 1, 2]:
		total += cost[_index(map, cell + flow_dir * k)]
	var at := _index(map, cell + flow_dir * 2)
	if total < flow.best[at]:
		flow.best[at] = total
		flow.parent[at] = from
		return true
	return false


static func _index(map: GameMap, cell: Vector2i) -> int:
	return cell.y * map.cols + cell.x


## The cheapest reached cell of `row` (the leftmost among equals), or -1 when none is reached.
static func _cheapest_on_row(map: GameMap, flow: Flow, row: int) -> int:
	var pick := -1
	for x in map.cols:
		var at := row * map.cols + x
		if flow.best[at] < UNREACHED and (pick < 0 or flow.best[at] < flow.best[pick]):
			pick = at
	return pick


## The cells of the course that ends at `end`, in flowing order, with the three cells a bridge
## span steps over filled in.
static func _course(map: GameMap, flow: Flow, end: int) -> Array[Vector2i]:
	var back: Array[Vector2i] = []
	var at := end
	while at >= 0:
		var x := at % map.cols
		var cell := Vector2i(x, (at - x) / map.cols)
		back.append(cell)
		var from := flow.parent[at]
		if from >= 0:
			var fx := from % map.cols
			var step := Vector2i(fx, (from - fx) / map.cols) - cell
			if absi(step.x) + absi(step.y) > 1:
				var unit := Vector2i(signi(step.x), signi(step.y))
				for k in range(1, absi(step.x) + absi(step.y)):
					back.append(cell + unit * k)
		at = from
	back.reverse()
	return back
