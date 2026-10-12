## Puts the sockets on a map and gives each an elevation level.
##
## It runs after the road generator and draws from its own stream
## (`Streams.SOCKETS`), so the road never changes. The steps, all deterministic:
## list the cells that are not road but within reach of it (reading order),
## shuffle them with the stream, take cells greedily while they keep their
## distance from the sockets already chosen until the target count is reached,
## sort the result in reading order, then give each socket a weighted
## elevation level.
class_name SocketPlacer
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## Fills `map.sockets` (the anchor, top-left cell, of each block) and
## `map.elevation` (one level for all the cells of a block) for the map's seed.
## Returns false, leaving the map without sockets, when the road leaves room for
## fewer than `SOCKET_MIN` of them: the generator then draws another road. That
## happens on a few roads of a 22 by 16 board with a detour and 2x2 blocks (seeds
## 2501 and 2996 among 6,000 consecutive ones), and on small boards.
static func place(map: GameMap) -> bool:
	var rng := Rng.derive(map.seed, Streams.SOCKETS)
	var candidates := _candidates(map)
	_shuffle(candidates, rng)
	var target: int = RULES.SOCKET_MIN + rng.next_int(RULES.SOCKET_MAX - RULES.SOCKET_MIN + 1)
	var chosen: Array[Vector2i] = []
	for cell in candidates:
		if chosen.size() >= target:
			break
		if _keeps_distance(cell, chosen, map.footprint):
			chosen.append(cell)
	if chosen.size() < RULES.SOCKET_MIN:
		return false
	chosen.sort_custom(_reading_order)
	map.sockets = chosen
	map.elevation = _flat_elevation(map.cols, map.rows)
	var total := 0
	for weight in RULES.ELEVATION_WEIGHTS:
		total += weight
	for anchor in chosen:
		var level := _weighted_level(rng.next_int(total))
		for dy in map.footprint:
			for dx in map.footprint:
				map.elevation[anchor.y + dy][anchor.x + dx] = level
	return true


## Anchors whose whole block is on the board, off the road and off the
## Heartstone's footprint, with a cell of the block within `SOCKET_REACH` of the
## road, in reading order.
static func _candidates(map: GameMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for row in range(0, map.rows - map.footprint + 1):
		for col in range(0, map.cols - map.footprint + 1):
			if _block_is_free(map, col, row) and _block_near_road(map, col, row):
				out.append(Vector2i(col, row))
	return out


static func _block_is_free(map: GameMap, col: int, row: int) -> bool:
	for dy in map.footprint:
		for dx in map.footprint:
			if map.tiles[row + dy][col + dx] == GameMap.Tile.ROAD:
				return false
			if map.heartstone.has_point(Vector2i(col + dx, row + dy)):
				return false
	return true


static func _block_near_road(map: GameMap, col: int, row: int) -> bool:
	for dy in map.footprint:
		for dx in map.footprint:
			if _road_within_reach(map, col + dx, row + dy):
				return true
	return false


static func _road_within_reach(map: GameMap, col: int, row: int) -> bool:
	for dy in range(-RULES.SOCKET_REACH, RULES.SOCKET_REACH + 1):
		for dx in range(-RULES.SOCKET_REACH, RULES.SOCKET_REACH + 1):
			var x := col + dx
			var y := row + dy
			if x < 0 or x >= map.cols or y < 0 or y >= map.rows:
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


## A single cell keeps `SOCKET_SPACING` (Manhattan) from the others; a block's
## anchor keeps its own size plus `SOCKET_BLOCK_GAP` (Chebyshev), so blocks never
## touch.
static func _keeps_distance(cell: Vector2i, chosen: Array[Vector2i], footprint: int) -> bool:
	for other in chosen:
		var dx := absi(cell.x - other.x)
		var dy := absi(cell.y - other.y)
		if footprint == 1:
			if dx + dy < RULES.SOCKET_SPACING:
				return false
		elif maxi(dx, dy) < footprint + RULES.SOCKET_BLOCK_GAP:
			return false
	return true


static func _reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or (a.y == b.y and a.x < b.x)


static func _flat_elevation(cols: int, rows: int) -> Array[PackedByteArray]:
	var lines: Array[PackedByteArray] = []
	for row in rows:
		var line := PackedByteArray()
		line.resize(cols)
		line.fill(0)
		lines.append(line)
	return lines


## The level whose share of the weights holds `roll` (0 up to the total weight).
static func _weighted_level(roll: int) -> int:
	var left := roll
	for level in RULES.ELEVATION_WEIGHTS.size():
		left -= RULES.ELEVATION_WEIGHTS[level]
		if left < 0:
			return level
	return RULES.ELEVATION_WEIGHTS.size() - 1
