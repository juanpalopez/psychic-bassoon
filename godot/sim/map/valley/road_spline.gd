## Builds a smooth road through waypoints (#404): a cubic Hermite spline with Catmull-Rom style
## tangents (it passes through every waypoint and turns smoothly at each), sampled finely enough
## to rasterise into road cells that step one cell at a time. Only `+ - * /`, `floor` and `sqrt`
## are used, so the curve is the same on every machine. Waypoints are in cell units: (x + 0.5, y +
## 0.5) is the middle of cell (x, y).
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
			curve.xs.append(_blend(p0.x, p1.x, p2.x, p3.x, t, _tangent_scale(p0, p1, p2, p3)))
			curve.ys.append(_blend(p0.y, p1.y, p2.y, p3.y, t, _tangent_scale(p0, p1, p2, p3)))
	curve.xs.append(float(waypoints[count - 1].x))
	curve.ys.append(float(waypoints[count - 1].y))
	_rasterise(curve)
	return curve


## The two tangent lengths of the segment from `p1` to `p2`, as factors of the vectors `p2 - p0`
## and `p3 - p1`: each tangent points along its chord pair and is as long as the segment, so
## waypoints that are unevenly spaced never make the curve overshoot into a loop (a uniform
## Catmull-Rom spline does). Returns (start factor, end factor).
static func _tangent_scale(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Vector2:
	var segment := _length(p1, p2)
	var before := _length(p0, p2)
	var after := _length(p1, p3)
	return Vector2(segment / maxf(before, 0.000001), segment / maxf(after, 0.000001))


static func _length(a: Vector2, b: Vector2) -> float:
	var dx := float(b.x) - float(a.x)
	var dy := float(b.y) - float(a.y)
	return sqrt(dx * dx + dy * dy)


## One coordinate of the cubic Hermite curve between `b` and `c` at `t` in [0, 1), with the tangent
## at `b` along `c - a` and the tangent at `c` along `d - b`, scaled by `scale`.
static func _blend(a: float, b: float, c: float, d: float, t: float, scale: Vector2) -> float:
	var t2 := t * t
	var t3 := t2 * t
	var start := (c - a) * scale.x
	var end := (d - b) * scale.y
	return (
		(2.0 * t3 - 3.0 * t2 + 1.0) * b
		+ (t3 - 2.0 * t2 + t) * start
		+ (3.0 * t2 - 2.0 * t3) * c
		+ (t3 - t2) * end
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
