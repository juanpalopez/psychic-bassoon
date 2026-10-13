## Audio in the main scene: silent until the first press, then music follows the game.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _main() -> Node:
	var main := MAIN_SCENE.instantiate()
	add_child_autofree(main)
	return main


func _audio(main: Node) -> AudioPlayer:
	for child in main.get_children():
		if child is AudioPlayer:
			return child
	return null


func _press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press


func test_audio_is_locked_until_the_first_press() -> void:
	var main := _main()
	var audio := _audio(main)
	assert_not_null(audio)
	assert_false(audio.is_unlocked())
	main._input(_press())
	assert_true(audio.is_unlocked())


func test_a_release_does_not_unlock_audio() -> void:
	var main := _main()
	var release := _press()
	release.pressed = false
	main._input(release)
	assert_false(_audio(main).is_unlocked())


func test_the_planning_music_is_asked_for_at_the_start() -> void:
	var main := _main()
	main._process(0.016)
	main._input(_press())
	assert_eq(_audio(main).playing_music(), "tier1_planning")


func test_the_sound_button_mutes_and_unmutes() -> void:
	var main := _main()
	var button := main.get_node("Hud/Sound") as Button
	assert_true(button.button_pressed, "sound starts on")
	button.button_pressed = false
	assert_true(_audio(main).is_muted())
	button.button_pressed = true
	assert_false(_audio(main).is_muted())
