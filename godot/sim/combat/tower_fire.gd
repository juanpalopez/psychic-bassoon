## Towers shooting. Each tick, after the foes move, a tower whose cooldown has
## run out picks the foe nearest the kingdom within its reach and fires; its
## cooldown then restarts at one over its rate. The Spool Guard hits one foe, the
## Thimble Mortar everything within its splash of the target. The shot happens
## the tick it is fired (a renderer draws the flight from the TOWER_FIRED
## event). A beam tower (the Prism Spire) fires no shots; its beam comes later.
class_name TowerFire
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const MAP_RULES := preload("res://content/map_rules.gd")


## Runs every tower's turn.
static func step(game: GameState) -> void:
	for tower in game.towers:
		var def: Dictionary = TOWERS.DEFS[tower.type]
		if def.get("beam", false):
			continue
		tower.cooldown -= Game.TICK_SECONDS
		if tower.cooldown > 0.0:
			continue
		var target := target_for(game, tower)
		if target == null:
			continue
		tower.cooldown = 1.0 / float(def.rate[tower.level])
		_fire(game, tower, def, target)


## How far the tower reaches, in cells: its level's range times the bonus of the
## elevation of its socket.
static func reach_of(game: GameState, tower: Tower) -> float:
	var base: float = TOWERS.DEFS[tower.type].range[tower.level]
	return base * game.map.range_multiplier(Vector2i(tower.col, tower.row))


## The foe the tower shoots: of the live foes in reach, the one with the least
## distance left to walk on its own route (routes differ in length, so the
## distance walked is not comparable); the foe that spawned first wins a tie.
static func target_for(game: GameState, tower: Tower) -> Foe:
	var centre_x := float(tower.col) + MAP_RULES.CELL_CENTRE
	var centre_y := float(tower.row) + MAP_RULES.CELL_CENTRE
	var best: Foe = null
	var best_left := 0.0
	for foe in foes_within(game, centre_x, centre_y, reach_of(game, tower)):
		var left := game.routes[foe.route].total - foe.distance
		if best == null or left < best_left:
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
