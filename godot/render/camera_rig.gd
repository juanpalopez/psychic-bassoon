## The board camera: it pans across the 32x20 valley, and lets the player pan and zoom.
##
## The view is one number, `zoom`, from 0 (the overview: the whole map in view, looking down
## at 62 degrees) to 1 (close, looking in at 56 degrees, cells about 100 px wide
## on the 720 px canvas); a pinch or the mouse wheel moves it. The pitch barely changes:
## a steep, nearly top-down view keeps units and sockets readable at every zoom. A one-finger drag
## pans, within the map plus `SCENERY_MARGIN` and rubber-banding back after release. The field of
## view is about 20 degrees, landscape.
##
## A run starts on the spawn side (`start_view`), at a zoom where sockets can be tapped. On a
## phone the overview draws sockets under 44 pt, so a tap there flies the camera in to the socket
## first (`zoom_to_show`, `fly_to`); `square_pixels` measures how big a socket is drawn.
##
## The camera orbits its target by a fixed yaw (`YAW_DEGREES`) about the vertical axis, so the
## road, tape and sockets read at an angle instead of as strict rows and columns. The yaw is one
## constant, and a drag is turned by it so the scene still follows the finger.
##
## `fit_distance`, `pitch_for`, `closest_distance`, `footprint`, `pan_bounds`, `top_height`,
## `ground_drag`, `rubber`, `view_basis`, `eye_offset`, `project` and `start_pan` are plain maths
## so they can be tested; `frame` places the camera for a screen shape and is called again when
## the window changes.
class_name CameraRig
extends Node3D

## A flight (`fly_to`) ended: `arrived` is false when the player took the camera back first.
signal flight_ended(arrived: bool)

const TOWERS := preload("res://content/towers.gd")
## Metres to the near clip plane.
const CAMERA_NEAR := 1.0
## The narrowest screen the rig frames for (a hidden canvas reports no size).
const MIN_ASPECT := 0.5
## The turn about the vertical axis (degrees): the camera sits to the +x side of the target.
const YAW_DEGREES := 30.0
## The share of the screen (about its centre) that must stay over the map plus
## `SCENERY_MARGIN` when panning.
const SCREEN_SHARE_OVER_BOARD := 0.08
## How far past the map's edge (in cells) the middle of the screen may go: the spawn and the
## Heartstone sit on the edge, and this lets them come to the middle with scenery beyond them.
const SCENERY_MARGIN := 2.0
## The zoom at which the pans are fully open; below it they narrow toward 0 (the whole board).
const PAN_RAMP_ZOOM := 0.5
## The pitch (degrees below the horizon) zoomed out and zoomed in.
const MAX_PITCH := 62.0
const MIN_PITCH := 56.0
## How wide a cell is, in pixels of the 720 px canvas, at the closest zoom.
const CLOSEST_CELL_PIXELS := 100.0
## Overscroll that gets through while dragging past the edge (the rest is damped).
const RUBBER := 0.35
## No pinch centre given: the zoom does not move the view.
const NO_CENTRE := Vector2(-1.0, -1.0)
## One mouse wheel notch.
const WHEEL_STEP := 0.08
## How strongly a pinch factor moves the zoom (per doubling of the finger gap).
const PINCH_SENSITIVITY := 0.6
## How fast the view settles when the finger lets go (per second).
const SPRING := 14.0
## How long a flight to a tapped socket takes (seconds).
const FLY_SECONDS := 0.35
## Where the spawn sits at the start of a run: this share of the screen width from the left.
const START_SPAWN_SHARE := 0.25
## A run never starts further out than this zoom, so even a big screen starts on the spawn side.
const START_MIN_ZOOM := 0.4
## Halvings in the search for the zoom that draws a socket big enough (2^-24 of the zoom range).
const ZOOM_SEARCH_STEPS := 24

@export var fov_degrees: float = 20.0
## Room left around the board, as a share of its size.
@export var margin: float = 1.0

