## A whole game played by the scripted bot, headless, returned as plain data.
extends GutTest

const PROFILES := preload("res://content/bot_profiles.gd")


func test_a_run_returns_the_numbers_a_balance_report_needs() -> void:
	var result := BotRunner.play(1, PROFILES.PROFILES.mix, 2)
	for key in [
		"seed",
		"waves_cleared",
		"over",
		"heartstone_health",
		"towers",
		"tower_levels",
		"buttons",
		"kills",
		"leaks",
		"rejected",
		"ticks",
		"waves"
	]:
		assert_true(result.has(key), key)
	assert_eq(result.seed, 1)
	assert_eq(result.rejected, 0)


func test_it_stops_after_the_asked_number_of_waves() -> void:
	var result := BotRunner.play(1, PROFILES.PROFILES.mix, 2)
	assert_eq(result.waves_cleared, 2)
	assert_false(result.over)
	assert_eq(result.waves.size(), 2)
	assert_gt(result.kills, 0)
	assert_gt(result.towers, 0)


func test_each_wave_reports_its_foes_kills_leaks_and_time() -> void:
	var result := BotRunner.play(1, PROFILES.PROFILES.mix, 3)
	var total_kills := 0
	var total_leaks := 0
	for wave in result.waves:
		assert_true(wave.has("wave") and wave.has("kills") and wave.has("leaks"))
		assert_gt(wave.ticks, 0)
		total_kills += wave.kills
		total_leaks += wave.leaks
	assert_eq(result.waves[0].wave, 1)
	assert_eq(result.waves[2].wave, 3)
	assert_eq(total_kills, result.kills)
	assert_eq(total_leaks, result.leaks)


func test_the_same_seed_and_profile_play_the_same_game() -> void:
	var a := BotRunner.play(7, PROFILES.PROFILES.spoolOnly, 3)
	var b := BotRunner.play(7, PROFILES.PROFILES.spoolOnly, 3)
	assert_eq(a, b)


func test_different_seeds_give_different_games() -> void:
	var a := BotRunner.play(1, PROFILES.PROFILES.mix, 2)
	var b := BotRunner.play(2, PROFILES.PROFILES.mix, 2)
	assert_ne(a.ticks, b.ticks)


func test_a_player_who_builds_nothing_loses() -> void:
	var idle := {"build_order": [], "call_early": false, "early_foes_left": 0}
	var result := BotRunner.play(1, idle, 30)
	assert_true(result.over)
	assert_eq(result.heartstone_health, 0)
	assert_lt(result.waves_cleared, 30)
	assert_eq(result.towers, 0)


func test_the_tick_limit_stops_a_run() -> void:
	var result := BotRunner.play(1, PROFILES.PROFILES.mix, 1000, 600)
	assert_eq(result.ticks, 600)
	assert_false(result.over)


func test_the_bot_gets_a_stronger_game_than_nothing() -> void:
	var idle := {"build_order": [], "call_early": false, "early_foes_left": 0}
	var with_towers := BotRunner.play(1, PROFILES.PROFILES.mix, 5)
	var without := BotRunner.play(1, idle, 5)
	assert_gt(with_towers.waves_cleared, without.waves_cleared)
	assert_gt(with_towers.heartstone_health, without.heartstone_health)
