## The audio adapter starts nothing before the first tap, and then plays what it is told.
extends GutTest


func _player() -> AudioPlayer:
	var player := AudioPlayer.new()
	add_child_autofree(player)
	return player


func test_nothing_plays_before_the_first_tap() -> void:
	var player := _player()
	player.play_sfx("scissor_snap")
	player.set_music("tier2_wave")
	assert_false(player.is_unlocked())
	assert_eq(player.sfx_played(), 0)
	assert_eq(player.playing_music(), "")


func test_music_asked_for_before_the_tap_starts_after_it() -> void:
	var player := _player()
	player.set_music("tier2_wave")
	player.unlock()
	assert_true(player.is_unlocked())
	assert_eq(player.playing_music(), "tier2_wave")


func test_after_the_tap_a_sound_plays_and_music_switches() -> void:
	var player := _player()
	player.unlock()
	player.play_sfx("scissor_snap")
	assert_eq(player.sfx_played(), 1)
	player.set_music("tier1_planning")
	player.set_music("tier3_boss")
	assert_eq(player.playing_music(), "tier3_boss")


func test_the_same_sound_in_the_same_instant_plays_once() -> void:
	var player := _player()
	var now := [1000]
	player.clock = func() -> int: return now[0]
	player.unlock()
	for i in 20:
		player.play_sfx("scissor_snap")
	assert_eq(player.sfx_played(), 1, "a crowd of kills in one tick is one snap")
	player.play_sfx("metal_snap")
	assert_eq(player.sfx_played(), 2)
	now[0] += 59
	player.play_sfx("scissor_snap")
	assert_eq(player.sfx_played(), 2, "still inside the window")
	now[0] += 1
	player.play_sfx("scissor_snap")
	assert_eq(player.sfx_played(), 3, "a new snap once the window has passed")


func test_muting_silences_sounds_and_pauses_the_music() -> void:
	var player := _player()
	player.unlock()
	player.set_music("tier2_wave")
	assert_false(player.is_music_paused())
	player.set_muted(true)
	player.play_sfx("metal_snap")
	assert_eq(player.sfx_played(), 0)
	assert_true(player.is_muted())
	assert_true(player.is_music_paused())
	player.set_music("tier3_boss")
	assert_true(player.is_music_paused(), "a tune switched while muted stays paused")
	player.set_muted(false)
	assert_false(player.is_music_paused())
	assert_eq(player.playing_music(), "tier3_boss")


func test_muting_stops_effects_already_playing() -> void:
	var player := _player()
	player.unlock()
	player.play_sfx("paper_tear")
	assert_true(player.any_voice_playing())
	player.set_muted(true)
	assert_false(player.any_voice_playing())


func test_the_first_release_starts_the_music_again_once() -> void:
	var player := _player()
	player.unlock()
	player.set_music("tier1_planning")
	player.confirm_unlock()
	assert_eq(player.music_starts(), 2, "the tune, then the retry")
	player.confirm_unlock()
	assert_eq(player.music_starts(), 2, "only once")