## 0 is the whole board in view, 1 is the closest view.
var zoom: float = 0.0
## Where the camera looks on the ground (x and z), as shown now.
var pan := Vector2.ZERO
## The height of the canvas in pixels; 0 reads it from the viewport. Tests set it,
## because a headless window is not the phone's 720 px canvas.
var canvas_height: float = 0.0

var _camera: Camera3D
var _aspect := 16.0 / 9.0
# the whole-board distance for the current aspect, so a drag never recomputes it
var _fit := 0.0
# the board size `_fit` and `_range` were measured for (the map in use can change)
var _fit_board := Vector2.ZERO
var _range_board := Vector2.ZERO
var _pan_raw := Vector2.ZERO
var _range := Rect2()
var _range_key := Vector4(-1.0, -1.0, -1.0, -1.0)
var _holding := false
var _flying := false
var _flight_time := 0.0
var _flight_from_pan := Vector2.ZERO
var _flight_to_pan := Vector2.ZERO
# zooms stay 64-bit floats: a Vector3 would round them to 32 bits
var _flight_from_zoom := 0.0
var _flight_to_zoom := 0.0


func _ready() -> void:
	frame(_screen_aspect())
	get_viewport().size_changed.connect(func() -> void: frame(_screen_aspect()))


func _process(delta: float) -> void:
	if _flying:
		_advance_flight(delta)
		return
	var range := pan_range()
	if _holding:
		pan = _rubbered(_pan_raw, range)
	else:
		_pan_raw = _pan_raw.clamp(range.position, range.end)
		var before := pan
		pan = pan.lerp(_pan_raw, 1.0 - exp(-SPRING * delta))
		if pan.distance_to(before) < 1e-7:
			return
	_place()


## How far back the camera must be, looking at the origin, so that every point
## fits on a screen with this aspect (width over height). `fov_degrees` is the
## vertical field of view; `margin` scales how far out the points may sit. The camera
## is turned by `yaw_degrees` about the vertical axis, so the points are measured
## along its turned right, up and forward directions.
static func fit_distance(
	points: Array[Vector3],
	pitch_degrees: float,
	fov_degrees: float,
	aspect: float,
	margin: float,
	yaw_degrees: float = 0.0
) -> float:
	var pitch := deg_to_rad(pitch_degrees)
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var forward := turn * Vector3(0.0, -sin(pitch), -cos(pitch))
	var up := turn * Vector3(0.0, cos(pitch), -sin(pitch))
	var right := turn * Vector3.RIGHT
	var tan_v := tan(deg_to_rad(fov_degrees) / 2.0)
	var tan_h := tan_v * aspect
	var distance := 0.0
	for point in points:
		# a point is on screen when |across| * margin <= depth * tan(half fov)
		var depth_offset := point.dot(forward)
		distance = maxf(distance, absf(point.dot(right)) * margin / tan_h - depth_offset)
		distance = maxf(distance, absf(point.dot(up)) * margin / tan_v - depth_offset)
	return distance


## The pitch for a zoom: 62 degrees zoomed out, 56 degrees zoomed in.
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


## The part of the ground the screen shows when the camera targets the middle of the board
## (pan 0) and is turned by `yaw_degrees`: the box around where the four corners of the screen
## meet the ground. `share` shrinks the screen about its centre first (0.08 keeps only its middle).
## A pan moves the whole footprint, so a box is exact for keeping its corners over the board.
static func footprint(
	distance: float,
	pitch_degrees: float,
	fov_degrees_value: float,
	aspect: float,
	yaw_degrees: float = 0.0,
	share: float = 1.0
) -> Rect2:
	var pitch := deg_to_rad(pitch_degrees)
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var position := turn * Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	var basis := turn * Basis(Vector3.RIGHT, -pitch)
	var tan_v := tan(deg_to_rad(fov_degrees_value) / 2.0)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		var direction := (
			basis * Vector3(corner.x * share * tan_v * aspect, corner.y * share * tan_v, -1.0)
		)
		if direction.y >= -1e-6:
			continue
		var hit := position + direction * (-position.y / direction.y)
		low = Vector2(minf(low.x, hit.x), minf(low.y, hit.z))
		high = Vector2(maxf(high.x, hit.x), maxf(high.y, hit.z))
	return Rect2(low, high - low)


