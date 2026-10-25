## Which foes get an edge arrow: the ones about to reach the Heartstone.
class_name ArrowTargets
extends RefCounted


## Fills `into` with the living foes within `limit` cells of the Heartstone along their route (a
## flier along its straight line), nearest first, at most `count`. `left` is scratch space, so
## a caller that keeps both arrays allocates nothing per call.
static func foes_near_heartstone(
	game: GameState, limit: float, count: int, into: Array[Foe], left: PackedFloat64Array
) -> void:
	into.clear()
	left.resize(0)
	for foe in game.foes:
		var routes := game.air_routes if foe.flying else game.routes
		if not foe.alive or foe.route < 0 or foe.route >= routes.size():
			continue
		var remaining := routes[foe.route].total - foe.distance
		if remaining > limit:
			continue
		var at := into.size()
		while at > 0 and left[at - 1] > remaining:
			at -= 1
		if at >= count:
			continue
		into.insert(at, foe)
		left.insert(at, remaining)
		if into.size() > count:
			into.resize(count)
			left.resize(count)
