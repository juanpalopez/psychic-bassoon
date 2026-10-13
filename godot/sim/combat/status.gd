## Statuses on a foe. Today only the slow, shared by every source of one (towers'
## specialisations, glue, rivers, spells): the strongest slow wins and a fresh one
## refreshes the timer. A foe walks `speed * (1 - slow)` while the timer runs.
class_name Status
extends RefCounted

const RULES := preload("res://content/game_rules.gd")


## Slows `foe` by `fraction` (0 to 1, more is clamped) for `seconds`. A slow that
## is not a positive share, or lasts no longer than the timer tolerance (the move
## loop would never clear it), is ignored. While a stronger slow is
## active a weaker one is ignored; an equal or stronger one replaces it and
## restarts the timer.
static func apply_slow(foe: Foe, fraction: float, seconds: float) -> void:
	# written so that NaN counts as no slow
	if not (fraction > 0.0 and seconds > RULES.TIMER_EPSILON):
		return
	var share := minf(fraction, 1.0)
	var active := foe.slow_timer > RULES.TIMER_EPSILON
	if active and share < foe.slow:
		return
	foe.slow = share
	foe.slow_timer = seconds
