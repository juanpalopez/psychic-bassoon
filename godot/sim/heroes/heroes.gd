## The hero context (#275): placing the hero and walking it along its cell path. Orders arrive
## as `MOVE_HERO` commands; the walk runs once a tick.
class_name Heroes
extends RefCounted

const HEROES := preload("res://content/heroes.gd")
const HALF := 0.5


## Places a hero of `type` at the Heartstone and builds the walkable graph it paths on. The game
## board does this in `Game.create`; a mechanic test calls it when it needs the hero.
static func place(game: GameState, type: String) -> void:
	game.hero_graph = HeroGraph.from_map(game.map)
	var def: Dictionary = HEROES.DEFS[type]
	var hero := Hero.new()
	hero.type = type
	hero.id = game.next_id
	game.next_id += 1
	hero.armor = def.armor
	hero.damage = def.damage
	hero.interval = def.interval
	hero.radius = def.radius
	hero.max_hp = def.hp
	hero.hp = hero.max_hp
	hero.speed = def.speed
	hero.cell = _home(game)
	hero.x = float(hero.cell.x) + HALF
	hero.y = float(hero.cell.y) + HALF
	game.hero = hero


## Sends the hero to a cell. Rejected when there is no hero, the cell is not ground it can stand
## on, or it cannot get there; a new order replaces the walk it is on.
static func order(game: GameState, command: Command) -> void:
	if game.hero == null:
		return Game.reject(game, command, GameEvent.RejectReason.NO_HERO)
	if not game.hero.alive:
		return Game.reject(game, command, GameEvent.RejectReason.HERO_FALLEN)
	var to := Vector2i(command.col, command.row)
	if not game.hero_graph.is_open(to):
		return Game.reject(game, command, GameEvent.RejectReason.NOT_WALKABLE)
	var cells := game.hero_graph.path(game.hero.cell, to)
	if cells.is_empty():
		return Game.reject(game, command, GameEvent.RejectReason.UNREACHABLE)
	# the walk starts at the cell it last stood in; a hero between two cells goes back to it only
	# when the new walk turns away, else it carries on to the cell ahead (a repeated order would
	# otherwise pull it back every time)
	var ahead := game.hero.path
	if not ahead.is_empty() and ahead[0] != game.hero.cell and cells.size() > 1:
		if cells[1] == ahead[0]:
			cells.remove_at(0)
	game.hero.path = cells
	# a new move lets go of the held foe; it keeps striking while it stays in reach
	var held := Melee.held_foe(game, game.hero)
	if held != null:
		Melee.release(held, game.hero)
		game.hero.chaser_id = held.id
	var event := GameEvent.of(GameEvent.Kind.HERO_ORDERED)
	event.x = float(to.x) + HALF
	event.y = float(to.y) + HALF
	game.events.append(event)


## Walks the hero one tick along its path, from cell centre to cell centre.
static func step(game: GameState) -> void:
	var hero := game.hero
	if hero == null or hero.path.is_empty():
		return
	var budget := hero.speed * Game.TICK_SECONDS
	while not hero.path.is_empty():
		var next := hero.path[0]
		var to_x := float(next.x) + HALF
		var to_y := float(next.y) + HALF
		# every leg runs along a row or a column, so this is its length
		var gap := absf(to_x - hero.x) + absf(to_y - hero.y)
		if gap > budget:
			hero.x += (to_x - hero.x) * (budget / gap)
			hero.y += (to_y - hero.y) * (budget / gap)
			return
		budget -= gap
		hero.x = to_x
		hero.y = to_y
		hero.cell = next
		hero.path.remove_at(0)
	var event := GameEvent.of(GameEvent.Kind.HERO_ARRIVED)
	event.x = hero.x
	event.y = hero.y
	game.events.append(event)


