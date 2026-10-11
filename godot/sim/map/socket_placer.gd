## Puts the sockets on a map and gives each an elevation level.
##
## It runs after the road generator and draws from its own stream
## (`Streams.SOCKETS`), so the road never changes. The steps, all deterministic:
## list the cells that are not road but within reach of it (reading order),
## shuffle them with the stream, take cells greedily while they keep their
## distance from the sockets already chosen until the target count is reached,
## top up without the distance rule if that fell short of the minimum, sort the
## result in reading order, then give each socket a weighted elevation level.
class_name SocketPlacer
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## Fills `map.sockets` and `map.elevation` for the map's seed.
static func place(map: GameMap) -> void:
	var rng := Rng.derive(map.seed, Streams.SOCKETS)
	var candidates := _candidates(map)
	_shuffle(candidates, rng)
	var target: int = RULES.SOCKET_MIN + rng.next_int(RULES.SOCKET_MAX - RULES.SOCKET_MIN + 1)
	var chosen: Array[Vector2i] = []
	for cell in candidates:
		if chosen.size() >= target:
			break
		if _keeps_distance(cell, chosen):
			chosen.append(cell)
	for cell in candidates:
		if chosen.size() >= RULES.SOCKET_MIN:
			break
		if not chosen.has(cell):
			chosen.append(cell)
	chosen.sort_custom(_reading_order)
	map.sockets = chosen
	map.elevation = _flat_elevation()
	var total := 0
	for weight in RULES.ELEVATION_WEIGHTS:
		total += weight
	for cell in chosen:
		map.elevation[cell.y][cell.x] = _weighted_level(rng.next_int(total))


## Cells that are not road but have a road cell within `SOCKET_REACH`.
static func _candidates(map: GameMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in RULES.GRID_ROWS:
		for col in RULES.GRID_COLS:
			if map.tiles[row][col] == GameMap.Tile.ROAD:
				continue
			if _road_within_reach(map, col, row):
				out.append(Vector2i(col, row))
	return out


static func _road_within_reach(map: GameMap, col: int, row: int) -> bool:
	for dy in range(-RULES.SOCKET_REACH, RULES.SOCKET_REACH + 1):
		for dx in range(-RULES.SOCKET_REACH, RULES.SOCKET_REACH + 1):
			var x := col + dx
			var y := row + dy
			if x < 0 or x >= RULES.GRID_COLS or y < 0 or y >= RULES.GRID_ROWS:
				continue
			if map.tiles[y][x] == GameMap.Tile.ROAD:
				return true
	return false


## Fisher-Yates with the stream, from the end of the list down.
static func _shuffle(cells: Array[Vector2i], rng: Rng) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.next_int(i + 1)
		var held := cells[i]
		cells[i] = cells[j]
		cells[j] = held


static func _keeps_distance(cell: Vector2i, chosen: Array[Vector2i]) -> bool:
	for other in chosen:
		if absi(cell.x - other.x) + absi(cell.y - other.y) < RULES.SOCKET_SPACING:
			return false
	return true


static func _reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _flat_elevation() -> Array[PackedByteArray]:
	var rows: Array[PackedByteArray] = []
	for row in RULES.GRID_ROWS:
		var line := PackedByteArray()
		line.resize(RULES.GRID_COLS)
		line.fill(0)
		rows.append(line)
	return rows


## The level whose share of the weights holds `roll` (0 up to the total weight).
static func _weighted_level(roll: int) -> int:
	var left := roll
	for level in RULES.ELEVATION_WEIGHTS.size():
		left -= RULES.ELEVATION_WEIGHTS[level]
		if left < 0:
			return level
	return RULES.ELEVATION_WEIGHTS.size() - 1