## The pans (the camera target, x and z) that keep a footprint over the board: the board's
## half size less what the footprint covers each way. An axis where the footprint is larger than
## the board has no range that fits, so it collapses to the midpoint of the two limits (not to 0,
## so the pan stays continuous as the zoom changes).
static func pan_bounds(board_half: Vector2, foot: Rect2) -> Rect2:
	var low := -board_half - foot.position
	var high := board_half - foot.end
	if low.x > high.x:
		low.x = (low.x + high.x) / 2.0
		high.x = low.x
	if low.y > high.y:
		low.y = (low.y + high.y) / 2.0
		high.y = low.y
	return Rect2(low, high - low)


## The pans narrowed for a zoom: all of `bounds` from `PAN_RAMP_ZOOM` up, shrinking toward 0 (the
## pan the fit is made for, so the whole board is in view) as the zoom falls to 0. A collapsed
## axis (no room that fits) thus moves smoothly from 0 to its midpoint instead of jumping.
static func pan_ramp(bounds: Rect2, zoom_value: float) -> Rect2:
	var ease := clampf(zoom_value / PAN_RAMP_ZOOM, 0.0, 1.0)
	var low := bounds.position * ease
	var high := bounds.end * ease
	# an axis with room keeps to its limits even when 0 is not among them
	if bounds.size.x > 0.0:
		low.x = clampf(low.x, bounds.position.x, bounds.end.x)
		high.x = clampf(high.x, bounds.position.x, bounds.end.x)
	if bounds.size.y > 0.0:
		low.y = clampf(low.y, bounds.position.y, bounds.end.y)
		high.y = clampf(high.y, bounds.position.y, bounds.end.y)
	return Rect2(low, high - low)


## The highest point the board can have, for the fit: the top cliff plus the tallest tower body
## (a default look at its top level). A tower at a corner of the board must stay on screen.
static func top_height() -> float:
	var look := TowerLook.new()
	var top_level := 0
	for def in TOWERS.DEFS.values():
		top_level = maxi(top_level, (def.cost as Array).size() - 1)
	var cliff: float = Board.LEVEL_HEIGHTS[Board.LEVEL_HEIGHTS.size() - 1]
	return cliff + look.base_height + look.height_per_level * float(top_level)


## How far the camera target moves on the ground (x and z) for a drag of `delta` screen pixels:
## the scene follows the finger, so a drag right moves the target left along the camera's
## right and a drag down moves it up the screen. `ground_per_pixel` is the ground a pixel
## covers across the screen; the up-screen direction is foreshortened by the pitch.
static func ground_drag(
	delta: Vector2, ground_per_pixel: float, pitch_degrees: float, yaw_degrees: float
) -> Vector2:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	var right := turn * Vector3.RIGHT
	var ahead := turn * Vector3.FORWARD
	var across := -delta.x * ground_per_pixel
	var along := delta.y * ground_per_pixel / sin(deg_to_rad(pitch_degrees))
	return Vector2(right.x, right.z) * across + Vector2(ahead.x, ahead.z) * along


## A value outside `low` to `high` is damped: only `RUBBER` of the overshoot gets through.
static func rubber(value: float, low: float, high: float) -> float:
	if value > high:
		return high + (value - high) * RUBBER
	if value < low:
		return low - (low - value) * RUBBER
	return value


## How the camera is turned for a pitch (degrees below the horizon) and a yaw: no roll.
static func view_basis(pitch_degrees: float, yaw_degrees: float) -> Basis:
	return (
		Basis(Vector3.UP, deg_to_rad(yaw_degrees))
		* Basis(Vector3.RIGHT, -deg_to_rad(pitch_degrees))
	)


## Where the camera sits relative to the point it looks at, `distance` away.
static func eye_offset(distance: float, pitch_degrees: float, yaw_degrees: float) -> Vector3:
	var pitch := deg_to_rad(pitch_degrees)
	return (
		Basis(Vector3.UP, deg_to_rad(yaw_degrees))
		* Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	)


