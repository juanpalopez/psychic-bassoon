## The intro wave as a sequence of steps. Each step waits for something the player does:
## read the goal (Next), tap a socket, build a tower, start a wave, watch it clear. Skip ends
## it from anywhere. It holds no nodes; the scene tells it what happened and shows its words.
class_name IntroFlow
extends RefCounted

signal finished(skipped: bool)

enum Step { IDLE, GOAL, PICK_SOCKET, PICK_TOWER, START_WAVE, WATCH, DONE }
enum Event { NEXT, SOCKET_SELECTED, TOWER_BUILT, WAVE_LAUNCHED, WAVE_CLEARED }

const GUIDE := preload("res://content/guide.gd")
const KEYS := {
	Step.GOAL: "goal",
	Step.PICK_SOCKET: "pick_socket",
	Step.PICK_TOWER: "pick_tower",
	Step.START_WAVE: "start_wave",
	Step.WATCH: "watch",
	Step.DONE: "done",
}

var _step := Step.IDLE


func start() -> void:
	_step = Step.GOAL


func step() -> Step:
	return _step


func is_active() -> bool:
	return _step != Step.IDLE


## What happened in the game. An event that does not belong to the step is ignored, except
## that a tower built or a wave launched early jumps ahead (the player knew what to do).
func notify(event: Event) -> void:
	match _step:
		Step.GOAL:
			if event == Event.NEXT:
				_step = Step.PICK_SOCKET
		Step.PICK_SOCKET:
			if event == Event.SOCKET_SELECTED:
				_step = Step.PICK_TOWER
			elif event == Event.TOWER_BUILT:
				_step = Step.START_WAVE
			elif event == Event.WAVE_LAUNCHED:
				_step = Step.WATCH
		Step.PICK_TOWER:
			if event == Event.TOWER_BUILT:
				_step = Step.START_WAVE
			elif event == Event.WAVE_LAUNCHED:
				_step = Step.WATCH
		Step.START_WAVE:
			if event == Event.WAVE_LAUNCHED:
				_step = Step.WATCH
		Step.WATCH:
			if event == Event.WAVE_CLEARED:
				_step = Step.DONE
		Step.DONE:
			if event == Event.NEXT:
				_finish(false)


func skip() -> void:
	if is_active():
		_finish(true)


## The words of the step, or "" when the intro is not running.
func text() -> String:
	return GUIDE.INTRO[KEYS[_step]].text if KEYS.has(_step) else ""


## The name of the HUD control the step points at, or "".
func target() -> String:
	return GUIDE.INTRO[KEYS[_step]].target if KEYS.has(_step) else ""


## Whether the sockets glow: while the player is asked to tap one.
func highlights_sockets() -> bool:
	return _step == Step.PICK_SOCKET


## Whether the bubble offers Next: only where the player has nothing to do on the map.
func offers_next() -> bool:
	return _step == Step.GOAL or _step == Step.DONE


## Whether the bubble is the small one, to leave the map free while the player acts on it.
func compact() -> bool:
	return is_active() and _step != Step.GOAL and _step != Step.DONE


func _finish(skipped: bool) -> void:
	_step = Step.IDLE
	finished.emit(skipped)
