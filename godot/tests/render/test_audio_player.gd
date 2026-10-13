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
	player.unlock()
	for i in 20:
		player.play_sfx("scissor_snap")
	assert_eq(player.sfx_played(), 1, "a crowd of kills in one tick is one snap")
	player.play_sfx("metal_snap")
	assert_eq(player.sfx_played(), 2)


func test_muting_silences_sounds_and_music() -> void:
	var player := _player()
	player.unlock()
	player.set_music("tier2_wave")
	player.set_muted(true)
	player.play_sfx("metal_snap")
	assert_eq(player.sfx_played(), 0)
	assert_true(player.is_muted())
	player.set_muted(false)
	assert_eq(player.playing_music(), "tier2_wave", "the music comes back")
