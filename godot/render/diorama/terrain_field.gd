## The diorama's ground, as data: one terrace level per cell over the map and a wide margin of
## render-only country round it (#324).
##
## Over the map each cell takes the sim's terrace (`GameMap.height_at`), the river's cells are
## carved into a gorge below the valley floor, and the Heartstone's block is levelled with the
## end of the road. Past the map the country is made up for the look only: hills from a hash of
## the map seed (never a game stream) that rise away from the map, the valley floor carried on
## along each road that leaves an edge, and the river's gorge carried on to the far edges and
## widening. Nothing here changes the game; the terrace and water builders mesh it and the views
## read `surface_height`, so a tower, a foe and a tap all agree with the ground that is drawn.
##
## Cells are in map coordinates (the map's own cells are 0 to cols - 1 and 0 to rows - 1;
## `MARGIN` more lie on every side). One terrace is `TERRACE_STEP` metres.
class_name TerrainField
extends RefCounted

## Metres from one terrace to the next, for every view (the socket rises included). Three
## quarters of a metre shows the kraft cliffs from the 56 to 62 degree camera (half a metre read
## as thin lines), and a bank beside the road (one terrace) hides less than half a cell of it.
const TERRACE_STEP := 0.75
## Cells of country past each edge of the map (the overview sees about 27 past it).
const MARGIN := 34
## The level of a gorge cell (the river), below the valley floor (level 0).
const GORGE := -1
## The floor of the gorge and the water in it, in metres.
const GORGE_FLOOR := -1.6
const WATER_HEIGHT := -1.05
## Where foes walk: the top of the road, a hair above the valley floor.
const ROAD_HEIGHT := 0.01
## The highest hill past the map, in terraces.
const HILL_MAX_LEVEL := 9
## The hills: a base and two octaves of value noise (cells between lattice points), rising by
## `HILL_RISE` terraces a cell away from the map, blended in from the map's own edge over
## `HILL_BLEND` cells. Toward the camera (the near and right sides) they are lower, so the
## valley opens toward the viewer.
const HILL_BASE := 1.0
const HILL_NOISE := 6.0
const HILL_DETAIL := 0.8
const HILL_SPACING := 15.0
const HILL_DETAIL_SPACING := 6.0
const HILL_RISE := 0.16
const HILL_BLEND := 6.0
const HILL_FRONT_DAMP := 0.6
## Past the blend the hills step `HILL_TERRACES` levels at a time: fewer, taller cliffs, like the
## look-dev's plateaus, and fewer triangles.
const HILL_TERRACES := 3
## The ground direction from the map toward the camera (it sits to +x and +z, `CameraRig`).
const TOWARD_CAMERA := Vector2(0.5, 0.866)
## Past the map the gorge widens: one cell either side from this far out, two from the next.
const GORGE_WIDE_FROM := 3
const GORGE_WIDER_FROM := 14
## A road leaving the map keeps the floor this many cells either side, and a low bank beyond.
const LEAD_FLOOR := 1
const LEAD_BANK := 2
## How a cell's outline is kept: sockets, then the Heartstone, then the road keep their square
## outline (no wobble, no chamfered corner) against anything with a lower guard.
const GUARD_NONE := 0
const GUARD_ROAD := 1
const GUARD_HEARTSTONE := 2
const GUARD_SOCKET := 3
## Salts of the render-only hashes (any number not used elsewhere for this purpose).
const SALT_HILLS := 701
const SALT_DETAIL := 702
const SALT_RIVER := 703

var map: GameMap
## The lines foes walk, one per map route (the game's own, or made from the map's cells): the
## road beds follow them.
var routes: Array[Route] = []
## The seed the hashes use (the map's).
var seed: int = 0
## The map cell of the field's first cell, and the field's size in cells.
var origin := Vector2i(-MARGIN, -MARGIN)
var size := Vector2i.ZERO
## One level per field cell, row by row (`GORGE` for the river).
var levels := PackedInt32Array()
## One `GUARD_*` per field cell.
var guards := PackedByteArray()
## The river's cells from the far edge of the field to the near one (map coordinates): the
## map's river, carried on past both edges. Empty when the map has none.
var river: Array[Vector2i] = []
## For each road that leaves the map at an edge: the cells it carries on through past the map,
## outward from the edge cell (map coordinates). Each item is an `Array[Vector2i]`.
var leads: Array = []
## The world direction each lead runs in (x across, y in depth), one per lead.
var lead_directions: Array[Vector2i] = []


