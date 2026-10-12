## What a foe leaves behind when it is destroyed. Only the Cardboard Golem splits:
## into `split_count` Scrap Goblins on its own route, `split_spacing` cells apart
## along it, the first where the Golem fell and the others behind it (a Golem that
## falls within `split_spacing` cells of the start stacks the extra ones on the
## spawn point), with the strength of the Golem's wave. They do not inherit its slow. The route is the Golem's (no random draw), the goblins
## are announced like any spawn, and nothing splits when a foe leaks.
class_name Splitting
extends RefCounted

const FOES := preload("res://content/foes.gd")


## Spawns the children of a foe that was destroyed (not one that leaked).
static func spawn_children(game: GameState, foe: Foe) -> void:
	var def: Dictionary = FOES.DEFS[foe.type]
	if not def.has("splits_into"):
		return
	var spacing := float(def.split_spacing)
	for i in int(def.split_count):
		var child := FoeSpawner.spawn(game, def.splits_into, foe.wave, foe.route)
		if child == null:
			continue
		child.distance = maxf(0.0, foe.distance - float(i) * spacing)
		var at := game.routes[foe.route].position_at(child.distance)
		child.x = at.x
		child.y = at.y
