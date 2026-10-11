## The speed the player picked: 1x, 2x, 3x, or paused. Speed only changes how
## many ticks run per frame; pause runs none.
extends GutTest


func test_it_starts_at_normal_speed_and_running() -> void:
	var speed := GameSpeed.new()
	assert_eq(speed.speed, 1)
	assert_false(speed.paused)
	assert_eq(speed.ticks_speed(), 1)


func test_choosing_a_speed_sets_it() -> void:
	var speed := GameSpeed.new()
	speed.choose(3)
	assert_eq(speed.ticks_speed(), 3)
	speed.choose(2)
	assert_eq(speed.ticks_speed(), 2)


func test_a_speed_that_is_not_offered_is_ignored() -> void:
	var speed := GameSpeed.new()
	speed.choose(2)
	speed.choose(4)
	speed.choose(0)
	speed.choose(-1)
	assert_eq(speed.speed, 2)


func test_pause_runs_no_ticks_and_resume_keeps_the_speed() -> void:
	var speed := GameSpeed.new()
	speed.choose(3)
	speed.toggle_pause()
	assert_true(speed.paused)
	assert_eq(speed.ticks_speed(), 0)
	speed.toggle_pause()
	assert_false(speed.paused)
	assert_eq(speed.ticks_speed(), 3)


func test_choosing_a_speed_while_paused_resumes() -> void:
	var speed := GameSpeed.new()
	speed.toggle_pause()
	speed.choose(2)
	assert_false(speed.paused)
	assert_eq(speed.ticks_speed(), 2)
