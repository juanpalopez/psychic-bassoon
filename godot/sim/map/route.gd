## The line foes walk: a spawn point, then every path cell centre.
##
## Positions are kept in `PackedFloat64Array`s, not `Vector2`, because Vector2
## is 32-bit in GDScript and the distances must match the 64-bit TypeScript
## results. Only `+ - *` and `sqrt` are used, which are exactly rounded.
class_name Route
extends RefCounted

const RULES := preload("res://content/map_rules.gd")

var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
## Distance from the spawn point to each point.
var cumulative := PackedFloat64Array()
var total: float = 0.0


## Builds the route for a path. Returns null for an empty path.
static func build(cells: Array[Vector2i]) -> Route:
	if cells.is_empty():
		push_error("a route needs at least one cell")
		return null
	var route := Route.new()
	# the spawn point sits off the board edge the road enters from: above the top
	# row for a road that starts by going down, left of the first column for one
	# that starts by going right, below the bottom row for one that starts by going up
	# (the second road may enter from the bottom edge)
	var goes_right := cells.size() > 1 and cells[1].x > cells[0].x
	var goes_up := cells.size() > 1 and cells[1].y < cells[0].y
	if goes_right:
		route.xs.append(-RULES.SPAWN_OFFSET)
		route.ys.append(float(cells[0].y) + RULES.CELL_CENTRE)
	elif goes_up:
		route.xs.append(float(cells[0].x) + RULES.CELL_CENTRE)
		route.ys.append(float(cells[0].y) + 1.0 + RULES.SPAWN_OFFSET)
	else:
		route.xs.append(float(cells[0].x) + RULES.CELL_CENTRE)
		route.ys.append(-RULES.SPAWN_OFFSET)
	for cell in cells:
		route.xs.append(float(cell.x) + RULES.CELL_CENTRE)
		route.ys.append(float(cell.y) + RULES.CELL_CENTRE)
	route.cumulative.append(0.0)
	for i in range(1, route.xs.size()):
		var dx := route.xs[i] - route.xs[i - 1]
		var dy := route.ys[i] - route.ys[i - 1]
		route.cumulative.append(route.cumulative[i - 1] + sqrt(dx * dx + dy * dy))
	route.total = route.cumulative[route.cumulative.size() - 1]
	return route


## A straight line from one point to another (the flight of a flying foe).
static func straight(from_x: float, from_y: float, to_x: float, to_y: float) -> Route:
	var route := Route.new()
	route.xs.append(from_x)
	route.ys.append(from_y)
	route.xs.append(to_x)
	route.ys.append(to_y)
	var dx := to_x - from_x
	var dy := to_y - from_y
	route.cumulative.append(0.0)
	route.cumulative.append(sqrt(dx * dx + dy * dy))
	route.total = route.cumulative[1]
	return route


## Position `along` cells from the spawn point, clamped to the route.
func position_at(along: float) -> RoutePoint:
	var i := 0
	while i < cumulative.size() - 2 and cumulative[i + 1] < along:
		i += 1
	var start := cumulative[i]
	var length := cumulative[i + 1] - start
	var fraction := 0.0
	if length > 0.0:
		fraction = minf(1.0, maxf(0.0, (along - start) / length))
	var point := RoutePoint.new()
	point.x = xs[i] + (xs[i + 1] - xs[i]) * fraction
	point.y = ys[i] + (ys[i + 1] - ys[i]) * fraction
	return point
