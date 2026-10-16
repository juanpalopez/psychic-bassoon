## Runs the zones abilities opened. An Ink Vortex pulls each foe inside its radius, on the main
## road (either spawn source), towards the zone's centre along the road, at a fixed pace. A
## heavy foe,
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
	# where it sits along the main road, so foes of either spawn source are pulled the same way
	zone.distance = Barracks.main_distance(game, centre)
	zone.radius = radius
	zone.pull = pull
	zone.timer = seconds
	game.zones.append(zone)
	game.events.append(_announce(GameEvent.Kind.ZONE_OPENED, zone))


## Opens a pool where a shell landed: ground foes inside it are slowed while it lasts.
static func open_pool(
	game: GameState, tower: Tower, at: Foe, radius: float, slow: float, seconds: float
) -> void:
	var zone := Zone.new()
	zone.id = game.next_id
	game.next_id += 1
	zone.kind = "pool"
	zone.tower_id = tower.id
	zone.x = at.x
	zone.y = at.y
	zone.route = at.route
	zone.distance = at.distance
	zone.radius = radius
	zone.slow = slow
	zone.timer = seconds
	game.zones.append(zone)
	game.events.append(_announce(GameEvent.Kind.ZONE_OPENED, zone))


static func _announce(kind: GameEvent.Kind, zone: Zone) -> GameEvent:
	var event := GameEvent.of(kind)
	event.tower_id = zone.tower_id
	event.zone_id = zone.id
	event.zone_kind = zone.kind
	event.x = zone.x
	event.y = zone.y
	event.splash = zone.radius
	return event


static func step(game: GameState) -> void:
	if game.zones.is_empty():
		return
	var open: Array[Zone] = []
	for zone in game.zones:
		if zone.kind == "pool":
			_soak(game, zone)
		else:
			_pull(game, zone)
		zone.timer -= Game.TICK_SECONDS
		if zone.timer <= RULES.TIMER_EPSILON:
			game.events.append(_announce(GameEvent.Kind.ZONE_CLOSED, zone))
		else:
			open.append(zone)
	game.zones = open


static func _pull(game: GameState, zone: Zone) -> void:
	var step_length := zone.pull * Game.TICK_SECONDS
	var limit := zone.radius * zone.radius
	for foe in game.foes:
		if not foe.alive or foe.heavy or foe.flying or foe.engaged_guard_id != -1:
			continue
		var along := Barracks.main_distance(game, foe)
		if along < 0.0:
			continue
		var dx := foe.x - zone.x
		var dy := foe.y - zone.y
		if dx * dx + dy * dy > limit:
			continue
		var gap := zone.distance - along
		foe.distance += clampf(gap, -step_length, step_length)


## A pool slows each ground foe inside it; the slow is short (`POOL_REFRESH_SECONDS`) and
## renewed each tick, so it lingers about that long after the foe leaves or the pool closes.
static func _soak(game: GameState, zone: Zone) -> void:
	var limit := zone.radius * zone.radius
	for foe in game.foes:
		if not foe.alive or foe.flying:
			continue
		var dx := foe.x - zone.x
		var dy := foe.y - zone.y
		if dx * dx + dy * dy <= limit:
			# a longer, equal or stronger slow already on the foe is left alone
			if foe.slow >= zone.slow and foe.slow_timer > RULES.POOL_REFRESH_SECONDS:
				continue
			Status.apply_slow(foe, zone.slow, RULES.POOL_REFRESH_SECONDS)
