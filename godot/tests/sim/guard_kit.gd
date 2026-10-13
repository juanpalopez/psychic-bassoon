## Helpers for the Guard Tent tests.
class_name GuardKit
extends RefCounted


## A game with Buttons to spare and a Guard Tent on its first socket.
static func game_with_tent(map_seed: int = 1) -> GameState:
	var game := Game.create(map_seed)
	game.buttons = 5000
	var anchor := game.map.sockets[0]
	GameTestKit.run(game, [Command.build("guardTent", anchor.x, anchor.y)])
	return game


static func tent(game: GameState) -> Tower:
	return game.towers[0]


## The point of the route where the tent's guards stand (the middle of the two).
static func post(game: GameState) -> float:
	return (game.guards[0].post + game.guards[1].post) / 2.0


## A foe `behind` cells before the middle of the tent's post.
static func foe_before_post(game: GameState, type: String, behind: float, wave: int = 1) -> Foe:
	var foe := FoeSpawner.spawn(game, type, wave, 0)
	foe.distance = post(game) - behind
	var at := game.routes[0].position_at(foe.distance)
	foe.x = at.x
	foe.y = at.y
	return foe


static func tick(game: GameState, count: int) -> void:
	for i in count:
		Game.tick(game)


static func events_of(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in game.events:
		if event.kind == kind:
			found.append(event)
	return found


## A Mess Tent socket whose block centre is within `reach` cells of the guards'
## post, or (-1, -1). The guard tent's own socket is left out.
static func socket_near_post(game: GameState, reach: float) -> Vector2i:
	var at := game.routes[0].position_at(post(game))
	for anchor in game.map.sockets:
		if anchor == Vector2i(game.towers[0].col, game.towers[0].row):
			continue
		var centre := game.map.socket_centre(anchor)
		if centre.distance_to(Vector2(at.x, at.y)) <= reach:
			return anchor
	return Vector2i(-1, -1)


## A game with a Guard Tent and, near its guards, a Mess Tent of `level` (0 to 2).
## Seed 0 means the first seed (from 1) where such a socket exists.
static func game_with_both(level: int = 0) -> GameState:
	for map_seed in range(1, 40):
		var game := game_with_tent(map_seed)
		var anchor := socket_near_post(game, 2.1)
		if anchor == Vector2i(-1, -1):
			continue
		GameTestKit.run(game, [Command.build("messTent", anchor.x, anchor.y)])
		for i in level:
			GameTestKit.run(game, [Command.upgrade(game.towers[1].id)])
		return game
	return null
