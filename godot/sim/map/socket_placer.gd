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
## happened on about 0.1% of the roads of the old game board (22 by 16, one road, 2x2
## blocks: 2 of 3,000 seeds; not measured on 16 by 11), on about 0.4% with a detour
## (11 of 3,000), and often on small boards (20 by 14: 3% to 7%).
## `least` and `most` bound the count for 2x2 blocks (the valley asks for more, #320).
static func place(
	map: GameMap, least: int = RULES.SOCKET_MIN, most_blocks: int = RULES.SOCKET_MAX
) -> bool:
	var rng := Rng.derive(map.seed, Streams.SOCKETS)
	var candidates := _candidates(map)
	_shuffle(candidates, rng)
	var most: int = RULES.SOCKET_MAX_SINGLE_CELL if map.footprint == 1 else most_blocks
	var target: int = least + rng.next_int(most - least + 1)
	var chosen: Array[Vector2i] = []
	for cell in candidates:
		if chosen.size() >= target:
			break
		if _keeps_distance(cell, chosen, map.footprint):
			chosen.append(cell)
	if chosen.size() < least:
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
## Heartstone's footprint, touching the road and with a stretch of it in reach
## of the block's centre (a single cell: within `SOCKET_REACH` of the road), in
## reading order.
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
	if map.footprint > 1:
		return _block_centre_near_road(map, col, row)
	for dy in map.footprint:
		for dx in map.footprint:
			if _road_within_reach(map, col + dx, row + dy):
				return true
	return false


## True when the block anchored at (col, row) touches the road and has a stretch
## of it to shoot at: a road cell's centre within `SOCKET_BLOCK_TOUCH_DISTANCE` of
## the block's centre, and at least `SOCKET_MIN_ROAD_COVERAGE` road cells within
## `SOCKET_COVERAGE_REACH` of it.
static func _block_centre_near_road(map: GameMap, col: int, row: int) -> bool:
	var centre := map.socket_centre(Vector2i(col, row))
	var reach: float = RULES.SOCKET_COVERAGE_REACH
	var touch: float = RULES.SOCKET_BLOCK_TOUCH_DISTANCE
	var span := int(ceil(reach)) + map.footprint
	var covered := 0
	var touching := false
	for y in range(maxi(0, row - span), mini(map.rows, row + map.footprint + span)):
		for x in range(maxi(0, col - span), mini(map.cols, col + map.footprint + span)):
			if map.tiles[y][x] != GameMap.Tile.ROAD:
				continue
			var dx := float(x) + RULES.CELL_CENTRE - centre.x
			var dy := float(y) + RULES.CELL_CENTRE - centre.y
			var squared := dx * dx + dy * dy
			if squared <= reach * reach:
				covered += 1
			if squared <= touch * touch:
				touching = true
	return touching and covered >= RULES.SOCKET_MIN_ROAD_COVERAGE


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
