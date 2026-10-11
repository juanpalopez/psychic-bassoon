## Lists the foes of a wave in spawn order, each with the pause before the next.
##
## It draws one float per rolled foe from the waves stream, in order, so the
## same seed always gives the same waves. The boss escort and the Golem are not
## rolled. A swarm wave (every 5th, unless it is a boss wave) is all goblins on
## tight gaps; a boss wave (every 10th) opens with an orc and ends with the Golem;
## any other wave is goblins, with orcs from wave 4 by a rising chance.
class_name WaveBuilder
extends RefCounted

const WAVES := preload("res://content/waves.gd")


static func build(wave: int, rng: Rng) -> Array[SpawnOrder]:
	var boss := wave % WAVES.BOSS_EVERY == 0
	var swarm := wave % WAVES.SWARM_EVERY == 0 and not boss
	var count := int(floor(WAVES.BASE_COUNT + float(wave) * WAVES.COUNT_PER_WAVE + 0.5))
	var gap := maxf(WAVES.GAP_MIN, WAVES.GAP_BASE - float(wave) * WAVES.GAP_PER_WAVE)
	var orc_threshold: float = (
		WAVES.ORC_BASE_THRESHOLD
		- minf(WAVES.ORC_THRESHOLD_CAP, float(wave) * WAVES.ORC_THRESHOLD_PER_WAVE)
	)
	var orders: Array[SpawnOrder] = []
	for i in count:
		var roll := rng.next_float()
		var type := "scrapGoblin"
		if not swarm and wave >= WAVES.ORC_FROM_WAVE and roll > orc_threshold:
			type = "corrugatedOrc"
		var multiplier: float = WAVES.GAP_ORC
		if type == "scrapGoblin":
			multiplier = WAVES.GAP_GOBLIN_SWARM if swarm else WAVES.GAP_GOBLIN
		orders.append(SpawnOrder.of(type, gap * multiplier))
	if boss:
		orders.append(SpawnOrder.of("cardboardGolem", WAVES.GOLEM_GAP))
		orders.push_front(SpawnOrder.of("corrugatedOrc", gap * WAVES.GAP_BOSS_ESCORT))
	return orders
