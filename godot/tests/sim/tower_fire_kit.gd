## Shared setup for the tower fire tests.
class_name TowerFireKit
extends RefCounted


## A game with one tower of `type` built (cooldown 0) on the level-0 socket
## nearest the road, and a way to put a foe on the road in its reach.
class Scene:
	extends RefCounted
	var game: GameState
	var tower: Tower
	var near: float = 0.0
	var gap: float = 0.0


static func scene(type: String = "spoolGuard", map_seed: int = 1, at_end: bool = false) -> Scene:
	var scene := Scene.new()
	scene.game = Game.create(map_seed)
	var route := scene.game.routes[0]
	var best_socket := Vector2i(-1, -1)
	scene.gap = INF
	var end := route.position_at(route.total)
	for socket in scene.game.map.sockets:
		if scene.game.map.elevation_at(socket) != 0:
			continue
		var centre := Vector2(float(socket.x) + 0.5, float(socket.y) + 0.5)
		if at_end:
			var to_end := centre.distance_to(Vector2(end.x, end.y))
			if to_end < scene.gap:
				scene.gap = to_end
				scene.near = route.total
				best_socket = socket
			continue
		var along := 0.0
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
	var centre := Vector2(float(scene.tower.col) + 0.5, float(scene.tower.row) + 0.5)
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
