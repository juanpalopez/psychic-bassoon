## The board camera: it frames the whole board, and lets the player pan and zoom.
##
## The view is one number, `zoom`, from 0 (the whole board in view, looking down
## at 65 degrees) to 1 (close, looking in at 30 degrees, cells about 120 px wide
## on the 720 px canvas); a pinch or the mouse wheel moves it. A one-finger drag
## pans, within the board and rubber-banding back after release. The field of
## view is about 35 degrees, landscape.
##
## `fit_distance`, `pitch_for`, `closest_distance`, `pan_limit` and `rubber` are
## plain maths so they can be tested; `frame` places the camera for a screen
## shape and is called again when the window changes.
class_name CameraRig
extends Node3D

## The narrowest screen the rig frames for (a hidden canvas reports no size).
const MIN_ASPECT := 0.5
## The pitch (degrees below the horizon) zoomed out and zoomed in.
const MAX_PITCH := 65.0
const MIN_PITCH := 30.0
## How wide a cell is, in pixels of the 720 px canvas, at the closest zoom.
const CLOSEST_CELL_PIXELS := 120.0
## How far the target may leave the centre, as a share of the board's half size
## at full zoom; zoomed out there is nothing to pan.
const PAN_LIMIT_SHARE := 0.9
## Overscroll that gets through while dragging past the edge (the rest is damped).
const RUBBER := 0.35
## One mouse wheel notch.
const WHEEL_STEP := 0.08
## How strongly a pinch factor moves the zoom (per doubling of the finger gap).
const PINCH_SENSITIVITY := 0.6
## How fast the view settles when the finger lets go (per second).
const SPRING := 14.0

@export var fov_degrees: float = 35.0
## Room left around the board, as a share of its size.
@export var margin: float = 1.05

## 0 is the whole board in view, 1 is the closest view.
var zoom: float = 0.0
## Where the camera looks on the ground (x and z), as shown now.
var pan := Vector2.ZERO
## The height of the canvas in pixels; 0 reads it from the viewport. Tests set it,
## because a headless window is not the phone's 720 px canvas.
var canvas_height: float = 0.0

var _camera: Camera3D
var _aspect := 16.0 / 9.0
var _pan_raw := Vector2.ZERO
var _holding := false


func _ready() -> void:
	frame(_screen_aspect())
	get_viewport().size_changed.connect(func() -> void: frame(_screen_aspect()))


func _process(delta: float) -> void:
	var limit := pan_limit(zoom)
	if _holding:
		pan = Vector2(rubber(_pan_raw.x, limit.x), rubber(_pan_raw.y, limit.y))
	else:
		_pan_raw = _pan_raw.clamp(-limit, limit)
		var before := pan
		pan = pan.lerp(_pan_raw, 1.0 - exp(-SPRING * delta))
		if pan.distance_to(before) < 1e-7:
			return
	_place()


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


## The pitch for a zoom: 65 degrees zoomed out, 30 degrees zoomed in.
static func pitch_for(zoom_value: float) -> float:
	return lerpf(MAX_PITCH, MIN_PITCH, clampf(zoom_value, 0.0, 1.0))


## How close the camera may come: where a cell is `CLOSEST_CELL_PIXELS` wide on a
## canvas `viewport_height` pixels tall, but never further out than the fit (on a
## small screen the cell size yields to the fitted view).
static func closest_distance(fov_degrees: float, viewport_height: float, fit: float) -> float:
	var distance := (
		viewport_height / (2.0 * tan(deg_to_rad(fov_degrees) / 2.0) * CLOSEST_CELL_PIXELS)
	)
	return minf(distance, fit)


## How far the camera target may leave the centre of the board at this zoom.
static func pan_limit(zoom_value: float) -> Vector2:
	return BoardSpace.size() / 2.0 * PAN_LIMIT_SHARE * clampf(zoom_value, 0.0, 1.0)


## A value past `limit` is damped: only `RUBBER` of the overshoot gets through.
static func rubber(value: float, limit: float) -> float:
	if absf(value) <= limit:
		return value
	return signf(value) * (limit + (absf(value) - limit) * RUBBER)


## The camera this rig places.
func camera() -> Camera3D:
	if _camera == null:
		_camera = Camera3D.new()
		add_child(_camera)
	return _camera


## Places the camera for a screen of this aspect ratio.
func frame(aspect: float) -> void:
	_aspect = maxf(aspect, MIN_ASPECT)
	_place()


func set_zoom(value: float) -> void:
	zoom = clampf(value, 0.0, 1.0)
	_place()


## A pinch: spreading (factor above 1) zooms in, closing zooms out.
func zoom_by(factor: float) -> void:
	set_zoom(zoom + log(maxf(factor, 1e-6)) / log(2.0) * PINCH_SENSITIVITY)


## Mouse wheel notches: positive zooms in.
func zoom_steps(steps: float) -> void:
	set_zoom(zoom + steps * WHEEL_STEP)


## A drag of `delta` screen pixels: the scene follows the finger.
func pan_by_pixels(delta: Vector2) -> void:
	_holding = true
	var height := maxf(_viewport_height(), 1.0)
	var ground_per_pixel := 2.0 * _distance() * tan(deg_to_rad(fov_degrees) / 2.0) / height
	var foreshortening := sin(deg_to_rad(pitch_for(zoom)))
	_pan_raw.x -= delta.x * ground_per_pixel
	_pan_raw.y -= delta.y * ground_per_pixel / foreshortening
	var limit := pan_limit(zoom)
	pan = Vector2(rubber(_pan_raw.x, limit.x), rubber(_pan_raw.y, limit.y))
	_place()


## The finger let go: the view settles back inside the board.
func release_pan() -> void:
	_holding = false


## Camera distance from its target at the current zoom.
func _distance() -> float:
	var fit := fit_distance(BoardSpace.corners(), MAX_PITCH, fov_degrees, _aspect, margin)
	var closest := closest_distance(fov_degrees, _viewport_height(), fit)
	return lerpf(fit, closest, zoom)


func _place() -> void:
	var camera_node := camera()
	var pitch := deg_to_rad(pitch_for(zoom))
	var distance := _distance()
	camera_node.fov = fov_degrees
	camera_node.rotation = Vector3(-pitch, 0.0, 0.0)
	camera_node.position = Vector3(pan.x, sin(pitch) * distance, pan.y + cos(pitch) * distance)


func _screen_aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	# a hidden or minimised canvas has no size: keep a sane shape, never 0
	return maxf(size.x / maxf(size.y, 1.0), MIN_ASPECT)


func _viewport_height() -> float:
	if canvas_height > 0.0:
		return canvas_height
	return get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
