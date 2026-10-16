## A fixed game with a spec chosen and its active used, for the specs golden: a
## Spool Guard taken to the Crossbow Ballista, seven Corrugated Orcs standing in a
## line, then the skewer and six seconds of play. Checkpoints use `ReplayKit` (hashes
## of the whole state and of the events, floats as bits).
class_name SpecScenario
extends RefCounted

const GOLDEN_PATH := "res://tests/goldens/specs.json"
const PRISM_GOLDEN_PATH := "res://tests/goldens/specs_prism.json"
const MORTAR_GOLDEN_PATH := "res://tests/goldens/specs_mortar.json"
const AVIARY_GOLDEN_PATH := "res://tests/goldens/specs_aviary.json"
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
		if tick == 60:
			# the cooldown is still running: this is refused and the golden pins the refusal
			Game.submit(game, Command.activate(scene.tower.id))
		if tick % CHECKPOINT_EVERY == 0:
			out.append(ReplayKit.checkpoint(game, events))
		Game.tick(game)
		events.fold(game)
	out.append(ReplayKit.checkpoint(game, events))
	return out


## A Prism Spire with one spec, a line of foes in its reach, the active used once, then play:
## `spec` is "cryoOrigamiSpire" (Flash Freeze) or "blotSingularity" (Ink Vortex and Corrosive
## Light). Foes stand on the road near the spire; a Cardboard Golem is among them.
static func play_prism(spec: String) -> Array:
	return play_tower("prismSpire", spec)


## The same for a mortar spec ("glitterCannon" or "stickyGlueMortar").
static func play_mortar(spec: String) -> Array:
	return play_tower("thimbleMortar", spec)


## The Spool Guard's Aviary: the squadron over a line of foes, a neighbour tower in recon.
static func play_aviary() -> Array:
	return play_tower("spoolGuard", "paperPlaneAviary")


static func play_tower(tower_type: String, spec: String) -> Array:
	var scene := TowerFireKit.scene(tower_type)
	var game := scene.game
	game.buttons = 10000
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(scene.tower.id, spec))
	Game.tick(game)
	for step in 5:
		var type := "cardboardGolem" if step == 3 else "corrugatedOrc"
		var foe := TowerFireKit.foe(game, scene.near - 0.9 + 0.45 * float(step), type)
		foe.speed = 0.5
		foe.hp = 100000.0
		foe.max_hp = 100000.0
	var events := ReplayKit.EventDigest.new()
	var out := []
	Game.submit(game, Command.activate(scene.tower.id))
	for tick in 240:
		if tick % CHECKPOINT_EVERY == 0:
			out.append(ReplayKit.checkpoint(game, events))
		Game.tick(game)
		events.fold(game)
	out.append(ReplayKit.checkpoint(game, events))
	return out