## One tick of the hero's fighting, after the foes have walked: a fallen hero waits to return;
## a standing one takes the nearest free foe in reach and trades blows with it; a foe it broke off
## from keeps striking while the hero stays in its reach.
static func fight(game: GameState) -> void:
	var hero := game.hero
	if hero == null:
		return
	if not hero.alive:
		_wait_to_return(game, hero)
		return
	var struck_by := _chase(game, hero)
	if hero.hp <= 0.0:
		_fall(game, hero)
		return
	var held := Melee.held_foe(game, hero)
	if held == null:
		hero.foe_id = -1
		if hero.path.is_empty():
			held = _take_a_foe(game, hero)
	if held != null:
		Melee.strike(game, hero, held, 0.0)
		# a chaser taken back already struck this tick; holding it resets its cooldown
		if held.id != struck_by:
			_take_a_blow(hero, held)
		if not held.alive:
			Melee.release(held, hero)
	if hero.hp <= 0.0:
		_fall(game, hero)


static func _fall(game: GameState, hero: Hero) -> void:
	Melee.fall(hero, Melee.held_foe(game, hero), float(HEROES.DEFS[hero.type].respawn))
	hero.path = [] as Array[Vector2i]
	hero.chaser_id = -1
	game.events.append(GameEvent.of(GameEvent.Kind.HERO_FELL))


## Returns the id of the chaser that struck this tick, or -1.
static func _chase(game: GameState, hero: Hero) -> int:
	if hero.chaser_id == -1:
		return -1
	var chaser: Foe = null
	for foe in game.foes:
		if foe.id == hero.chaser_id and foe.alive and _in_reach(game, hero, foe):
			if foe.engaged_guard_id != -1:
				break
			chaser = foe
	if chaser == null:
		hero.chaser_id = -1
		return -1
	_take_a_blow(hero, chaser)
	return chaser.id


static func _take_a_blow(hero: Hero, foe: Foe) -> void:
	if Melee.foe_strikes(foe) and not Melee.blind_miss(foe):
		hero.hp -= Melee.blow(foe, float(hero.armor))


static func _take_a_foe(game: GameState, hero: Hero) -> Foe:
	var best: Foe = null
	var best_gap := INF
	for foe in game.foes:
		if not foe.alive or not foe.blockable or foe.flying or foe.engaged_guard_id != -1:
			continue
		if not _in_reach(game, hero, foe):
			continue
		var gap := _gap(hero, foe)
		if gap < best_gap or (gap == best_gap and foe.id < best.id):
			best = foe
			best_gap = gap
	if best == null:
		return null
	Melee.hold(hero, best)
	var event := GameEvent.of(GameEvent.Kind.HERO_ENGAGED)
	event.foe_id = best.id
	event.foe_type = best.type
	game.events.append(event)
	return best


static func _gap(hero: Hero, foe: Foe) -> float:
	var dx := foe.x - hero.x
	var dy := foe.y - hero.y
	return sqrt(dx * dx + dy * dy)


## Measured to the road band's edge like a tower's (#446): a foe walks the centre line, so the
## hero standing anywhere on the band reaches it. One line, easy to revert if the owner says no.
static func _in_reach(game: GameState, hero: Hero, foe: Foe) -> bool:
	return _gap(hero, foe) <= hero.radius + foe.radius + HEROES.REACH + game.map.reach_margin()


static func _wait_to_return(game: GameState, hero: Hero) -> void:
	if not Melee.wait_to_return(hero):
		return
	hero.cell = _home(game)
	hero.x = float(hero.cell.x) + HALF
	hero.y = float(hero.cell.y) + HALF
	game.events.append(GameEvent.of(GameEvent.Kind.HERO_ROSE))


## The last cell of the main road the hero can stand on: where the road meets the Heartstone.
static func _home(game: GameState) -> Vector2i:
	var road := game.map.path
	for index in range(road.size() - 1, -1, -1):
		if game.hero_graph.is_open(road[index]):
			return road[index]
	return road[road.size() - 1]
