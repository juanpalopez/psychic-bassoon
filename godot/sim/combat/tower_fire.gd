## Towers shooting. Each tick, after the foes move, a tower whose cooldown has
## run out picks the foe nearest the Heartstone within its reach and fires; its
## cooldown then restarts at one over its rate (plus what the last tick ran
## over). The Spool Guard hits one foe, the Thimble Mortar everything within its
## splash of the target. The shot happens the tick it is fired (a renderer draws
## the flight from the TOWER_FIRED event). A beam tower (the Prism Spire) fires
## no shots: it locks a foe and hurts it a little every tick.
class_name TowerFire
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const RULES := preload("res://content/game_rules.gd")


## Runs every tower's turn.
static func step(game: GameState) -> void:
	for tower in game.towers:
		var def: Dictionary = TOWERS.DEFS[tower.type]
		if def.get("guards", false) or def.get("support", false):
			continue
		if def.get("beam", false):
			_beam(game, tower, def)
			continue
		var was_ready := tower.cooldown <= RULES.TIMER_EPSILON
		tower.cooldown -= Game.TICK_SECONDS
		if tower.cooldown > RULES.TIMER_EPSILON:
			continue
		var target := target_for(game, tower)
		if target == null:
			# an idle tower waits at 0, so it keeps no head start
			tower.cooldown = 0.0
			continue
		# the part of the last tick that ran past the cooldown carries over, so a
		# rate that does not divide the tick still averages out; a tower that was
		# already waiting has no such remainder
		var carried := 0.0 if was_ready else tower.cooldown
		tower.cooldown = carried + 1.0 / float(def.rate[tower.level])
		_fire(game, tower, def, target)


## How far the tower reaches, in cells: its level's range times the bonus of the
## elevation of its socket.
static func reach_of(game: GameState, tower: Tower) -> float:
	var base: float = TOWERS.DEFS[tower.type].range[tower.level]
	return base * game.map.range_multiplier(Vector2i(tower.col, tower.row))


## The foe the tower shoots: of the live foes in reach, the one with the least
## distance left to walk on its own route (routes differ in length, so the
## distance walked is not comparable); the foe that spawned first wins a tie. A support foe in
## reach (the Ink Shaman) is shot before any other.
static func target_for(game: GameState, tower: Tower) -> Foe:
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var best: Foe = null
	var best_left := 0.0
	for foe in foes_within(game, centre.x, centre.y, reach_of(game, tower)):
		var left := game.routes[foe.route].total - foe.distance
		var better := best == null or left < best_left
		if best != null and foe.support != best.support:
			better = foe.support
		if better:
			best = foe
			best_left = left
	return best


## The live foes whose centre is within `radius` of a point, in spawn order.
static func foes_within(game: GameState, x: float, y: float, radius: float) -> Array[Foe]:
	var found: Array[Foe] = []
	var limit := radius * radius
	for foe in game.foes:
		var dx := foe.x - x
		var dy := foe.y - y
		if foe.alive and dx * dx + dy * dy <= limit:
			found.append(foe)
	return found


## Lets go of every lock whose foe has fallen, so no tower keeps pointing at a
## foe that is about to leave the game. Run after all towers have fired.
static func release_fallen_locks(game: GameState) -> void:
	for tower in game.towers:
		if tower.target_id < 0:
			continue
		var held := false
		for foe in game.foes:
			if foe.id == tower.target_id and foe.alive:
				held = true
				break
		if not held:
			tower.target_id = -1


## A beam tower's turn: keep the locked foe while it lives and stays in reach,
## else lock the foe the tower would target, and hurt it a tick's share of the
## beam's damage per second. No event is emitted: render reads `target_id`.
static func _beam(game: GameState, tower: Tower, def: Dictionary) -> void:
	var target := _locked_foe(game, tower)
	if target == null:
		target = target_for(game, tower)
	tower.target_id = target.id if target != null else -1
	if target == null:
		return
	var per_second := float(def.damage[tower.level])
	var kind := Damage.kind_named(def.damage_type)
	Damage.apply_beam(game, target, per_second, kind, Game.TICK_SECONDS)


## The foe the tower is locked on, if it is still alive and within reach.
static func _locked_foe(game: GameState, tower: Tower) -> Foe:
	if tower.target_id < 0:
		return null
	var reach := reach_of(game, tower)
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	for foe in foes_within(game, centre.x, centre.y, reach):
		if foe.id == tower.target_id:
			return foe
	return null


static func _fire(game: GameState, tower: Tower, def: Dictionary, target: Foe) -> void:
	var splash := 0.0
	if def.has("splash"):
		splash = float(def.splash[tower.level])
	var event := GameEvent.of(GameEvent.Kind.TOWER_FIRED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.splash = splash
	game.events.append(event)
	var kind := Damage.kind_named(def.damage_type)
	var amount := float(def.damage[tower.level])
	if splash <= 0.0:
		Damage.apply(game, target, amount, kind)
		return
	# find who is in the blast before the first hit can change anything
	for foe in foes_within(game, target.x, target.y, splash):
		Damage.apply(game, foe, amount, kind)
