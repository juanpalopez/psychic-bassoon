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


## Opens a squadron over the tower's reach. The planes patrol there and bomb on a clock.
static func open_squadron(game: GameState, tower: Tower, active: Dictionary) -> void:
	var zone := Zone.new()
	zone.id = game.next_id
	game.next_id += 1
	zone.kind = "squadron"
	zone.tower_id = tower.id
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	zone.x = centre.x
	zone.y = centre.y
	zone.radius = TowerFire.reach_of(game, tower)
	zone.planes = int(active.planes)
	zone.damage = float(active.damage)
	zone.splash = float(active.splash)
	zone.every = float(active.every)
	zone.clock = zone.every
	zone.timer = float(active.seconds)
	game.zones.append(zone)
	game.events.append(_announce(GameEvent.Kind.ZONE_OPENED, zone))


static func step(game: GameState) -> void:
	if game.zones.is_empty():
		return
	var open: Array[Zone] = []
	for zone in game.zones:
		match zone.kind:
			"pool":
				_soak(game, zone)
			"squadron":
				_patrol(game, zone)
			_:
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


## A squadron drops its bombs when its clock runs out: plane `i` bombs the `i`th foe in the patrol,
## the one furthest along its road first (the planes share the foes round when there are fewer).
static func _patrol(game: GameState, zone: Zone) -> void:
	zone.clock -= Game.TICK_SECONDS
	if zone.clock > RULES.TIMER_EPSILON:
		return
	zone.clock += zone.every
	var foes: Array[Foe] = []
	var left: Array[float] = []
	for foe in TowerFire.foes_within(game, zone.x, zone.y, zone.radius):
		var route := (game.air_routes if foe.flying else game.routes)[foe.route]
		var remaining := route.total - foe.distance
		var at := foes.size()
		while at > 0 and left[at - 1] > remaining:
			at -= 1
		foes.insert(at, foe)
		left.insert(at, remaining)
	if foes.is_empty():
		return
	for plane in zone.planes:
		# a plane whose foe an earlier bomb of this drop killed takes the next one standing
		for step in foes.size():
			var target := foes[(plane + step) % foes.size()]
			if target.alive:
				_bomb(game, zone, target)
				break


static func _bomb(game: GameState, zone: Zone, target: Foe) -> void:
	var event := GameEvent.of(GameEvent.Kind.TOWER_FIRED)
	event.tower_id = zone.tower_id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.splash = zone.splash
	game.events.append(event)
	for foe in TowerFire.foes_within(game, target.x, target.y, zone.splash):
		var bonus := Specs.damage_bonus(game, foe, Damage.Kind.PHYSICAL)
		Damage.apply(game, foe, zone.damage, Damage.Kind.PHYSICAL, 0.0, bonus)
