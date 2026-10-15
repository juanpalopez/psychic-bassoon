## The Ink Shaman's aura, applied at the start of each tick before the foes walk: every other
## foe within a shaman's radius heals a share of its max health a second and walks faster by
## the strongest aura over it (auras do not add up). The shaman does not buff itself.
class_name ShamanAura
extends RefCounted


static func step(game: GameState) -> void:
	var shamans: Array[Foe] = []
	for foe in game.foes:
		foe.speed_buff = 0.0
		if foe.alive and foe.support:
			shamans.append(foe)
	if shamans.is_empty():
		return
	for foe in game.foes:
		if not foe.alive:
			continue
		for shaman in shamans:
			if shaman == foe:
				continue
			var dx := foe.x - shaman.x
			var dy := foe.y - shaman.y
			if dx * dx + dy * dy > shaman.aura_radius * shaman.aura_radius:
				continue
			foe.speed_buff = maxf(foe.speed_buff, shaman.aura_speed)
			foe.hp = minf(foe.max_hp, foe.hp + foe.max_hp * shaman.aura_heal * Game.TICK_SECONDS)
