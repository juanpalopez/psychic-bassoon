## `Game.create_on_strip_valley` is the board the mechanic tests name; today it is the same game
## as the default board, to the last bit (#458). When the default flips, this test is the one to
## change, and the mechanic tests do not move.
extends GutTest

const SEEDS := 60
## Waves played on the seeds that run a whole stretch of play.
const WAVES := 12
const PLAYED_SEEDS: Array[int] = [1, 7, 42]
const MAX_TICKS := 60000
## Ticks between two launches: the waves overlap, which is the busier case.
const WAVE_EVERY := 900


func _hash(game: GameState) -> String:
	var events := ReplayKit.EventDigest.new()
	return str(ReplayKit.checkpoint(game, events).hash)


func test_both_entries_give_the_same_game_on_seeds_1_to_60() -> void:
	for map_seed in range(1, SEEDS + 1):
		var a := Game.create(map_seed)
		var b := Game.create_on_strip_valley(map_seed)
		assert_eq(_hash(a), _hash(b), "seed %d" % map_seed)
		assert_eq(a.rng.state, b.rng.state, "seed %d rng" % map_seed)
		assert_not_null(b.hero, "seed %d keeps the Knight" % map_seed)


func test_both_entries_play_twelve_waves_alike() -> void:
	for map_seed in PLAYED_SEEDS:
		var a := Game.create(map_seed)
		var b := Game.create_on_strip_valley(map_seed)
		var da := ReplayKit.EventDigest.new()
		var db := ReplayKit.EventDigest.new()
		a.heartstone_health = 1000000
		b.heartstone_health = 1000000
		var ticks := 0
		while a.wave < WAVES and ticks < MAX_TICKS:
			if ticks % WAVE_EVERY == 0:
				Game.submit(a, Command.launch_wave())
				Game.submit(b, Command.launch_wave())
			Game.tick(a)
			Game.tick(b)
			da.fold(a)
			db.fold(b)
			ticks += 1
		assert_eq(a.wave, WAVES, "seed %d reached the wave" % map_seed)
		assert_eq(ReplayKit.checkpoint(a, da), ReplayKit.checkpoint(b, db), "seed %d" % map_seed)
