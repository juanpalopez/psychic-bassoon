## Numbers about a built tower, read from the content and the map so the panel
## and the ring agree with the sim.
class_name TowerInfo
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const RULES := preload("res://content/game_rules.gd")


## How far the tower reaches a foe on the road, in cells: its level's range times the bonus of
## its cell's elevation, plus half the map's reach band (0 without one; #446), as the sim measures.
static func effective_range(map: GameMap, tower: Tower) -> float:
	var base: float = TOWERS.DEFS[tower.type].range[tower.level]
	return base * map.range_multiplier(Vector2i(tower.col, tower.row)) + map.reach_margin()


## Buttons the next upgrade costs, or -1 at the top level.
static func next_cost(tower: Tower) -> int:
	var costs: Array = TOWERS.DEFS[tower.type].cost
	if tower.level + 1 >= costs.size():
		return -1
	return costs[tower.level + 1]


## Buttons a sale gives back (the same rounding as the sim).
static func refund(tower: Tower) -> int:
	return int(floor(float(tower.invested) * RULES.SELL_REFUND))
