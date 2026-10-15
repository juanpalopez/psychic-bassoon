## Statuses on a foe. Today the slow and the bleed, shared by every source of one (towers'
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


## Makes `foe` bleed `dps` true damage a second for `seconds`. As with a slow, a
## weaker bleed does not replace a stronger one still running; an equal or stronger
## one replaces it and restarts the timer. No positive share or time is no bleed.
static func apply_bleed(foe: Foe, dps: float, seconds: float) -> void:
	# written so that NaN counts as no bleed
	if not (dps > 0.0 and seconds > RULES.TIMER_EPSILON):
		return
	var active := foe.bleed_timer > RULES.TIMER_EPSILON
	if active and dps < foe.bleed_dps:
		return
	foe.bleed_dps = dps
	foe.bleed_timer = seconds


## A tick of every bleed: true damage for the tick, then the timer runs down.
## The bleed ends with its last bleeding step, not a tick later.
static func step_bleed(game: GameState) -> void:
	for foe in game.foes:
		if not foe.alive or foe.bleed_timer <= RULES.TIMER_EPSILON:
			continue
		Damage.apply(game, foe, foe.bleed_dps * Game.TICK_SECONDS, Damage.Kind.TRUE)
		foe.bleed_timer -= Game.TICK_SECONDS
		if foe.bleed_timer <= RULES.TIMER_EPSILON:
			foe.bleed_dps = 0.0
			foe.bleed_timer = 0.0
