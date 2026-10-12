## Lists the foes of a wave in spawn order, each with the pause before the next.
##
## It draws one float per rolled foe from the waves stream, in order, so the
## same seed always gives the same waves. The boss escort and the Golem are not
## rolled. A swarm wave (every 5th, unless it is a boss wave) is mostly goblins on
## tight gaps, with a few orcs by its own threshold; a boss wave (every 10th) opens
## with an orc and ends with the Golem;
## any other wave is goblins, with orcs from wave 4 by a rising chance.
class_name WaveBuilder
extends RefCounted

const WAVES := preload("res://content/waves.gd")


## The number of foes in a wave (not counting the boss escort and the boss).
static func count_for(wave: int) -> int:
	var count: float = WAVES.BASE_COUNT + float(wave) * WAVES.COUNT_PER_WAVE
	if is_swarm(wave):
		count *= WAVES.SWARM_COUNT_MULTIPLIER
	return Rounding.half_up(count)


## A goblin swarm wave: every `SWARM_EVERY`th wave, unless it is a boss wave.
static func is_swarm(wave: int) -> bool:
	return wave % WAVES.SWARM_EVERY == 0 and wave % WAVES.BOSS_EVERY != 0


## Draws one float per foe from the waves stream and lists the wave.
static func build(wave: int, rng: Rng) -> Array[SpawnOrder]:
	var rolls: Array[float] = []
	for i in count_for(wave):
		rolls.append(rng.next_float())
	return compose(wave, rolls)


## Lists a wave from the rolls of its foes (`count_for(wave)` of them, one per
## foe, each from 0 up to 1): a roll above the orc threshold makes a heavy foe in
## a normal wave from `ORC_FROM_WAVE` on; swarm waves ignore the rolls.
static func compose(wave: int, rolls: Array[float]) -> Array[SpawnOrder]:
	var boss := wave % WAVES.BOSS_EVERY == 0
	var swarm := is_swarm(wave)
	var gap := maxf(WAVES.GAP_MIN, WAVES.GAP_BASE - float(wave) * WAVES.GAP_PER_WAVE)
	var orc_threshold: float = (
		WAVES.ORC_BASE_THRESHOLD
		- minf(WAVES.ORC_THRESHOLD_CAP, float(wave) * WAVES.ORC_THRESHOLD_PER_WAVE)
	)
	if swarm:
		orc_threshold = WAVES.SWARM_ORC_THRESHOLD
	var orders: Array[SpawnOrder] = []
	for roll in rolls:
		var type: String = WAVES.FILLER_FOE
		if wave >= WAVES.ORC_FROM_WAVE and roll > orc_threshold:
			type = WAVES.HEAVY_FOE
		var multiplier: float = WAVES.GAP_ORC
		if type == WAVES.FILLER_FOE:
			multiplier = WAVES.GAP_GOBLIN_SWARM if swarm else WAVES.GAP_GOBLIN
		orders.append(SpawnOrder.of(type, gap * multiplier))
	if boss:
		orders.append(SpawnOrder.of(WAVES.BOSS_FOE, WAVES.GOLEM_GAP))
		orders.push_front(SpawnOrder.of(WAVES.HEAVY_FOE, gap * WAVES.GAP_BOSS_ESCORT))
	return orders
