## A camera that frames the whole board, pitched down like the plan says
## (about 55 degrees, about 35 degrees field of view, landscape).
##
## `fit_distance` is plain maths so it can be tested; `frame` places the
## camera for a screen shape and is called again when the window changes.
class_name CameraRig
extends Node3D

@export var pitch_degrees: float = 55.0
@export var fov_degrees: float = 35.0
## Room left around the board, as a share of its size.
@export var margin: float = 1.05

var _camera: Camera3D


func _ready() -> void:
	frame(_aspect())
	get_viewport().size_changed.connect(func() -> void: frame(_aspect()))


## How far back the camera must be, looking at the origin, so that every point
## fits on a screen with this aspect (width over height). `fov_degrees` is the
## vertical field of view; `margin` scales how far out the points may sit.
static func fit_distance(
	points: Array[Vector3], pitch_degrees: float, fov_degrees: float, aspect: float, margin: float
) -> float:
	var pitch := deg_to_rad(pitch_degrees)
	var forward := Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	var tan_v := tan(deg_to_rad(fov_degrees) / 2.0)
	var tan_h := tan_v * aspect
	var distance := 0.0
	for point in points:
		# a point is on screen when |across| * margin <= depth * tan(half fov)
		var depth_offset := point.dot(forward)
		distance = maxf(distance, absf(point.x) * margin / tan_h - depth_offset)
		distance = maxf(distance, absf(point.dot(up)) * margin / tan_v - depth_offset)
	return distance


## Places the camera for a screen of this aspect ratio.
func frame(aspect: float) -> void:
	if _camera == null:
		_camera = Camera3D.new()
		add_child(_camera)
	var pitch := deg_to_rad(pitch_degrees)
	var distance := fit_distance(BoardSpace.corners(), pitch_degrees, fov_degrees, aspect, margin)
	_camera.fov = fov_degrees
	_camera.rotation = Vector3(-pitch, 0.0, 0.0)
	_camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)


func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)
