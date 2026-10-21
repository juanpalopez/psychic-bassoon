## Shared setup for the tower fire tests.
class_name TowerFireKit
extends RefCounted

const MAP_RULES := preload("res://content/map_rules.gd")


## A game with one tower of `type` built (cooldown 0) on the level-0 socket
## nearest the road (the part of the road from `after` on), and a way to put a foe on the road
## in its reach.
class Scene:
	extends RefCounted
	var game: GameState
	var tower: Tower
	var near: float = 0.0
	var gap: float = 0.0
	## The second tower of `pair`.
	var second: Tower


static func scene(
	type: String = "spoolGuard",
	map_seed: int = 1,
	at_end: bool = false,
	existing: GameState = null,
	after: float = 0.0
) -> Scene:
	var scene := Scene.new()
	scene.game = existing if existing != null else Game.create(map_seed)
	var route := scene.game.routes[0]
	var best_socket := Vector2i(-1, -1)
	scene.gap = INF
	var end := route.position_at(route.total)
	for socket in scene.game.map.sockets:
		if scene.game.map.elevation_at(socket) != 0:
			continue
		var centre := scene.game.map.socket_centre(socket)
		if at_end:
			var to_end := centre.distance_to(Vector2(end.x, end.y))
			if to_end < scene.gap:
				scene.gap = to_end
				scene.near = route.total
				best_socket = socket
			continue
		var along := after
		while along <= route.total:
			var point := route.position_at(along)
			var gap := centre.distance_to(Vector2(point.x, point.y))
			if gap < scene.gap:
				scene.gap = gap
				scene.near = along
				best_socket = socket
			along += 0.05
	Game.submit(scene.game, Command.build(type, best_socket.x, best_socket.y))
	Game.tick(scene.game)
	scene.tower = scene.game.towers[0]
	# the build tick already let the tower look for a target: nothing was there
	scene.tower.cooldown = 0.0
	return scene


## A game on the 16 by 11 board (the game board until #320), for a test whose numbers or
## placement were chosen on that board's map of `map_seed` and that is about a mechanic, not
## the board.
static func landscape(map_seed: int = 1) -> GameState:
	return Game.create(map_seed, MAP_RULES.LANDSCAPE_COLS, MAP_RULES.LANDSCAPE_ROWS)


## A foe standing still on route 0 at `along`, `type` of wave 1.
static func foe(game: GameState, along: float, type: String = "scrapGoblin", route: int = 0) -> Foe:
	var foe := FoeSpawner.spawn(game, type, 1, route)
	foe.speed = 0.0
	foe.distance = along
	var point := game.routes[route].position_at(along)
	foe.x = point.x
	foe.y = point.y
	return foe


static func kinds(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in game.events:
		if event.kind == kind:
			found.append(event)
	return found


static func shot_ticks(scene: Scene, foe: Foe, ticks: int) -> Array[int]:
	var at: Array[int] = []
	for i in ticks:
		var before := foe.hp
		Game.tick(scene.game)
		if foe.hp < before:
			at.append(i)
	return at


## The distance along route 0 of the road point farthest from the tower, and
## that point's distance from the tower in cells.
static func farthest_from(scene: Scene) -> Array:
	var route := scene.game.routes[0]
	var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	var best_along := 0.0
	var best_gap := 0.0
	var along := 0.0
	while along <= route.total:
		var point := route.position_at(along)
		var gap := centre.distance_to(Vector2(point.x, point.y))
		if gap > best_gap:
			best_gap = gap
			best_along = along
		along += 0.05
	return [best_along, best_gap]


## A game with a tower of `type_a` then one of `type_b`, built on two different
## level-0 sockets that both reach the same point of the road, `near` along it.
static func pair(type_a: String, type_b: String, map_seed: int = 1) -> Scene:
	var scene := Scene.new()
	scene.game = Game.create(map_seed)
	var map := scene.game.map
	var route := scene.game.routes[0]
	var flat: Array[Vector2i] = []
	for socket in map.sockets:
		if map.elevation_at(socket) == 0:
			flat.append(socket)
	var found := false
	var along := 0.0
	while along <= route.total and not found:
		var point := route.position_at(along)
		var here := Vector2(point.x, point.y)
		var close: Array[Vector2i] = []
		for socket in flat:
			if map.socket_centre(socket).distance_to(here) <= 2.2:
				close.append(socket)
		if close.size() >= 2:
			scene.near = along
			scene.gap = 2.2
			scene.game.buttons = 1000
			Game.submit(scene.game, Command.build(type_a, close[0].x, close[0].y))
			Game.submit(scene.game, Command.build(type_b, close[1].x, close[1].y))
			Game.tick(scene.game)
			found = true
		along += 0.05
	assert(found, "no point of the road is within reach of two level-0 sockets")
	scene.tower = scene.game.towers[0]
	scene.second = scene.game.towers[1]
	scene.tower.cooldown = 0.0
	scene.second.cooldown = 0.0
	return scene
