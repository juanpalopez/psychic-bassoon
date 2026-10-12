## Records a game played by the scripted bot and replays it from its commands.
## A recording is plain data: the seed, the commands (tick first), and a
## checkpoint of the state every `CHECKPOINT_EVERY` ticks and at the end. A
## checkpoint is taken at the start of its tick, before that tick's commands.
## It holds a few readable numbers and a SHA-256 of the whole state, so a
## difference anywhere (a float's last bit included) shows up, in little space.
class_name ReplayKit
extends RefCounted

const PROFILES := preload("res://content/bot_profiles.gd")

## Two seconds of play at 30 Hz, times thirty: one checkpoint a minute.
const CHECKPOINT_EVERY := 1800


## Plays `map_seed` with the named bot profile for up to `max_waves` waves.
static func record(map_seed: int, profile_id: String, max_waves: int) -> Dictionary:
	var bot := ScriptedBot.new(PROFILES.PROFILES[profile_id])
	var commands := []
	var checkpoints := []
	var seen := []
	var act := func(game: GameState) -> void:
		seen.append(game)
		if game.tick_count % CHECKPOINT_EVERY == 0:
			checkpoints.append(checkpoint(game))
		var before := game.pending.size()
		bot.act(game)
		for i in range(before, game.pending.size()):
			commands.append(encode(game.tick_count, game.pending[i]))
	var result := BotRunner.play_with(map_seed, act, max_waves)
	var game: GameState = seen.back()
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
		"final": checkpoint(game),
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
	var checkpoints := []
	for tick in int(recording.ticks):
		if tick % CHECKPOINT_EVERY == 0:
			checkpoints.append(checkpoint(game))
		for command in by_tick.get(tick, []):
			Game.submit(game, command)
		Game.tick(game)
	return {"checkpoints": checkpoints, "final": checkpoint(game)}


## A few readable numbers and the hash of the whole state.
static func checkpoint(game: GameState) -> Dictionary:
	var state := GameTestKit.snapshot(game)
	state.erase("routes")
	return {
		"tick": game.tick_count,
		"wave": game.wave,
		"buttons": game.buttons,
		"heartstone_health": game.heartstone_health,
		"foes": game.foes.size(),
		"towers": game.towers.size(),
		"hash": JSON.stringify(_with_bits(state), "", true).sha256_text(),
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
