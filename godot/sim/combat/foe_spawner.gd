## Puts a foe on the spawn point with the strength of its wave.
class_name FoeSpawner
extends RefCounted

const FOES := preload("res://content/foes.gd")


## Spawns a foe of `type` for `wave`. With several routes the route stream picks
## one (one draw per foe); with one route nothing is drawn. Pass `route` to
## choose the route yourself. Returns null for an unknown foe.
static func spawn(game: GameState, type: String, wave: int, route: int = -1) -> Foe:
	var stats := FoeStats.for_wave(type, wave)
	if stats == null:
		return null
	var base: Dictionary = FOES.DEFS[type]
	var lane := route
	if lane < 0:
		lane = game.route_rng.next_int(game.routes.size()) if game.routes.size() > 1 else 0
	var foe := Foe.new()
	foe.id = game.next_id
	game.next_id += 1
	foe.type = type
	foe.wave = wave
	foe.hp = float(stats.hp)
	foe.max_hp = float(stats.hp)
	foe.speed = stats.speed
	foe.reward = stats.reward
	foe.armor = stats.armor
	foe.resist = int(base.resist)
	foe.radius = float(base.radius)
	foe.leak = int(base.leak)
	foe.attack_damage = stats.attack_damage
	foe.attack_interval = float(base.attack_interval)
	foe.blockable = bool(base.blockable)
	foe.support = bool(base.get("support", false))
	foe.aura_radius = float(base.get("aura_radius", 0.0))
	foe.aura_heal = float(base.get("aura_heal", 0.0))
	foe.aura_speed = float(base.get("aura_speed", 0.0))
	foe.route = lane
	var start := game.routes[lane].position_at(0.0)
	foe.x = start.x
	foe.y = start.y
	game.foes.append(foe)
	var event := GameEvent.of(GameEvent.Kind.FOE_SPAWNED)
	event.foe_id = foe.id
	event.foe_type = type
	event.wave = wave
	game.events.append(event)
	return foe
