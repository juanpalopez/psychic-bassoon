## Replays: a seed plus the commands the bot sent give the same game again, and
## the committed golden (`tests/goldens/replays.json`) pins it across changes.
extends GutTest

const GOLDEN_PATH := "res://tests/goldens/replays.json"


func _golden() -> Array:
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_replays_golden.gd")
	return JSON.parse_string(file.get_as_text())


func test_recording_the_same_game_twice_gives_the_same_recording() -> void:
	var a := ReplayKit.record(3, "mix", 2)
	var b := ReplayKit.record(3, "mix", 2)
	assert_eq(a, b)


func test_a_recording_has_commands_checkpoints_and_a_final_state() -> void:
	var rec := ReplayKit.record(3, "mix", 5)
	assert_gt(rec.commands.size(), 0)
	assert_eq(rec.checkpoints[0].tick, 0)
	assert_eq(rec.checkpoints[1].tick, ReplayKit.CHECKPOINT_EVERY)
	assert_eq(rec.final.tick, rec.ticks)
	assert_eq(rec.final.hash.length(), 64)


func test_the_commands_alone_replay_to_the_same_checkpoints() -> void:
	var rec := ReplayKit.record(3, "mix", 3)
	var again := ReplayKit.replay(rec)
	assert_eq(again.checkpoints, rec.checkpoints)
	assert_eq(again.final, rec.final)


func test_a_dropped_command_changes_the_final_state() -> void:
	var rec := ReplayKit.record(3, "mix", 3)
	var changed := rec.duplicate(true)
	changed.commands.remove_at(changed.commands.size() / 2)
	assert_ne(ReplayKit.replay(changed).final.hash, rec.final.hash)


func test_a_command_one_tick_later_changes_the_final_state() -> void:
	var rec := ReplayKit.record(3, "mix", 3)
	var changed := rec.duplicate(true)
	changed.commands[1][0] += 1
	assert_ne(ReplayKit.replay(changed).final.hash, rec.final.hash)


func test_another_seed_with_the_same_commands_differs() -> void:
	var rec := ReplayKit.record(3, "mix", 3)
	var changed := rec.duplicate(true)
	changed.seed = 4
	assert_ne(ReplayKit.replay(changed).final.hash, rec.final.hash)


func test_floats_are_compared_by_their_bits() -> void:
	assert_eq(ReplayKit.bits(1.0), "3ff0000000000000")
	assert_eq(ReplayKit.bits(0.1), "3fb999999999999a")


func test_the_golden_covers_a_won_run_and_a_lost_run() -> void:
	var golden := _golden()
	assert_gte(golden.size(), 4)
	var won := 0
	var lost := 0
	for rec in golden:
		if rec.outcome == "won":
			won += 1
		if rec.outcome == "lost":
			lost += 1
	assert_gt(won, 0)
	assert_gt(lost, 0)


func test_the_bot_still_plays_the_golden_games() -> void:
	for entry in _golden():
		var rec := ReplayKit.record(int(entry.seed), entry.profile, int(entry.max_waves))
		var label := "seed %d %s" % [entry.seed, entry.profile]
		assert_eq(rec.outcome, entry.outcome, label)
		assert_eq(rec.ticks, int(entry.ticks), label)
		assert_eq(rec.commands, ReplayKit.normalised(entry.commands), label)
		assert_eq(rec.checkpoints, ReplayKit.normalised(entry.checkpoints), label)
		assert_eq(rec.final, ReplayKit.normalised(entry.final), label)


func test_the_golden_commands_replay_without_the_bot() -> void:
	for entry in _golden():
		var rec: Dictionary = entry.duplicate(true)
		rec.seed = int(entry.seed)
		rec.ticks = int(entry.ticks)
		rec.commands = ReplayKit.normalised(entry.commands)
		var again := ReplayKit.replay(rec)
		var label := "seed %d %s" % [entry.seed, entry.profile]
		assert_eq(again.checkpoints, ReplayKit.normalised(entry.checkpoints), label)
		assert_eq(again.final, ReplayKit.normalised(entry.final), label)
