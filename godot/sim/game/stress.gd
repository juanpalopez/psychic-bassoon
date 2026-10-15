## Keeps a fixed number of foes walking, for the phone check of 80 foes at 60 fps. It is not
## part of a game: a page parameter turns it on and the scene calls `top_up` before each tick.
## The foes are real ones made by the sim's own spawner, so the cost on screen is the real
## cost. It draws no random numbers and keeps the Heartstone alive, so a crowd is repeatable.
class_name Stress
extends RefCounted

const RULES := preload("res://content/game_rules.gd")
## The mix by foe id: mostly goblins, a share of orcs, now and then a golem.
const MIX: Array[String] = ["scrapGoblin", "scrapGoblin", "scrapGoblin", "corrugatedOrc"]
const GOLEM_EVERY := 25
const WAVE := 1


## Brings the number of living foes up to `target`. The first fill spreads them along the road;
## after that a foe that leaked is replaced at the spawn point, one a tick at most.
static func top_up(game: GameState, target: int) -> void:
	if target <= 0:
		return
	game.heartstone_health = maxi(game.heartstone_health, RULES.START_HEARTSTONE_HEALTH)
	var alive := 0
	for foe in game.foes:
		if foe.alive:
			alive += 1
	var missing := target - alive
	if missing <= 0:
		return
	var filling := alive == 0
	var route: Route = game.routes[0]
	var count := missing if filling else 1
	for i in count:
		var foe := FoeSpawner.spawn(game, _type_for(game.next_id), WAVE, 0)
		if filling:
			foe.distance = route.total * (float(i) + 0.5) / float(missing)
			var at := route.position_at(foe.distance)
			foe.x = at.x
			foe.y = at.y


static func _type_for(id: int) -> String:
	if id % GOLEM_EVERY == 0:
		return "cardboardGolem"
	return MIX[id % MIX.size()]
