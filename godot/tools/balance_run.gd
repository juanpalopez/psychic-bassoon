## Plays the scripted bot on several seeds and prints how it did, so a change to
## the numbers shows its effect. Run it from the repo root:
##
##   godot --headless --path godot -s tools/balance_run.gd -- --seeds=1,2,3 \
##       --profiles=spoolOnly,mix --waves=20
##
## All three options are optional: the defaults are seeds 1 to 8, every profile
## and 20 waves. `--detail` adds, for each profile, a table of the waves averaged
## over the seeds (how long a wave took to clear, kills, leaks, towers, Buttons),
## and a table of what each wave is made of.
extends SceneTree

const PROFILES := preload("res://content/bot_profiles.gd")
const WAVES := preload("res://content/waves.gd")
const DEFAULT_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8]
const DEFAULT_WAVES := 20


func _init() -> void:
	var seeds := DEFAULT_SEEDS
	var profile_ids := PROFILES.PROFILE_IDS
	var max_waves := DEFAULT_WAVES
	var detail := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = []
			for part in arg.trim_prefix("--seeds=").split(","):
				seeds.append(int(part))
		elif arg.begins_with("--profiles="):
			profile_ids = []
			for part in arg.trim_prefix("--profiles=").split(","):
				profile_ids.append(part)
		elif arg == "--detail":
			detail = true
		elif arg.begins_with("--waves="):
			max_waves = int(arg.trim_prefix("--waves="))
	print(
		"profile        seed  cleared  died  heart  towers  levels(0/1/2)  buttons  kills  leaks  minutes"
	)
	for id in profile_ids:
		var cleared: Array[int] = []
		var results: Array[Dictionary] = []
		for map_seed in seeds:
			var r := BotRunner.play(map_seed, PROFILES.PROFILES[id], max_waves)
			results.append(r)
			cleared.append(r.waves_cleared)
			print(
				(
					"%-14s %4d  %7d  %4d  %5d  %6d  %d/%d/%d  %9d  %5d  %5d  %7.1f"
					% [
						id,
						map_seed,
						r.waves_cleared,
						r.died_on_wave,
						r.heartstone_health,
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
		if detail:
			_print_waves(id, results)
	if detail:
		_print_composition(seeds[0], max_waves)
	quit()


## The waves of every run of a profile, averaged: only the runs that cleared a
## wave count for it.
func _print_waves(id: String, results: Array[Dictionary]) -> void:
	print("\n%s, waves averaged over the runs that cleared them" % id)
	print("wave  runs  clear(s)  kills  leaks  towers  buttons")
	for wave in range(1, 61):
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


## What each wave is made of on one seed: foes, by kind, and their total hp.
func _print_composition(map_seed: int, max_waves: int) -> void:
	print("\nwave composition on seed %d" % map_seed)
	print("wave  foes  goblins  orcs  golems  total hp  first foe in (s)  last foe in (s)")
	var game := Game.create(map_seed)
	for wave in range(1, max_waves + 1):
		var orders := WaveBuilder.build(wave, game.rng)
		var counts := {"scrapGoblin": 0, "corrugatedOrc": 0, "cardboardGolem": 0}
		var hp := 0
		var time := WAVES.FIRST_SPAWN_DELAY
		var first := time
		for order in orders:
			counts[order.type] += 1
			hp += FoeStats.for_wave(order.type, wave).hp
			time += order.gap
		print(
			(
				"%4d  %4d  %7d  %4d  %6d  %8d  %16.1f  %15.1f"
				% [
					wave,
					orders.size(),
					counts.scrapGoblin,
					counts.corrugatedOrc,
					counts.cardboardGolem,
					hp,
					first,
					time,
				]
			)
		)
