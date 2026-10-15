## The stats line of a tower in the guide, for its first level, read from the content.
class_name GuideText
extends RefCounted


static func stats(def: Dictionary) -> String:
	var cost: int = def.cost[0]
	var reach: float = def.range[0]
	if def.get("support", false):
		return (
			"Cost %d  Guards +%d%% speed, +%d hp/s  Reach %s"
			% [
				cost,
				int(round(def.guard_speed_bonus[0] * 100.0)),
				int(round(def.guard_regen_bonus[0])),
				reach
			]
		)
	if def.get("guards", false):
		return (
			"Cost %d  Guards %d hp, blow %d  Reach %s"
			% [cost, def.guard_hp[0], def.guard_damage[0], reach]
		)
	if def.get("beam", false):
		return "Cost %d  Damage %d/s  Range %s" % [cost, def.damage[0], reach]
	var line := (
		"Cost %d  Damage %d  Range %s  Rate %s/s" % [cost, def.damage[0], reach, def.rate[0]]
	)
	if def.has("splash"):
		line += "  Blast %s" % def.splash[0]
	return line