## Where a world point is drawn on a canvas of `canvas` pixels, for a camera at `eye` turned by
## `basis` with a vertical field of view of `fov_degrees_value` (as `Camera3D.unproject_position`
## does, but for any view, so a view can be measured before the camera goes there).
static func project(
	point: Vector3, eye: Vector3, basis: Basis, fov_degrees_value: float, canvas: Vector2
) -> Vector2:
	var local := basis.transposed() * (point - eye)
	var depth := maxf(-local.z, 1e-6)
	var scale := canvas.y / (2.0 * tan(deg_to_rad(fov_degrees_value) / 2.0) * depth)
	return canvas / 2.0 + Vector2(local.x, -local.y) * scale


## The pan a run starts at: the spawn, moved along the camera's right so that it sits
## `START_SPAWN_SHARE` of the way across a screen showing `ground_width` of ground.
static func start_pan(spawn: Vector2, ground_width: float, yaw_degrees: float) -> Vector2:
	var right := Basis(Vector3.UP, deg_to_rad(yaw_degrees)) * Vector3.RIGHT
	return spawn + Vector2(right.x, right.z) * ground_width * (0.5 - START_SPAWN_SHARE)


## The camera this rig places.
func camera() -> Camera3D:
	if _camera == null:
		_camera = Camera3D.new()
		# the camera sits tens of metres up; the default 5 cm near plane wastes depth precision
		# and made close, stacked paper layers flicker on WebGL
		_camera.near = CAMERA_NEAR
		add_child(_camera)
	return _camera


## Places the camera for a screen of this aspect ratio.
func frame(aspect: float) -> void:
	_aspect = maxf(aspect, MIN_ASPECT)
	_fit = 0.0
	_place()


func set_zoom(value: float) -> void:
	cancel_flight()
	zoom = clampf(value, 0.0, 1.0)
	_place()


## A pinch: spreading (factor above 1) zooms in, closing zooms out. Given the middle of the
## fingers in screen pixels, the point of the board under them stays under them.
func zoom_by(factor: float, centre: Vector2 = NO_CENTRE) -> void:
	var pinned := centre != NO_CENTRE
	var before := ground_under(centre) if pinned else Vector2.ZERO
	set_zoom(zoom + log(maxf(factor, 1e-6)) / log(2.0) * PINCH_SENSITIVITY)
	if pinned:
		_pan_raw += before - ground_under(centre)
		var range := pan_range()
		pan = _rubbered(_pan_raw, range) if _holding else _pan_raw.clamp(range.position, range.end)
		_place()


## The ground point (x and z) under a screen pixel.
func ground_under(pixel: Vector2) -> Vector2:
	var camera_node := camera()
	var origin := camera_node.project_ray_origin(pixel)
	var direction := camera_node.project_ray_normal(pixel)
	if direction.y >= -1e-6:
		return Vector2(origin.x, origin.z)
	var hit := origin + direction * (-origin.y / direction.y)
	return Vector2(hit.x, hit.z)


## The pans allowed now: the middle `SCREEN_SHARE_OVER_BOARD` of the screen stays over the map
## plus `SCENERY_MARGIN`, so the map's outer rows can come to the middle of the screen with
## scenery around them.
func pan_range() -> Rect2:
	# the range only changes with the zoom, the screen shape, the fit, the canvas height and the board
	_current_fit()
	var key := Vector4(zoom, _aspect, _fit, canvas_height)
	if key != _range_key or BoardSpace.size() != _range_board:
		_range_key = key
		_range_board = BoardSpace.size()
		_range = pan_range_at(zoom)
	return _range


## The pans allowed at a zoom (see `pan_range`).
func pan_range_at(zoom_value: float) -> Rect2:
	var foot := footprint(
		_distance_at(zoom_value),
		pitch_for(zoom_value),
		fov_degrees,
		_aspect,
		YAW_DEGREES,
		SCREEN_SHARE_OVER_BOARD
	)
	var half := BoardSpace.size() / 2.0 + Vector2.ONE * SCENERY_MARGIN
	return pan_ramp(pan_bounds(half, foot), zoom_value)


