## Turns pointer events into the three things the board cares about: a tap, a
## pan (one finger dragging, or two fingers moving together) and a pinch (two
## fingers spreading or closing). Pure logic with signals: it knows nothing
## about the camera or the scene, so it can be tested with plain numbers.
##
## Feed it `press`, `move` and `release` for each pointer (an id and a position
## in the same units each time). A press that never moves past `DRAG_THRESHOLD`
## is a tap when it lifts; once a drag starts, every pixel of it is passed on.
class_name Gestures
extends RefCounted

signal tapped(position: Vector2)
signal panned(by: Vector2)
signal pinched(factor: float, centre: Vector2)
## The last finger lifted (after a tap or a drag): time to let the camera settle.
signal ended

## How far a finger may wander (in viewport pixels) and still be a tap.
const DRAG_THRESHOLD := 20.0

var _pointers := {}
var _start := Vector2.ZERO
var _dragging := false
var _tap_possible := false
var _last_distance := 0.0
var _last_centre := Vector2.ZERO


func press(id: int, position: Vector2) -> void:
	_pointers[id] = position
	if _pointers.size() == 1:
		_start = position
		_dragging = false
		_tap_possible = true
	elif _pointers.size() == 2:
		_tap_possible = false
		_last_distance = _distance()
		_last_centre = _centre()


func move(id: int, position: Vector2) -> void:
	if not _pointers.has(id):
		return
	var before: Vector2 = _pointers[id]
	_pointers[id] = position
	if _pointers.size() == 1:
		if not _dragging and position.distance_to(_start) > DRAG_THRESHOLD:
			_dragging = true
			_tap_possible = false
			panned.emit(position - _start)
		elif _dragging:
			panned.emit(position - before)
	elif _pointers.size() >= 2:
		var distance := _distance()
		var centre := _centre()
		if _last_distance > 0.0 and distance > 0.0:
			pinched.emit(distance / _last_distance, centre)
		panned.emit(centre - _last_centre)
		_last_distance = distance
		_last_centre = centre


func release(id: int, position: Vector2) -> void:
	if not _pointers.has(id):
		return
	if _pointers.size() == 1 and _tap_possible and not _dragging:
		tapped.emit(position)
	_pointers.erase(id)
	if _pointers.size() == 1:
		# the finger left after a pinch keeps panning from where it is, never taps
		_dragging = true
		_tap_possible = false
	elif _pointers.size() == 2:
		# a third finger lifted: the pair may be a different one, so measure afresh
		_last_distance = _distance()
		_last_centre = _centre()
	elif _pointers.is_empty():
		_dragging = false
		_tap_possible = false
		ended.emit()


## Forgets everything in progress (the window lost focus, a menu took the touch)
## and tells the camera the fingers are gone.
func cancel() -> void:
	var was_active := not _pointers.is_empty()
	_pointers.clear()
	_dragging = false
	_tap_possible = false
	if was_active:
		ended.emit()


## The two pointers with the lowest ids drive a pinch.
func _two() -> Array:
	var ids := _pointers.keys()
	ids.sort()
	return [_pointers[ids[0]], _pointers[ids[1]]]


func _distance() -> float:
	var two := _two()
	return (two[0] as Vector2).distance_to(two[1])


func _centre() -> Vector2:
	var two := _two()
	return ((two[0] as Vector2) + (two[1] as Vector2)) / 2.0
