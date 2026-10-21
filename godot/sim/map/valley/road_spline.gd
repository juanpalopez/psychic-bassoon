## Builds a smooth road through waypoints (#404): a Catmull-Rom spline (it passes through every
## waypoint and turns smoothly at each) sampled finely enough to rasterise into road cells that
## step one cell at a time. Only `+ - * /`, `floor` and `sqrt` are used, so the curve is the same
## on every machine. Waypoints are in cell units: (x + 0.5, y + 0.5) is the middle of cell (x, y).
class_name RoadSpline
extends RefCounted

const RULES := preload("res://content/valley/road_rules.gd")


## The road through `waypoints` (at least two).
static func build(waypoints: Array[Vector2]) -> RoadCurve:
	var curve := RoadCurve.new()
	var count := waypoints.size()
	assert(count >= 2, "a road needs at least two waypoints")
	for index in count - 1:
		var p0 := waypoints[maxi(index - 1, 0)]
		var p1 := waypoints[index]
		var p2 := waypoints[index + 1]
		var p3 := waypoints[mini(index + 2, count - 1)]
		var dx := float(p2.x) - float(p1.x)
		var dy := float(p2.y) - float(p1.y)
		var steps := int(floor(sqrt(dx * dx + dy * dy) * RULES.SAMPLES_PER_CELL)) + 1
		for step in steps:
			var t := float(step) / float(steps)
			curve.xs.append(_blend(p0.x, p1.x, p2.x, p3.x, t))
			curve.ys.append(_blend(p0.y, p1.y, p2.y, p3.y, t))
	curve.xs.append(float(waypoints[count - 1].x))
	curve.ys.append(float(waypoints[count - 1].y))
	_rasterise(curve)
	return curve


## One coordinate of the Catmull-Rom curve between `b` and `c` at `t` in [0, 1).
static func _blend(a: float, b: float, c: float, d: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return (
		0.5
		* (
			2.0 * b
			+ (c - a) * t
			+ (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
			+ (3.0 * b - a - 3.0 * c + d) * t3
		)
	)


## Fills the curve's cells (the cells it passes through, in order) and the point of each. A step
## to a diagonal neighbour goes through the neighbour the curve is nearer to, so every step is
## one cell; that cell shares the point of the cell after it.
static func _rasterise(curve: RoadCurve) -> void:
	for index in curve.xs.size():
		var cell := Vector2i(int(floor(curve.xs[index])), int(floor(curve.ys[index])))
		var last := curve.cells.size() - 1
		if last >= 0 and curve.cells[last] == cell:
			continue
		if last >= 0:
			var step := cell - curve.cells[last]
			if absi(step.x) + absi(step.y) == 2:
				var first := Vector2i(cell.x, curve.cells[last].y)
				var second := Vector2i(curve.cells[last].x, cell.y)
				var near := (
					first if _gap(first, curve, index) <= _gap(second, curve, index) else second
				)
				curve.cells.append(near)
				curve.cell_points.append(index)
		curve.cells.append(cell)
		curve.cell_points.append(index)


static func _gap(cell: Vector2i, curve: RoadCurve, index: int) -> float:
	var dx := float(cell.x) + 0.5 - curve.xs[index]
	var dy := float(cell.y) + 0.5 - curve.ys[index]
	return dx * dx + dy * dy
