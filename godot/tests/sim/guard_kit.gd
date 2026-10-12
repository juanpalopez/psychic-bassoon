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
