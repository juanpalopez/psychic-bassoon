## Runs the zones abilities opened. An Ink Vortex pulls each foe inside its radius, on the
## zone's route, towards the zone's centre along that route, at a fixed pace. A heavy foe,
## a foe a guard holds and a flying foe are not pulled. The zone ends when its time runs out.
class_name Zones
extends RefCounted

const RULES := preload("res://content/game_rules.gd")


## Opens a vortex at a foe's place. The caller fills the numbers from the spec.
static func open_vortex(
	game: GameState, tower: Tower, centre: Foe, radius: float, pull: float, seconds: float
) -> void:
	var zone := Zone.new()
	zone.id = game.next_id
	game.next_id += 1
	zone.kind = "ink_vortex"
	zone.tower_id = tower.id
	zone.x = centre.x
	zone.y = centre.y
	zone.route = centre.route
	zone.distance = centre.distance
	zone.radius = radius
	zone.pull = pull
	zone.timer = seconds
	game.zones.append(zone)
	var event := GameEvent.of(GameEvent.Kind.ZONE_OPENED)
	event.tower_id = tower.id
	event.x = zone.x
	event.y = zone.y
	event.splash = radius
	game.events.append(event)


static func step(game: GameState) -> void:
	if game.zones.is_empty():
		return
	var open: Array[Zone] = []
	for zone in game.zones:
		_pull(game, zone)
		zone.timer -= Game.TICK_SECONDS
		if zone.timer <= RULES.TIMER_EPSILON:
			var event := GameEvent.of(GameEvent.Kind.ZONE_CLOSED)
			event.tower_id = zone.tower_id
			event.x = zone.x
			event.y = zone.y
			game.events.append(event)
		else:
			open.append(zone)
	game.zones = open


static func _pull(game: GameState, zone: Zone) -> void:
	var step_length := zone.pull * Game.TICK_SECONDS
	var limit := zone.radius * zone.radius
	for foe in game.foes:
		if not foe.alive or foe.heavy or foe.flying or foe.engaged_guard_id != -1:
			continue
		if foe.route != zone.route:
			continue
		var dx := foe.x - zone.x
		var dy := foe.y - zone.y
		if dx * dx + dy * dy > limit:
			continue
		var gap := zone.distance - foe.distance
		foe.distance += clampf(gap, -step_length, step_length)