## The field for a map: the sim's terraces on the map, made-up country round it. `walked` are
## the game's routes; when empty they are made from the map's route cells.
static func from_map(source: GameMap, walked: Array[Route] = []) -> TerrainField:
	var field := TerrainField.new()
	field.map = source
	# as the game builds them when it gives none (`Route.for_map`)
	field.routes = walked if not walked.is_empty() else Route.for_map(source)
	field.seed = source.seed
	field.size = Vector2i(source.cols + 2 * MARGIN, source.rows + 2 * MARGIN)
	field.levels.resize(field.size.x * field.size.y)
	field.guards.resize(field.size.x * field.size.y)
	field._lay_map()
	field._lay_hills()
	field._lay_leads()
	field._lay_river()
	return field


## The world height of a terrace level's top.
static func level_height(level: int) -> float:
	if level < 0:
		return GORGE_FLOOR
	return float(level) * TERRACE_STEP


## Whether a cell (map coordinates) is in the field.
func has_cell(cell: Vector2i) -> bool:
	var at := cell - origin
	return at.x >= 0 and at.y >= 0 and at.x < size.x and at.y < size.y


## The index of a cell in `levels` and `guards`, clamped into the field.
func index_of(cell: Vector2i) -> int:
	var at := (cell - origin).clamp(Vector2i.ZERO, size - Vector2i.ONE)
	return at.y * size.x + at.x


## The terrace level of a cell (the nearest field cell's when it is past the field).
func level_at(cell: Vector2i) -> int:
	return levels[index_of(cell)]


## The guard of a cell (`GUARD_*`).
func guard_at(cell: Vector2i) -> int:
	return guards[index_of(cell)]


## Whether the cell is in the gorge (under water).
func is_gorge(cell: Vector2i) -> bool:
	return level_at(cell) == GORGE


## The top of the terrain drawn at the middle of a cell: its terrace, or the gorge floor.
func top_at(cell: Vector2i) -> float:
	return level_height(level_at(cell))


## What stands on a cell stands this high: the road's top on a road cell (the bridges too),
## the water on a river cell, and the terrace top anywhere else (a socket block's included).
## Towers, foes, guards, the highlight and the tap picking all read it.
func surface_height(cell: Vector2i) -> float:
	if map.in_bounds(cell) and map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD:
		return ROAD_HEIGHT
	if is_gorge(cell):
		return WATER_HEIGHT
	return top_at(cell)


## The cell under a world point (x and z), in map coordinates, on or off the map.
func cell_under(world: Vector3) -> Vector2i:
	return Vector2i(
		floori(world.x + float(map.cols) / 2.0), floori(world.z + float(map.rows) / 2.0)
	)


## The world centre of any cell, on or off the map (`BoardSpace.cell_to_world` on the map).
func cell_centre(cell: Vector2i) -> Vector3:
	return Vector3(
		float(cell.x) - float(map.cols - 1) / 2.0, 0.0, float(cell.y) - float(map.rows - 1) / 2.0
	)


## The ground the field covers, in world x and z (its outer cells' outer edges).
func world_rect() -> Rect2:
	var low := cell_centre(origin) - Vector3(0.5, 0.0, 0.5)
	return Rect2(Vector2(low.x, low.z), Vector2(size))


## The highest terrace on the field, in metres.
func highest() -> float:
	var top := GORGE
	for level in levels:
		top = maxi(top, level)
	return level_height(top)


## Smooth value noise in [0, 1) over the cells, from a hash of the seed (render only).
func noise(x: float, y: float, spacing: float, salt: int) -> float:
	var gx := x / spacing
	var gy := y / spacing
	var ix := floori(gx)
	var iy := floori(gy)
	var fx := gx - float(ix)
	var fy := gy - float(iy)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := CellHash.of(ix, iy, seed, salt)
	var b := CellHash.of(ix + 1, iy, seed, salt)
	var c := CellHash.of(ix, iy + 1, seed, salt)
	var d := CellHash.of(ix + 1, iy + 1, seed, salt)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func _put(cell: Vector2i, level: int, guard: int = -1) -> void:
	if not has_cell(cell):
		return
	var at := index_of(cell)
	levels[at] = level
	if guard >= 0:
		guards[at] = guard


func _lay_map() -> void:
	for row in map.rows:
		for col in map.cols:
			var cell := Vector2i(col, row)
			var guard := GUARD_NONE
			if map.tiles[row][col] == GameMap.Tile.ROAD:
				guard = GUARD_ROAD
			if map.heartstone.has_point(cell):
				guard = GUARD_HEARTSTONE
			if map.is_socket_cell(cell):
				guard = GUARD_SOCKET
			var level := map.height_at(cell)
			if guard == GUARD_ROAD:
				# the wide band's outer cells (#430) lie on the valley floor like the centre line
				level = 0
			if guard == GUARD_HEARTSTONE:
				# the Heartstone stands level with the end of the road
				level = map.height_at(map.path[map.path.size() - 1])
			_put(cell, level, guard)
	for cell in map.river:
		_put(cell, GORGE)


