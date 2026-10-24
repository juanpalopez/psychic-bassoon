## A road template (#432): a piece of road in a local frame, from
## `godot/content/valley/segments.gd`.
## The entry is at (0, 0) heading +x, +y is to the right of the heading, units are cells. A value
## object: build it once, never change it. The fitter (`SegmentFitter`) places it between gates.
class_name RoadSegment
extends RefCounted

const SEGMENTS := preload("res://content/valley/segments.gd")

static var _library: Dictionary = {}

var id: StringName = &""
## The spline's control points, the first at the origin.
var points: Array[Vector2] = []
## Unit vectors: the way the road runs in at the entry and out at the exit.
var entry_heading := Vector2.ZERO
var exit_heading := Vector2.ZERO
## Where the exit is, from the entry (the last control point).
var exit := Vector2.ZERO
var width: float = 0.0
## The half width of free ground the road needs beside it.
var clearance: float = 0.0
## What the piece is for (a bend, a crossing, a wrap round high ground).
var tag: StringName = &""
var min_turn_radius: float = 0.0
## The least and most the fitter may scale it along either local axis.
var scale_range := Vector2.ONE


## The template with this id (`SEGMENTS.SWEEP`, ...).
static func get_segment(segment_id: StringName) -> RoadSegment:
	if _library.is_empty():
		for key in SEGMENTS.DATA:
			_library[key] = _from_data(key, SEGMENTS.DATA[key])
	return _library[segment_id]


## The ids of every template, in a fixed order.
static func ids() -> Array[StringName]:
	return [
		SEGMENTS.SWEEP,
		SEGMENTS.S_BEND,
		SEGMENTS.BRIDGE,
		SEGMENTS.RIDGE_WRAP,
		SEGMENTS.LANDMARK,
		SEGMENTS.HOOK,
		SEGMENTS.U_TURN,
		SEGMENTS.JOG,
	]


## The road through the control points, in the local frame moved to `origin`.
func build(origin: Vector2) -> RoadCurve:
	var moved: Array[Vector2] = []
	for point in points:
		moved.append(point + origin)
	return RoadSpline.build(moved)


static func _from_data(segment_id: StringName, data: Dictionary) -> RoadSegment:
	var segment := RoadSegment.new()
	segment.id = segment_id
	for point in data["points"]:
		segment.points.append(point)
	segment.entry_heading = data["entry_heading"]
	segment.exit_heading = data["exit_heading"]
	segment.exit = segment.points[segment.points.size() - 1]
	segment.width = SEGMENTS.WIDTH
	segment.clearance = SEGMENTS.CLEARANCE
	segment.tag = data["tag"]
	segment.min_turn_radius = data["min_turn_radius"]
	segment.scale_range = data["scale"]
	return segment
