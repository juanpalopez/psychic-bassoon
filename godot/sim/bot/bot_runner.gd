## Plays a whole game with the scripted bot, headless, and returns plain data.
class_name BotRunner
extends RefCounted

## Thirty minutes of play at the sim's tick rate.
const DEFAULT_MAX_TICKS := 54000


## Plays `map_seed` with `profile` (see `content/bot_profiles.gd`) until the
## Heartstone falls, `max_waves` waves are cleared or `max_ticks` ticks pass.
static func play(
	map_seed: int, profile: Dictionary, max_waves: int, max_ticks: int = DEFAULT_MAX_TICKS
) -> Dictionary:
	return play_with(map_seed, ScriptedBot.new(profile).act, max_waves, max_ticks)


## The same with any player: `act` is called with the game before every tick and
## may only send commands. The per-wave records and `unfinished` count what
## happened since the previous clear (with early calls, kills belong to the wave
## that clears next), so together they add up to the totals.
static func play_with(
	map_seed: int, act: Callable, max_waves: int, max_ticks: int = DEFAULT_MAX_TICKS
) -> Dictionary:
	var game := Game.create(map_seed)
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
