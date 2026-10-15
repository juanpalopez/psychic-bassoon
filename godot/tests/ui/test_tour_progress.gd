## The tour is shown once and remembered; it can be turned off for tests and the browser test.
extends GutTest


func test_an_unseen_tour_is_wanted_in_a_real_run() -> void:
	assert_true(TourProgress.wanted(false, "", false))


func test_a_seen_tour_is_not_shown_again() -> void:
	assert_false(TourProgress.wanted(true, "", false))


func test_the_tour_param_zero_and_headless_runs_turn_it_off() -> void:
	assert_false(TourProgress.wanted(false, "0", false))
	assert_false(TourProgress.wanted(false, "", true))
	assert_true(TourProgress.wanted(false, "1", false), "tour=1 shows it as usual")


func test_marking_the_tour_seen_is_remembered_by_the_store() -> void:
	var memory := {}
	var progress := TourProgress.new(
		func() -> bool: return memory.get("seen", false), func() -> void: memory["seen"] = true
	)
	assert_false(progress.seen())
	progress.mark_seen()
	assert_true(progress.seen())
	assert_true(memory.seen)
