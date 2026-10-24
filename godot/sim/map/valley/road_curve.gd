## A road as the curve foes walk and the cells it covers (#404): the points of the curve and, for
## each road cell in walking order, the index of the point that stands for it. Plain data; the
## spline (`RoadSpline`) and the stitcher build it.
class_name RoadCurve
extends RefCounted

## Doubles, not `Vector2`, so distances keep their precision (see `Route`).
var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
## The road cells in walking order (unit steps).
var cells: Array[Vector2i] = []
## For each road cell, the index of its point, never decreasing along the road.
var cell_points := PackedInt32Array()


## The curve that joins the centres of these cells with straight lines (a road with no spline).
static func from_cells(cells: Array[Vector2i]) -> RoadCurve:
	var curve := RoadCurve.new()
	curve.cells = cells.duplicate()
	for index in cells.size():
		curve.xs.append(float(cells[index].x) + 0.5)
		curve.ys.append(float(cells[index].y) + 0.5)
		curve.cell_points.append(index)
	return curve


## Adds `other` after this curve's points (its cell points shift to follow).
func append_curve(other: RoadCurve) -> void:
	var shift := xs.size()
	cells.append_array(other.cells)
	xs.append_array(other.xs)
	ys.append_array(other.ys)
	for point in other.cell_points:
		cell_points.append(point + shift)


## The distance from the point (x, y) to the curve's nearest segment, in cells. Plain floats, no
## vectors: the socket placers call it for every anchor of a strip.
func distance_to(x: float, y: float) -> float:
	var best := 1.0e30
	for index in xs.size():
		best = minf(best, _gap_squared(index, x, y))
	return sqrt(best)


## The distance from the point (x, y) to the segment that starts at point `index` (the last
## point stands alone).
func segment_gap(index: int, x: float, y: float) -> float:
	return sqrt(_gap_squared(index, x, y))


## The distance from the curve to the square of `size` cells whose corner cell is (`cell_x`,
## `cell_y`): 0 where it touches it. A road band covers a cell, and a socket block must keep off
## the band, by this.
func rect_gap(cell_x: int, cell_y: int, size: int) -> float:
	var best := 1.0e30
	var left := float(cell_x)
	var top := float(cell_y)
	var right := left + float(size)
	var bottom := top + float(size)
	for index in xs.size():
		# a segment whose box is further than the best so far cannot be nearer
		var reach := sqrt(best) if best < 1.0e29 else 1.0e30
		var next := mini(index + 1, xs.size() - 1)
		if (
			maxf(xs[index], xs[next]) < left - reach
			or minf(xs[index], xs[next]) > right + reach
			or maxf(ys[index], ys[next]) < top - reach
			or minf(ys[index], ys[next]) > bottom + reach
		):
			continue
		best = minf(best, _rect_gap_squared(index, left, top, right, bottom))
	return sqrt(best)


## The same for the segment that starts at point `index` (the last point stands alone).
func segment_rect_gap(index: int, cell_x: int, cell_y: int, size: int) -> float:
	var left := float(cell_x)
	var top := float(cell_y)
	return sqrt(_rect_gap_squared(index, left, top, left + float(size), top + float(size)))


func _rect_gap_squared(index: int, left: float, top: float, right: float, bottom: float) -> float:
	var next := mini(index + 1, xs.size() - 1)
	var ax := xs[index]
	var ay := ys[index]
	var bx := xs[next]
	var by := ys[next]
	if _crosses(ax, ay, bx, by, left, top, right, bottom):
		return 0.0
	# the segments do not cross the square, so the nearest pair is an end against the square or a
	# corner against the segment
	var best := _gap_squared(index, left, top)
	best = minf(best, _gap_squared(index, right, top))
	best = minf(best, _gap_squared(index, left, bottom))
	best = minf(best, _gap_squared(index, right, bottom))
	var dx := maxf(maxf(left - ax, ax - right), 0.0)
	var dy := maxf(maxf(top - ay, ay - bottom), 0.0)
	best = minf(best, dx * dx + dy * dy)
	dx = maxf(maxf(left - bx, bx - right), 0.0)
	dy = maxf(maxf(top - by, by - bottom), 0.0)
	return minf(best, dx * dx + dy * dy)


## Whether the segment a to b meets the rectangle (Liang-Barsky clipping).
static func _crosses(
	ax: float, ay: float, bx: float, by: float, left: float, top: float, right: float, bottom: float
) -> bool:
	var enter := 0.0
	var leave := 1.0
	var step := bx - ax
	if step == 0.0:
		if ax < left or ax > right:
			return false
	else:
		var t0 := (left - ax) / step
		var t1 := (right - ax) / step
		enter = maxf(enter, minf(t0, t1))
		leave = minf(leave, maxf(t0, t1))
	step = by - ay
	if step == 0.0:
		if ay < top or ay > bottom:
			return false
	else:
		var t0 := (top - ay) / step
		var t1 := (bottom - ay) / step
		enter = maxf(enter, minf(t0, t1))
		leave = minf(leave, maxf(t0, t1))
	return enter <= leave


func _gap_squared(index: int, x: float, y: float) -> float:
	var next := mini(index + 1, xs.size() - 1)
	var ax := xs[index]
	var ay := ys[index]
	var abx := xs[next] - ax
	var aby := ys[next] - ay
	var along := 0.0
	var length_squared := abx * abx + aby * aby
	if length_squared > 0.0:
		along = clampf(((x - ax) * abx + (y - ay) * aby) / length_squared, 0.0, 1.0)
	var dx := ax + abx * along - x
	var dy := ay + aby * along - y
	return dx * dx + dy * dy
