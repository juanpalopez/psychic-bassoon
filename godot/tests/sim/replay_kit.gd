## Records a game played by the scripted bot and replays it from its commands.
## A recording is plain data: the seed, the commands (tick first), and a
## checkpoint of the state every `CHECKPOINT_EVERY` ticks and at the end. A
## checkpoint is taken at the start of its tick, before that tick's commands.
## It holds a few readable numbers, a SHA-256 of the whole state, and a running
## SHA-256 of every event drained so far, so a difference anywhere (a float's
## last bit, an event's payload) shows up, in little space.
class_name ReplayKit
extends RefCounted

const PROFILES := preload("res://content/bot_profiles.gd")

## Twenty seconds of play at 30 Hz.
const CHECKPOINT_EVERY := 600


## Plays `map_seed` with the named bot profile for up to `max_waves` waves.
static func record(map_seed: int, profile_id: String, max_waves: int) -> Dictionary:
	var bot := ScriptedBot.new(PROFILES.PROFILES[profile_id])
	var commands := []
	var checkpoints := []
	var seen := []
	var events := EventDigest.new()
	var act := func(game: GameState) -> void:
		seen.append(game)
		# the events of the tick that just ran, folded before this tick's checkpoint
		events.fold(game)
		if game.tick_count % CHECKPOINT_EVERY == 0:
			checkpoints.append(checkpoint(game, events))
		var before := game.pending.size()
		bot.act(game)
		for i in range(before, game.pending.size()):
			commands.append(encode(game.tick_count, game.pending[i]))
	var result := BotRunner.play_with(map_seed, act, max_waves)
	var game: GameState = seen.back()
	events.fold(game)
	var outcome := "unfinished"
	if result.won:
		outcome = "won"
	elif result.over:
		outcome = "lost"
	elif result.waves_cleared >= max_waves:
		outcome = "stopped"
	return {
		"seed": map_seed,
		"profile": profile_id,
		"max_waves": max_waves,
		"outcome": outcome,
		"ticks": game.tick_count,
		"commands": commands,
		"checkpoints": checkpoints,
		"final": checkpoint(game, events),
	}


## Feeds the recorded commands to a fresh game, no bot, and takes the same
## checkpoints.
static func replay(recording: Dictionary) -> Dictionary:
	var game := Game.create(int(recording.seed))
	var by_tick := {}
	for entry in recording.commands:
		var tick := int(entry[0])
		if not by_tick.has(tick):
			by_tick[tick] = []
		by_tick[tick].append(decode(entry))
	var events := EventDigest.new()
	var checkpoints := []
	for tick in int(recording.ticks):
		if tick % CHECKPOINT_EVERY == 0:
			checkpoints.append(checkpoint(game, events))
		for command in by_tick.get(tick, []):
			Game.submit(game, command)
		Game.tick(game)
		events.fold(game)
	return {"checkpoints": checkpoints, "final": checkpoint(game, events)}


## A few readable numbers and the hashes of the whole state and of the events.
static func checkpoint(game: GameState, events: EventDigest) -> Dictionary:
	var state := GameTestKit.snapshot(game)
	state.erase("routes")
	state.erase("events")
	state.erase("pending")
	var more := []
	for foe in game.foes:
		more.append(
			[
				foe.id,
				foe.wave,
				foe.max_hp,
				foe.resist,
				foe.radius,
				foe.leak,
				foe.slow_timer,
				foe.alive
			]
		)
	state["foe_details"] = more
	return {
		"tick": game.tick_count,
		"wave": game.wave,
		"buttons": game.buttons,
		"heartstone_health": game.heartstone_health,
		"foes": game.foes.size(),
		"towers": game.towers.size(),
		"hash": JSON.stringify(_with_bits(state), "", true).sha256_text(),
		"events": events.digest,
	}


static func encode(tick: int, command: Command) -> Array:
	match command.kind:
		Command.Kind.BUILD:
			return [tick, "build", command.tower, command.col, command.row]
		Command.Kind.UPGRADE:
			return [tick, "upgrade", command.tower_id]
		Command.Kind.SELL:
			return [tick, "sell", command.tower_id]
	return [tick, "launch_wave"]


static func decode(entry: Array) -> Command:
	match entry[1]:
		"build":
			return Command.build(entry[2], int(entry[3]), int(entry[4]))
		"upgrade":
			return Command.upgrade(int(entry[2]))
		"sell":
			return Command.sell(int(entry[2]))
	return Command.launch_wave()


## The IEEE-754 bits of a float as 16 hex digits, most significant byte first.
static func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	var hex := ""
	for i in range(7, -1, -1):
		hex += "%02x" % bytes[i]
	return hex


## JSON reads every number as a float; give back the ints a recording holds.
static func normalised(value: Variant) -> Variant:
	if value is Array:
		var out := []
		for item in value:
			out.append(normalised(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = normalised(value[key])
		return out
	if value is float and value == floor(value):
		return int(value)
	return value


## Folds the events of each tick into one running hash.
class EventDigest:
	extends RefCounted
	var digest := ""

	## Call once after every tick, with the game that just ticked.
	func fold(game: GameState) -> void:
		if game.events.is_empty():
			return
		var lines := []
		for event in game.events:
			lines.append(ReplayKit.describe(event))
		digest = (digest + JSON.stringify(lines)).sha256_text()


## Every field of an event, floats as bits.
static func describe(event: GameEvent) -> Array:
	var command := ""
	if event.command != null:
		command = JSON.stringify(encode(0, event.command))
	return [
		event.kind,
		event.tower_id,
		event.level,
		event.refund,
		event.wave,
		event.early_bonus,
		event.bonus,
		event.foe_id,
		event.foe_type,
		event.leak,
		event.reward,
		bits(event.splash),
		bits(event.x),
		bits(event.y),
		command,
		event.reason,
	]


static func _with_bits(value: Variant) -> Variant:
	if value is Array:
		var out := []
		for item in value:
			out.append(_with_bits(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _with_bits(value[key])
		return out
	if value is float:
		return bits(value)
	return value
