## The speed the player picked: one of the offered speeds, or paused. It only
## says how many ticks to run per frame (0 when paused); a tick never grows.
class_name GameSpeed
extends RefCounted

const SPEEDS: Array[int] = [1, 2, 3]

var speed := SPEEDS[0]
var paused := false


## Picks one of `SPEEDS` and resumes; any other value is ignored.
func choose(value: int) -> void:
	if not SPEEDS.has(value):
		return
	speed = value
	paused = false


func toggle_pause() -> void:
	paused = not paused


## The speed to hand to `Frame.step`, or 0 when no tick should run.
func ticks_speed() -> int:
	return 0 if paused else speed
