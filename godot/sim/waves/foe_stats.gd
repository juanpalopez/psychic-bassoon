## A foe's numbers when it spawns in a given wave: the base numbers, scaled up.
##
## Only `+ - * /`, `floor`, `min` and `max` are used, and a result is rounded
## with `int(floor(x + 0.5))`, so results are the same on every platform.
class_name FoeStats
extends RefCounted

const FOES := preload("res://content/foes.gd")
const WAVES := preload("res://content/waves.gd")

var hp: int = 0
var speed: float = 0.0
var reward: int = 0
var armor: int = 0


## The stats of foe `id` spawned in `wave`, or null for an unknown foe.
static func for_wave(id: String, wave: int) -> FoeStats:
	if not FOES.DEFS.has(id):
		push_error("unknown foe %s" % id)
		return null
	var base: Dictionary = FOES.DEFS[id]
	var n := float(wave - 1)
	var hp_scale: float = 1.0 + WAVES.HP_LINEAR * n + WAVES.HP_QUADRATIC * n * n
	var speed_bonus: float = minf(WAVES.SPEED_CAP, float(wave) * WAVES.SPEED_PER_WAVE)
	var stats := FoeStats.new()
	stats.hp = Rounding.half_up(float(base.hp) * hp_scale)
	stats.speed = float(base.speed) * (1.0 + speed_bonus)
	stats.reward = Rounding.half_up(float(base.reward) * (1.0 + WAVES.REWARD_PER_WAVE * n))
	stats.armor = int(base.armor) + int(floor(float(wave) / float(WAVES.ARMOR_EVERY_WAVES)))
	return stats