## The hills past the map: the map's edge carried out and blended into rising value noise.
func _lay_hills() -> void:
	var last := Vector2i(map.cols - 1, map.rows - 1)
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if map.in_bounds(cell):
				continue
			var edge := cell.clamp(Vector2i.ZERO, last)
			var out := cell - edge
			var away := maxi(absi(out.x), absi(out.y))
			var base := maxi(map.height_at(edge), 0)
			var front := clampf(Vector2(out).normalized().dot(TOWARD_CAMERA), 0.0, 1.0)
			var hill := (
				HILL_BASE
				+ HILL_NOISE * noise(float(cell.x), float(cell.y), HILL_SPACING, SALT_HILLS)
				+ (
					HILL_DETAIL
					* noise(float(cell.x), float(cell.y), HILL_DETAIL_SPACING, SALT_DETAIL)
				)
				+ HILL_RISE * float(away)
			)
			hill *= 1.0 - HILL_FRONT_DAMP * front
			var blend := smoothstep(0.0, HILL_BLEND, float(away))
			var raw := lerpf(float(base), hill, blend)
			var level := int(floor(raw + 0.5))
			if float(away) >= HILL_BLEND:
				level = HILL_TERRACES * int(floor(raw / float(HILL_TERRACES) + 0.5))
			_put(cell, clampi(level, 0, HILL_MAX_LEVEL))


## The valley floor carried on along each road that starts at an edge of the map.
func _lay_leads() -> void:
	leads.clear()
	lead_directions.clear()
	var starts := {}
	for route in map.routes:
		var start: Vector2i = route[0]
		if starts.has(start):
			continue
		starts[start] = true
		var out := _outward(start, route[1] - start)
		if out == Vector2i.ZERO:
			continue
		var cells: Array[Vector2i] = []
		for step in range(1, MARGIN + 1):
			cells.append(start + out * step)
		leads.append(cells)
		lead_directions.append(out)
		var side := Vector2i(out.y, out.x)
		for cell in cells:
			for k in range(-LEAD_BANK, LEAD_BANK + 1):
				var bank := cell + side * k
				if not has_cell(bank) or map.in_bounds(bank):
					continue
				if absi(k) <= LEAD_FLOOR:
					_put(bank, 0, GUARD_ROAD if k == 0 else GUARD_NONE)
				else:
					_put(bank, mini(level_at(bank), 1))


## The way out of the map from an edge cell, away from the road's next cell; zero when the
## cell is not on an edge.
func _outward(start: Vector2i, inward: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	if start.x == 0:
		candidates.append(Vector2i.LEFT)
	if start.x == map.cols - 1:
		candidates.append(Vector2i.RIGHT)
	if start.y == 0:
		candidates.append(Vector2i.UP)
	if start.y == map.rows - 1:
		candidates.append(Vector2i.DOWN)
	for out in candidates:
		if out == -inward:
			return out
	return candidates[0] if candidates.size() > 0 else Vector2i.ZERO


## The river's gorge carried on past the top and bottom edges, meandering and widening.
func _lay_river() -> void:
	river.clear()
	if map.river.is_empty():
		return
	var above := _river_lead(map.river[0], -1)
	above.reverse()
	river.append_array(above)
	river.append_array(map.river)
	river.append_array(_river_lead(map.river[map.river.size() - 1], 1))
	for cell in river:
		if map.in_bounds(cell):
			continue
		var away := maxi(-cell.y, cell.y - (map.rows - 1))
		var half := 0
		if away >= GORGE_WIDER_FROM:
			half = 2
		elif away >= GORGE_WIDE_FROM:
			half = 1
		for k in range(-half, half + 1):
			var at := cell + Vector2i(k, 0)
			# a road carried past the map keeps its floor (no road crosses out there)
			if has_cell(at) and not map.in_bounds(at) and guard_at(at) == GUARD_NONE:
				_put(at, GORGE)


## The river's cells from `from` (an edge cell) out to the field's edge, `dy` a row a step,
## stepping aside now and then.
func _river_lead(from: Vector2i, dy: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var at := from
	for step in MARGIN:
		at += Vector2i(0, dy)
		cells.append(at)
		var pick := CellHash.of(at.x, at.y, seed, SALT_RIVER)
		if step > 2 and pick < 0.3:
			var aside := Vector2i(-1 if pick < 0.15 else 1, 0)
			var next := at + aside
			if next.x > origin.x + 2 and next.x < origin.x + size.x - 3:
				at = next
				cells.append(at)
	return cells
