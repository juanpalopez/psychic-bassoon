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
	var to := Vector2i(command.col, command.row)
	if not game.hero_graph.is_open(to):
		return Game.reject(game, command, GameEvent.RejectReason.NOT_WALKABLE)
	var cells := game.hero_graph.path(game.hero.cell, to)
	if cells.is_empty():
		return Game.reject(game, command, GameEvent.RejectReason.UNREACHABLE)
	# the walk starts at the cell it last stood in, so a hero between two cells goes back to it
	game.hero.path = cells
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


## The last cell of the main road the hero can stand on: where the road meets the Heartstone.
static func _home(game: GameState) -> Vector2i:
	var road := game.map.path
	for index in range(road.size() - 1, -1, -1):
		if game.hero_graph.is_open(road[index]):
			return road[index]
	return road[road.size() - 1]
