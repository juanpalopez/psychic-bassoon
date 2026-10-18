## The line foes walk: a spawn point, then the road's cells. `build` puts a point on every
## path cell centre (the ported route the frozen fixtures pin); `build_curved` rounds the
## path's corners (#321), and that curve is what foes on the valley board walk, so their
## movement, distance, range and hits all follow it.
##
## Positions are kept in `PackedFloat64Array`s, not `Vector2`, because Vector2
## is 32-bit in GDScript and the distances must match the 64-bit TypeScript
## results. Only `+ - * /` and `sqrt` are used, which are exactly rounded.
class_name Route
extends RefCounted

const RULES := preload("res://content/map_rules.gd")
## How many cells past the join the curve of a second route can still differ from the main
## road's: a cell's curve points depend on its neighbours and on whether their neighbours are
## corners, so from the second cell after the join on both routes are the same curve.
const JOIN_SETTLE_CELLS := 2

var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
## Distance from the spawn point to each point.
var cumulative := PackedFloat64Array()
var total: float = 0.0
## For each cell of the path, the index of the point that stands for it: the cell's centre,
## or the middle of the curve that rounds it when it is a corner.
var cell_points := PackedInt32Array()
## Whether the corners are rounded (`build_curved`).
var curved: bool = false


## Builds the route for a path. Returns null for an empty path.
static func build(cells: Array[Vector2i]) -> Route:
	if cells.is_empty():
		push_error("a route needs at least one cell")
		return null
	var route := Route.new()
	_add_spawn(route, cells)
	for cell in cells:
		route.cell_points.append(route.xs.size())
		route.xs.append(float(cell.x) + RULES.CELL_CENTRE)
		route.ys.append(float(cell.y) + RULES.CELL_CENTRE)
	_measure(route)
	return route


## Builds the route for a path with its corners rounded: each corner cell's centre is replaced
## by a quadratic Bezier with that centre as its control point, from `CURVE_LEG` cells before it
## to `CURVE_LEG` cells after it (the centres of the cells either side), or `CURVE_LEG_TIGHT`
## cells (the corner cell's edges) when a neighbouring cell is a corner too. Either way the
## curve stays in the corner cell and its two neighbours, meets the straight road with the
## road's own heading, and meets the next corner's curve instead of crossing it. Straight cells
## keep their centres. Returns null for an empty path.
static func build_curved(cells: Array[Vector2i]) -> Route:
	if cells.is_empty():
		push_error("a route needs at least one cell")
		return null
	var route := Route.new()
	route.curved = true
	_add_spawn(route, cells)
	var count := cells.size()
	var corner := PackedByteArray()
	corner.resize(count)
	corner.fill(0)
	for k in range(1, count - 1):
		if cells[k + 1] - cells[k] != cells[k] - cells[k - 1]:
			corner[k] = 1
	for k in count:
		var cx := float(cells[k].x) + RULES.CELL_CENTRE
		var cy := float(cells[k].y) + RULES.CELL_CENTRE
		if corner[k] == 0:
			route.cell_points.append(route.xs.size())
			route.xs.append(cx)
			route.ys.append(cy)
			continue
		var tight := corner[k - 1] == 1 or corner[k + 1] == 1
		var leg := RULES.CURVE_LEG_TIGHT if tight else RULES.CURVE_LEG
		var come := cells[k] - cells[k - 1]
		var go := cells[k + 1] - cells[k]
		var ax := cx - leg * float(come.x)
		var ay := cy - leg * float(come.y)
		var bx := cx + leg * float(go.x)
		var by := cy + leg * float(go.y)
		var half := maxi(1, int(floor(leg / RULES.CURVE_POINT_SPACING + 0.5)))
		var segments := 2 * half
		# a full leg starts and ends on the centres of the straight cells either side, which
		# add their own points; a tight leg starts on the edge the previous corner's curve
		# already ended on, or adds that edge point after a straight cell, and adds its end
		var first := 0 if tight and corner[k - 1] == 0 else 1
		var last := segments if tight else segments - 1
		for j in range(first, last + 1):
			if j == half:
				route.cell_points.append(route.xs.size())
			var t := float(j) / float(segments)
			var u := 1.0 - t
			route.xs.append(u * u * ax + 2.0 * u * t * cx + t * t * bx)
			route.ys.append(u * u * ay + 2.0 * u * t * cy + t * t * by)
	_measure(route)
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


## With a second spawn source: how much further along `second` (the feeder, then the main road
## from the join cell on) a point of the main road is than along `main`. It is measured at a
## cell where both routes are already the same line: the join cell itself on grid routes, and
## `JOIN_SETTLE_CELLS` cells after it on curved ones, whose curves near the join differ.
static func join_offset(main: Route, second: Route, feeder_length: int, join_index: int) -> float:
	var settle := JOIN_SETTLE_CELLS if second.curved else 0
	return second.cell_distance(feeder_length + settle) - main.cell_distance(join_index + settle)


## Distance from the spawn point to the point that stands for the path's `cell`-th cell.
func cell_distance(cell: int) -> float:
	return cumulative[cell_points[cell]]


## Position `along` cells from the spawn point, clamped to the route.
func position_at(along: float) -> RoutePoint:
	# the first segment whose end is at least `along` away (the first of equal ones), found
	# by bisection: curved routes have many points and every foe asks every tick
	var end := maxi(1, cumulative.bsearch(along, true))
	var i := mini(end, cumulative.size() - 1) - 1
	var start := cumulative[i]
	var length := cumulative[i + 1] - start
	var fraction := 0.0
	if length > 0.0:
		fraction = minf(1.0, maxf(0.0, (along - start) / length))
	var point := RoutePoint.new()
	point.x = xs[i] + (xs[i + 1] - xs[i]) * fraction
	point.y = ys[i] + (ys[i + 1] - ys[i]) * fraction
	return point


## The spawn point sits off the board edge the road enters from: above the top row for a road
## that starts by going down, left of the first column for one that starts by going right,
## below the bottom row for one that starts by going up (the second road may enter from the
## bottom edge).
static func _add_spawn(route: Route, cells: Array[Vector2i]) -> void:
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


## Fills in the distance to every point and the total.
static func _measure(route: Route) -> void:
	route.cumulative.append(0.0)
	for i in range(1, route.xs.size()):
		var dx := route.xs[i] - route.xs[i - 1]
		var dy := route.ys[i] - route.ys[i - 1]
		route.cumulative.append(route.cumulative[i - 1] + sqrt(dx * dx + dy * dy))
	route.total = route.cumulative[route.cumulative.size() - 1]
