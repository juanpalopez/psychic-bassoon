## Terrain for the two end sections (#384): low terraces away from the road, forest at the strip's
## edges, and the socket blocks' own cells kept at their level.
class_name SectionGround
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
const END := preload("res://content/valley/end_rules.gd")


## Paints heights and regions of a result whose road and sockets are placed. Ground `terrace_gap`
## or more cells from the road is terrace 1 and grows forest from `forest_gap`; when `heart` is
## not empty, ground within `rise_reach` cells of it and `rise_gap` or more from the road is
## terrace 2 (and stays meadow). Walkable ground is left whole.
static func paint(
	result: SectionResult,
	terrace_gap: int,
	forest_gap: int,
	heart: Rect2i = Rect2i(),
	rise_gap: int = 0,
	rise_reach: int = 0
) -> void:
	var size: int = RULES.GAME_SOCKET_FOOTPRINT
	for y in range(result.rect.position.y, result.rect.end.y):
		for x in range(result.rect.position.x, result.rect.end.x):
			var cell := Vector2i(x, y)
			var gap := _road_gap(result.road, cell)
			var near_heart := heart.size != Vector2i.ZERO and _rect_gap(heart, cell) <= rise_reach
			var level := END.LOW_LEVEL if gap >= terrace_gap else END.FLOOR_LEVEL
			if near_heart and gap >= rise_gap:
				level = END.RISE_LEVEL
			result.set_height(cell, level)
			if gap >= forest_gap and not near_heart:
				result.set_region(cell, GameMap.Region.FOREST)
	for index in result.sockets.size():
		var block := Rect2i(result.sockets[index], Vector2i(size, size))
		for y in range(block.position.y - 1, block.end.y + 1):
			for x in range(block.position.x - 1, block.end.x + 1):
				var cell := Vector2i(x, y)
				if not result.has_cell(cell):
					continue
				if block.has_point(cell):
					result.set_height(cell, result.socket_levels[index])
					result.set_region(cell, GameMap.Region.MEADOW)
				else:
					result.set_height(cell, mini(result.height_at(cell), END.LOW_LEVEL))


## Chebyshev distance from a cell to the nearest road cell.
static func _road_gap(road: Array[Vector2i], cell: Vector2i) -> int:
	var best: int = END.NO_ROAD_GAP
	for step in road:
		best = mini(best, maxi(absi(step.x - cell.x), absi(step.y - cell.y)))
	return best


static func _rect_gap(rect: Rect2i, cell: Vector2i) -> int:
	var dx := maxi(maxi(rect.position.x - cell.x, cell.x - (rect.end.x - 1)), 0)
	var dy := maxi(maxi(rect.position.y - cell.y, cell.y - (rect.end.y - 1)), 0)
	return maxi(dx, dy)
