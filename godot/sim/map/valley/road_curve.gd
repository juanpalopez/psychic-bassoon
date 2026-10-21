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
