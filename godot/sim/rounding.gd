## Rounding that gives the same answer on every platform: half up, using only
## `floor`. (The engine's `round` is avoided in the sim; see CLAUDE.md.)
class_name Rounding
extends RefCounted


## `x` rounded to the nearest integer, halves going up: `int(floor(x + 0.5))`.
static func half_up(value: float) -> int:
	return int(floor(value + 0.5))
