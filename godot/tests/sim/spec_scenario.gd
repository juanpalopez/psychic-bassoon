## A fixed game with a spec chosen and its active used, for the specs golden: a
## Spool Guard taken to the Crossbow Ballista, seven Corrugated Orcs standing in a
## line, then the skewer and six seconds of play. Checkpoints use `ReplayKit` (hashes
## of the whole state and of the events, floats as bits).
class_name SpecScenario
extends RefCounted

const GOLDEN_PATH := "res://tests/goldens/specs.json"
const CHECKPOINT_EVERY := 30
const TICKS := 180


static func play() -> Array:
	var scene := TowerFireKit.scene()
	var game := scene.game
	game.buttons = 10000
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(scene.tower.id, "crossbowBallista"))
	Game.tick(game)
	scene.tower.cooldown = 1000.0
	var centre := game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	var distance := 10.0
	for offset in [0.5, 0.8, 1.0, 1.3, 1.6, 1.9, 2.2]:
		var foe := TowerFireKit.foe(game, distance, "corrugatedOrc")
		foe.x = centre.x + offset
		foe.y = centre.y
		distance += 0.5
	var events := ReplayKit.EventDigest.new()
	var out := []
	Game.submit(game, Command.activate(scene.tower.id))
	for tick in TICKS:
		if tick % CHECKPOINT_EVERY == 0:
			out.append(ReplayKit.checkpoint(game, events))
		Game.tick(game)
		events.fold(game)
	out.append(ReplayKit.checkpoint(game, events))
	return out
