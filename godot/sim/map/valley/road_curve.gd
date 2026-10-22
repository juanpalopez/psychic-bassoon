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
