## Tells the emulated mouse finger from the extra fingers.
##
## The engine turns the first finger that goes down into mouse events (and the
## board reads those), and delivers every finger as a touch event with an index.
## Browsers number touches as they like (Safari keeps counting up, so the first
## finger can be index 7), so the board must not read an index of 1 or more as "a
## second finger". This follows the engine's own rule: the first finger down while
## no finger is the mouse is the mouse, and every other finger is an extra one that
## gets a pointer id of 1 or more for the gesture tracker.
class_name TouchFingers
extends RefCounted

## The pointer id of the finger the engine emulates as the mouse (the gesture
## tracker reads that one from the mouse events).
const MOUSE := 0
const NO_FINGER := -1

var _mouse_index := NO_FINGER
var _extra := {}


## A finger went down: its pointer id (`MOUSE` for the emulated mouse finger).
## Pressing a finger already known changes nothing.
func press(index: int) -> int:
	if index == _mouse_index or _extra.has(index):
		return pointer_of(index)
	if _mouse_index == NO_FINGER:
		_mouse_index = index
		return MOUSE
	var id := 1
	while _extra.values().has(id):
		id += 1
	_extra[index] = id
	return id


## The pointer id of a finger; a finger never seen counts as the mouse one, which
## the board ignores in touch events.
func pointer_of(index: int) -> int:
	if _extra.has(index):
		return _extra[index]
	return MOUSE


## A finger went up: its pointer id, and the finger is forgotten.
func release(index: int) -> int:
	var id := pointer_of(index)
	if index == _mouse_index:
		_mouse_index = NO_FINGER
	_extra.erase(index)
	return id


## Forgets every finger (a focus loss can swallow the releases).
func reset() -> void:
	_mouse_index = NO_FINGER
	_extra.clear()
