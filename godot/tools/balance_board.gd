## The board the balance tool plays on (#458): `strip`, `layout` or `default`, and a run of the
## scripted bot on it. It lives in the tool, not in `godot/sim`, so the bot's runner is untouched;
## `BotRunner.play_with` makes its own game, so this plays the same loop on the named board.
class_name BalanceBoard
extends RefCounted


## The game for a seed on a board. Null (with an error) when the board cannot be made.
static func game_for(board: String, map_seed: int) -> GameState:
	match board:
		"layout":
			return Game.create_on_layout_valley(map_seed)
		"strip":
			# named after the generator, not `Game.create`: the default board flips to the layout
			# valley in #458 and `strip` must keep meaning the strip valley (the same arguments
			# `Game.create` uses on its board); when `Game.create_on_strip_valley` lands, this
			# branch becomes that one call
			var strip_map := MapGen.generate_valley(map_seed)
			if strip_map == null:
				push_error("no strip valley for seed %d" % map_seed)
				return null
			return Game.from_map(map_seed, strip_map, false, true)
		_:
			return Game.create(map_seed)


## Plays `map_seed` on `board` with `profile` like `BotRunner.play`, and returns the same
## record (empty when the board cannot be made).
static func play(
	board: String,
	map_seed: int,
	profile: Dictionary,
	max_waves: int,
	max_ticks: int = BotRunner.DEFAULT_MAX_TICKS
) -> Dictionary:
	var game := game_for(board, map_seed)
	if game == null:
		return {}
	# keep the bot in a variable: a Callable on a temporary would lose its object
	var bot := ScriptedBot.new(profile)
	var act := bot.act
	var kills := 0
	var leaks := 0
	var rejected := 0
	var waves := []
	var since_clear := {"kills": 0, "leaks": 0, "ticks": 0}
	var waves_cleared := 0
	var ticks := 0
	while ticks < max_ticks and not game.over and not game.won and waves_cleared < max_waves:
		act.call(game)
		Game.tick(game)
		ticks += 1
		since_clear.ticks += 1
		for event in game.events:
			match event.kind:
				GameEvent.Kind.FOE_KILLED:
					kills += 1
					since_clear.kills += 1
				GameEvent.Kind.FOE_LEAKED:
					leaks += 1
					since_clear.leaks += 1
				GameEvent.Kind.COMMAND_REJECTED:
					rejected += 1
				GameEvent.Kind.WAVE_CLEARED:
					waves_cleared = event.wave
					(
						waves
						. append(
							{
								"wave": event.wave,
								"kills": since_clear.kills,
								"leaks": since_clear.leaks,
								"ticks": since_clear.ticks,
								"buttons": game.buttons,
								"towers": game.towers.size(),
							}
						)
					)
					since_clear = {"kills": 0, "leaks": 0, "ticks": 0}
	var levels := [0, 0, 0]
	for tower in game.towers:
		levels[tower.level] += 1
	return {
		"seed": map_seed,
		"waves_cleared": waves_cleared,
		"over": game.over,
		"won": game.won,
		"died_on_wave": game.wave if game.over else 0,
		"heartstone_health": game.heartstone_health,
		"towers": game.towers.size(),
		"sockets": game.map.sockets.size(),
		"tower_levels": levels,
		"buttons": game.buttons,
		"kills": kills,
		"leaks": leaks,
		"rejected": rejected,
		"ticks": ticks,
		"waves": waves,
		"unfinished": since_clear,
	}
