## Plays the scripted bot on several seeds and prints how it did, so a change to
## the numbers shows its effect. Run it from the repo root:
##
##   godot --headless --path godot -s tools/balance_run.gd -- --seeds=1,2,3 \
##       --profiles=spoolOnly,mix --waves=20
##
## All the options are optional: the defaults are seeds 1 to 8, every profile
## and 20 waves; a mistyped option prints the usage and exits with 1. `--detail`
## adds, for each profile, a table of the waves averaged over the seeds (how long
## a wave took to clear, kills, leaks, towers, Buttons), the mean road length and
## a table of what each wave is made of. `--board=strip|layout|default` plays the
## strip valley, the layout valley or the game's default board (no option is the
## default board and the output is as before); `--pace=` sets the foe pace of the map
## (`GameMap.foe_pace`, a number above 0; no option keeps the board's own pace).
extends SceneTree

const PROFILES := preload("res://content/bot_profiles.gd")
const WAVES := preload("res://content/waves.gd")


func _init() -> void:
	var args := BalanceArgs.parse(OS.get_cmdline_user_args())
	if args.error != "":
		printerr(args.error)
		printerr(BalanceArgs.usage())
		quit(1)
		return
	var seeds: Array[int] = args.seeds
	var max_waves: int = args.waves
	var board: String = args.board if args.board != "" else "default"
	var pace: float = args.pace
	if args.board != "" or pace > 0.0:
		print("board: %s%s" % [board, _pace_text(pace, ", ")])
	print(
		(
			"profile        seed  cleared  died  heart  sockets  towers  levels(0/1/2)"
			+ "  buttons  kills  leaks  minutes"
		)
	)
	for id in args.profiles:
		var cleared: Array[int] = []
		var results: Array[Dictionary] = []
		for map_seed in seeds:
			var r := BalanceBoard.play_for_args(args, map_seed, PROFILES.PROFILES[id])
			if r.is_empty():
				printerr("no %s board for seed %d" % [board, map_seed])
				quit(1)
				return
			results.append(r)
			cleared.append(r.waves_cleared)
			print(
				(
					"%-14s %4d  %7d  %4d  %5d  %7d  %6d  %d/%d/%d  %9d  %5d  %5d  %7.1f"
					% [
						id,
						map_seed,
						r.waves_cleared,
						r.died_on_wave,
						r.heartstone_health,
						r.sockets,
						r.towers,
						r.tower_levels[0],
						r.tower_levels[1],
						r.tower_levels[2],
						r.buttons,
						r.kills,
						r.leaks,
						float(r.ticks) / 30.0 / 60.0,
					]
				)
			)
		cleared.sort()
		print("%-14s median waves cleared: %d" % [id, cleared[cleared.size() / 2]])
		if args.detail:
			_print_waves(id, results, max_waves, pace)
	if args.detail:
		_print_road_length(seeds, args.board)
		_print_composition(seeds[0], max_waves, board, args.board != "", pace)
	quit()


## The waves of every run of a profile, averaged: only the runs that cleared a
## wave count for it.
func _print_waves(id: String, results: Array[Dictionary], max_waves: int, pace: float) -> void:
	print("\n%s%s, waves averaged over the runs that cleared them" % [id, _pace_text(pace, " at ")])
	print("wave  runs  clear(s)  kills  leaks  towers  buttons")
	for wave in range(1, max_waves + 1):
		var n := 0
		var seconds := 0.0
		var kills := 0.0
		var leaks := 0.0
		var towers := 0.0
		var buttons := 0.0
		for r in results:
			for w in r.waves:
				if w.wave == wave:
					n += 1
					seconds += float(w.ticks) / 30.0
					kills += w.kills
					leaks += w.leaks
					towers += w.towers
					buttons += w.buttons
		if n == 0:
			continue
		print(
			(
				"%4d  %4d  %8.1f  %5.1f  %5.2f  %6.1f  %7.0f"
				% [wave, n, seconds / n, kills / n, leaks / n, towers / n, buttons / n]
			)
		)


## The mean length of the main road, in cells, on the given seeds, against the
## original 9 by 13 board (the numbers behind "the road is much longer").
func _print_road_length(seeds: Array[int], named_board: String) -> void:
	if named_board != "":
		var total := 0.0
		for map_seed in seeds:
			total += float(BalanceBoard.game_for(named_board, map_seed).map.path.size())
		print(
			(
				"\nmean main road on the %s board over %d seeds: %.1f cells"
				% [named_board, seeds.size(), total / seeds.size()]
			)
		)
		return
	var landscape := 0.0
	var legacy := 0.0
	for map_seed in seeds:
		landscape += float(MapGen.generate(map_seed).path.size())
		legacy += float(MapGen.generate(map_seed, 9, 13, false, 1).path.size())
	print(
		(
			"\nmean main road over %d seeds: %.1f cells (the old 9 by 13 board: %.1f)"
			% [seeds.size(), landscape / seeds.size(), legacy / seeds.size()]
		)
	)


## What each wave is made of on one seed: foes, by kind, and their total hp.
func _print_composition(
	map_seed: int, max_waves: int, board: String, named: bool, pace: float
) -> void:
	var parts: Array[String] = []
	if named:
		parts.append("%s board" % board)
	if pace > 0.0:
		parts.append("foe pace %s" % pace)
	var note := " (%s)" % ", ".join(parts) if not parts.is_empty() else ""
	print("\nwave composition on seed %d%s" % [map_seed, note])
	print(
		(
			"wave  foes  goblins  orcs  golems  moths  shamans  total hp"
			+ "  first foe in (s)  last foe in (s)"
		)
	)
	var game := BalanceBoard.game_for(board, map_seed)
	for wave in range(1, max_waves + 1):
		var orders := WaveBuilder.build(wave, game.rng)
		var counts := {
			"scrapGoblin": 0,
			"corrugatedOrc": 0,
			"cardboardGolem": 0,
			"razorMoth": 0,
			"inkShaman": 0,
		}
		var hp := 0
		var time := WAVES.FIRST_SPAWN_DELAY
		var first := time
		for order in orders:
			counts[order.type] += 1
			hp += FoeStats.for_wave(order.type, wave).hp
			time += order.gap
		print(
			(
				"%4d  %4d  %7d  %4d  %6d  %5d  %7d  %8d  %16.1f  %15.1f"
				% [
					wave,
					orders.size(),
					counts.scrapGoblin,
					counts.corrugatedOrc,
					counts.cardboardGolem,
					counts.razorMoth,
					counts.inkShaman,
					hp,
					first,
					time,
				]
			)
		)


## The pace in the output, after `lead`, when `--pace=` is given; nothing otherwise, so the
## output without the option is unchanged.
func _pace_text(pace: float, lead: String) -> String:
	return "%sfoe pace %s" % [lead, pace] if pace > 0.0 else ""