## How wide (its narrowest width, in canvas pixels) a flat square `side` cells wide around
## `centre` is drawn now.
func square_pixels(centre: Vector3, side: float) -> float:
	return square_pixels_at(zoom, pan, centre, side)


## How wide a flat square around `centre` would be drawn at this zoom and pan.
func square_pixels_at(zoom_value: float, pan_value: Vector2, centre: Vector3, side: float) -> float:
	var pitch := pitch_for(zoom_value)
	var eye := (
		Vector3(pan_value.x, 0.0, pan_value.y)
		+ eye_offset(_distance_at(zoom_value), pitch, YAW_DEGREES)
	)
	var basis := view_basis(pitch, YAW_DEGREES)
	var height := maxf(_viewport_height(), 1.0)
	var canvas := Vector2(height * _aspect, height)
	var drawn := PackedVector2Array()
	for corner in TapZoom.square_corners(centre, side):
		drawn.append(project(corner, eye, basis, fov_degrees, canvas))
	return TapZoom.narrowest_width(drawn)


## The pan that brings a point (it may be raised) to the middle of the screen at a zoom, as near
## as the limits allow.
func pan_to_centre(point: Vector3, zoom_value: float) -> Vector2:
	var forward := -view_basis(pitch_for(zoom_value), YAW_DEGREES).z
	var ground := point + forward * (point.y / -forward.y)
	var range := pan_range_at(zoom_value)
	return Vector2(ground.x, ground.z).clamp(range.position, range.end)


## The least zoom at which a flat square `side` cells wide around `centre`, brought to the middle
## of the screen as near as the limits allow, is drawn at least `min_pixels` across its narrowest
## width; 1 when even the closest zoom draws it smaller.
func zoom_to_show(centre: Vector3, side: float, min_pixels: float) -> float:
	if _shown_pixels(centre, side, 0.0) >= min_pixels:
		return 0.0
	if _shown_pixels(centre, side, 1.0) < min_pixels:
		return 1.0
	var low := 0.0
	var high := 1.0
	for i in ZOOM_SEARCH_STEPS:
		var middle := (low + high) / 2.0
		if _shown_pixels(centre, side, middle) >= min_pixels:
			high = middle
		else:
			low = middle
	return high


## Eases the camera to `target_zoom` with `point` in the middle of the screen (as near as the
## limits allow) over `FLY_SECONDS`, then emits `flight_ended(true)`. A drag, a pinch or a zoom
## by the player ends it early.
func fly_to(point: Vector3, target_zoom: float) -> void:
	cancel_flight()
	var to_zoom := clampf(target_zoom, 0.0, 1.0)
	var to_pan := pan_to_centre(point, to_zoom)
	_flight_from_pan = pan
	_flight_to_pan = to_pan
	_flight_from_zoom = zoom
	_flight_to_zoom = to_zoom
	_flight_time = 0.0
	_holding = false
	_flying = true


## Puts the camera at a zoom with `point` in the middle of the screen (as near as the limits
## allow) at once, with no flight.
func show_point(point: Vector3, zoom_value: float) -> void:
	cancel_flight()
	_holding = false
	zoom = clampf(zoom_value, 0.0, 1.0)
	pan = pan_to_centre(point, zoom)
	_pan_raw = pan
	_place()


## Whether a flight is under way.
func flying() -> bool:
	return _flying


## Ends a flight where the camera is now and emits `flight_ended(false)`; no flight, nothing.
func cancel_flight() -> void:
	if not _flying:
		return
	_flying = false
	_pan_raw = pan
	flight_ended.emit(false)


## The view a run starts in: on the spawn side, with the spawn `START_SPAWN_SHARE` of the way
## across the screen, at the least zoom where a socket `side` cells wide in the middle of the
## screen is `min_pixels` across (and no further out than `START_MIN_ZOOM`).
func start_view(spawn: Vector3, side: float, min_pixels: float) -> void:
	cancel_flight()
	_holding = false
	var centred := 0.0
	if _centred_pixels(side, 1.0) < min_pixels:
		centred = 1.0
	elif _centred_pixels(side, 0.0) < min_pixels:
		var low := 0.0
		centred = 1.0
		for i in ZOOM_SEARCH_STEPS:
			var middle := (low + centred) / 2.0
			if _centred_pixels(side, middle) >= min_pixels:
				centred = middle
			else:
				low = middle
	zoom = maxf(centred, START_MIN_ZOOM)
	var width := 2.0 * _distance() * tan(deg_to_rad(fov_degrees) / 2.0) * _aspect
	var range := pan_range()
	pan = start_pan(Vector2(spawn.x, spawn.z), width, YAW_DEGREES).clamp(range.position, range.end)
	_pan_raw = pan
	_place()


