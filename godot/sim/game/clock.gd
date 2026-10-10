## Turns real elapsed time into a number of simulation ticks to run this frame.
##
## Game speed multiplies the tick count; the tick itself stays fixed. A long
## frame is clamped so a stalled tab cannot trigger a burst of ticks. Ported
## from `src/sim/game/clock.ts`.
class_name Clock
extends RefCounted

const RULES := preload("res://content/game_rules.gd")

## Real time carried between frames, in seconds.
var accumulator: float = 0.0


## Ticks to run for `elapsed_seconds` of real time at `speed` (1 to
## `MAX_GAME_SPEED`). An invalid speed is reported and runs nothing; a
## negative or non-finite elapsed time runs nothing.
func advance(elapsed_seconds: float, speed: int) -> int:
	if speed < 1 or speed > RULES.MAX_GAME_SPEED:
		push_error("game speed must be 1 to %d" % RULES.MAX_GAME_SPEED)
		return 0
	if not (elapsed_seconds > 0.0) or is_inf(elapsed_seconds):
		return 0
	accumulator += minf(elapsed_seconds, RULES.MAX_FRAME_SECONDS)
	var ticks := int(floor(accumulator / Game.TICK_SECONDS))
	accumulator = maxf(0.0, accumulator - float(ticks) * Game.TICK_SECONDS)
	return ticks * speed
