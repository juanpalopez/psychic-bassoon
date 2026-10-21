## A fixed game with a spec chosen and its active used, for the specs golden: a
## Spool Guard taken to the Crossbow Ballista, seven Corrugated Orcs standing in a
## line, then the skewer and six seconds of play. Checkpoints use `ReplayKit` (hashes
## of the whole state and of the events, floats as bits).
class_name SpecScenario
extends RefCounted

const SPECS := preload("res://content/specs.gd")

const GOLDEN_PATH := "res://tests/goldens/specs.json"
const PRISM_GOLDEN_PATH := "res://tests/goldens/specs_prism.json"
const MORTAR_GOLDEN_PATH := "res://tests/goldens/specs_mortar.json"
const AVIARY_GOLDEN_PATH := "res://tests/goldens/specs_aviary.json"
const GUARD_GOLDEN_PATH := "res://tests/goldens/specs_guard.json"
const MESS_GOLDEN_PATH := "res://tests/goldens/specs_mess.json"
const CHECKPOINT_EVERY := 30
const TICKS := 180
const NO_SOCKET := Vector2i(-1, -1)
const MAX_SEED := 40


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
	return play_tower("spoolGuard", "paperPlaneAviary", true)


## The first socket whose plot is next to the tower's, within the Aviary's gap, or NO_SOCKET.
static func _neighbour_socket(game: GameState, tower: Tower) -> Vector2i:
	var gap: float = SPECS.find("spoolGuard", "paperPlaneAviary").passive.gap
	var here := game.map.socket_centre(Vector2i(tower.col, tower.row))
	for socket in game.map.sockets:
		var there := game.map.socket_centre(socket)
		if (
			socket != Vector2i(tower.col, tower.row)
			and Specs.adjacent(here, there, float(game.map.footprint), gap)
		):
			return socket
	return NO_SOCKET


static func play_tower(tower_type: String, spec: String, with_neighbour: bool = false) -> Array:
	var scene := TowerFireKit.scene(tower_type)
	if with_neighbour:
		# the valley's sockets are spread along the banks: take the first seed with a plot
		# next to the tower
		var map_seed := 1
		while map_seed < MAX_SEED and _neighbour_socket(scene.game, scene.tower) == NO_SOCKET:
			map_seed += 1
			scene = TowerFireKit.scene(tower_type, map_seed)
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
	if with_neighbour:
		# a Thimble Mortar on a plot next to the Aviary, so High Recon is in the golden
		var socket := _neighbour_socket(game, scene.tower)
		if socket != NO_SOCKET:
			Game.submit(game, Command.build("thimbleMortar", socket.x, socket.y))
			Game.tick(game)
		assert(game.towers.size() == 2, "the aviary scenario needs a plot next to the Aviary")
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


## A Guard Tent at the top level with a spec ("cardboardKnights" or "scissorRogues"), a Golem and
## Orcs walking up to its guards, the active used once, then play.
static func play_guard(spec: String) -> Array:
	var game := GuardKit.game_with_tent()
	var tent := GuardKit.tent(game)
	game.buttons = 10000
	Game.submit(game, Command.upgrade(tent.id))
	Game.submit(game, Command.upgrade(tent.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(tent.id, spec))
	Game.tick(game)
	for step in 4:
		var type := "cardboardGolem" if step == 2 else "corrugatedOrc"
		var foe := GuardKit.foe_before_post(game, type, 0.2 + 0.5 * float(step))
		foe.hp = 100000.0
		foe.max_hp = 100000.0
	var events := ReplayKit.EventDigest.new()
	var out := []
	Game.submit(game, Command.activate(tent.id))
	for tick in 300:
		if tick % CHECKPOINT_EVERY == 0:
			out.append(ReplayKit.checkpoint(game, events))
		Game.tick(game)
		events.fold(game)
	out.append(ReplayKit.checkpoint(game, events))
	return out


## A Guard Tent and a Mess Tent at the top level near its guards, the Mess Tent with a spec
## ("ironRations" or "gourmetFrenzy"), foes walking up, the active used once, then play.
static func play_mess(spec: String) -> Array:
	var game := GuardKit.game_with_both(0)
	var mess: Tower = game.towers[1]
	game.buttons = 10000
	Game.submit(game, Command.upgrade(mess.id))
	Game.submit(game, Command.upgrade(mess.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(mess.id, spec))
	Game.tick(game)
	for step in 3:
		var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.2 + 0.5 * float(step))
		foe.hp = 100000.0
		foe.max_hp = 100000.0
	var events := ReplayKit.EventDigest.new()
	var out := []
	Game.submit(game, Command.activate(mess.id))
	for tick in 300:
		if tick % CHECKPOINT_EVERY == 0:
			out.append(ReplayKit.checkpoint(game, events))
		Game.tick(game)
		events.fold(game)
	out.append(ReplayKit.checkpoint(game, events))
	return out