## Mouse wheel notches: positive zooms in.
func zoom_steps(steps: float) -> void:
	set_zoom(zoom + steps * WHEEL_STEP)


## A drag of `delta` screen pixels: the scene follows the finger.
func pan_by_pixels(delta: Vector2) -> void:
	cancel_flight()
	_holding = true
	var height := maxf(_viewport_height(), 1.0)
	var ground_per_pixel := 2.0 * _distance() * tan(deg_to_rad(fov_degrees) / 2.0) / height
	_pan_raw += ground_drag(delta, ground_per_pixel, pitch_for(zoom), YAW_DEGREES)
	pan = _rubbered(_pan_raw, pan_range())
	_place()


## The finger let go: the view settles back inside the board.
func release_pan() -> void:
	_holding = false


func _rubbered(raw: Vector2, range: Rect2) -> Vector2:
	return Vector2(
		rubber(raw.x, range.position.x, range.end.x), rubber(raw.y, range.position.y, range.end.y)
	)


func _shown_pixels(centre: Vector3, side: float, zoom_value: float) -> float:
	return square_pixels_at(zoom_value, pan_to_centre(centre, zoom_value), centre, side)


## A square at the point the camera looks at, at a zoom: the same wherever the camera is.
func _centred_pixels(side: float, zoom_value: float) -> float:
	return square_pixels_at(zoom_value, Vector2.ZERO, Vector3.ZERO, side)


func _advance_flight(delta: float) -> void:
	_flight_time = minf(_flight_time + delta, FLY_SECONDS)
	var eased := smoothstep(0.0, 1.0, _flight_time / FLY_SECONDS)
	zoom = lerpf(_flight_from_zoom, _flight_to_zoom, eased)
	pan = _flight_from_pan.lerp(_flight_to_pan, eased)
	_pan_raw = pan
	_place()
	if _flight_time >= FLY_SECONDS:
		_flying = false
		flight_ended.emit(true)


## Camera distance from its target at the current zoom.
func _distance() -> float:
	return _distance_at(zoom)


func _distance_at(zoom_value: float) -> float:
	var fit := _current_fit()
	var closest := closest_distance(fov_degrees, _viewport_height(), fit)
	return lerpf(fit, closest, clampf(zoom_value, 0.0, 1.0))


## The whole-board distance for the board in use, measured again when the map's size changed.
func _current_fit() -> float:
	var board := BoardSpace.size()
	if _fit <= 0.0 or board != _fit_board:
		_fit_board = board
		_fit = _fit_now()
	return _fit


func _place() -> void:
	var camera_node := camera()
	var pitch := pitch_for(zoom)
	camera_node.fov = fov_degrees
	# orbit the pan target: the same offset as before the yaw, turned about the vertical axis
	camera_node.basis = view_basis(pitch, YAW_DEGREES)
	camera_node.position = Vector3(pan.x, 0.0, pan.y) + eye_offset(_distance(), pitch, YAW_DEGREES)


func _fit_now() -> float:
	var points: Array[Vector3] = []
	for corner in BoardSpace.corners():
		points.append(corner)
		points.append(corner + Vector3(0.0, top_height(), 0.0))
	return fit_distance(points, MAX_PITCH, fov_degrees, _aspect, margin, YAW_DEGREES)


func _screen_aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	# a hidden or minimised canvas has no size: keep a sane shape, never 0
	return maxf(size.x / maxf(size.y, 1.0), MIN_ASPECT)


func _viewport_height() -> float:
	if canvas_height > 0.0:
		return canvas_height
	return get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
