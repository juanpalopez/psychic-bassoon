## Blind: a foe misses a share of its melee blows by a tally, never by a random number.
extends GutTest


func _misses(share: float, blows: int) -> Array[int]:
	var foe := Foe.new()
	foe.blind = share
	var at: Array[int] = []
	for i in blows:
		if Barracks._blind_miss(foe):
			at.append(i + 1)
	return at


func test_a_share_of_0_4_misses_the_third_and_fifth_blow_of_five() -> void:
	assert_eq(_misses(0.4, 5), [3, 5])


func test_a_share_whose_sum_drifts_still_misses_exactly_once_in_ten() -> void:
	# ten times 0.1 is 0.9999999999999999 in floating point, and still counts as a whole
	assert_eq(_misses(0.1, 10), [10])
	assert_eq(_misses(0.1, 20), [10, 20])


func test_no_blind_never_misses() -> void:
	assert_eq(_misses(0.0, 50), [])


func test_apply_blind_sets_and_a_stronger_or_equal_one_restarts_it() -> void:
	var foe := Foe.new()
	Status.apply_blind(foe, 0.4, 6.0)
	assert_eq(foe.blind, 0.4)
	assert_eq(foe.blind_timer, 6.0)
	Status.apply_blind(foe, 0.2, 9.0)
	assert_eq(foe.blind, 0.4, "a weaker blind is ignored")
	assert_eq(foe.blind_timer, 6.0)
	foe.blind_timer = 2.0
	Status.apply_blind(foe, 0.4, 6.0)
	assert_eq(foe.blind_timer, 6.0, "an equal one restarts the timer")
	Status.apply_blind(foe, 0.6, 3.0)
	assert_eq(foe.blind, 0.6, "a stronger one replaces it")
	assert_eq(foe.blind_timer, 3.0)


func test_apply_blind_ignores_no_share_no_time_and_nan() -> void:
	var foe := Foe.new()
	Status.apply_blind(foe, 0.0, 5.0)
	Status.apply_blind(foe, 0.4, 0.0)
	Status.apply_blind(foe, NAN, 5.0)
	Status.apply_blind(foe, 0.4, NAN)
	assert_eq(foe.blind, 0.0)
	assert_eq(foe.blind_timer, 0.0)


func test_a_blind_that_ends_forgets_its_tally() -> void:
	var game := GameState.new()
	var foe := Foe.new()
	game.foes.append(foe)
	Status.apply_blind(foe, 0.4, 0.1)
	assert_false(Barracks._blind_miss(foe))
	assert_gt(foe.miss_tally, 0.0)
	for i in 5:
		Status.step_blind(game)
	assert_eq(foe.blind, 0.0)
	assert_eq(foe.miss_tally, 0.0, "the next blind starts from nothing")


func test_a_blind_foe_in_a_fight_hurts_the_guard_only_on_the_blows_that_land() -> void:
	var game := GuardKit.game_with_tent()
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	GuardKit.tick(game, 3)
	var guard: Guard = (
		game.guards[0] if game.guards[0].id == foe.engaged_guard_id else game.guards[1]
	)
	guard.hp = 1.0e9
	guard.max_hp = 1.0e9
	foe.blind = 0.5
	foe.blind_timer = 1000.0
	foe.miss_tally = 0.0
	foe.attack_cooldown = 0.0
	var blow := maxf(foe.attack_damage * 0.25, foe.attack_damage - float(guard.armor))
	var before := guard.hp
	var interval := foe.attack_interval
	# four blows: two land (every second one misses at a share of 0.5)
	GuardKit.tick(game, int(interval * 30.0 * 3.0) + 2)
	assert_almost_eq(before - guard.hp, 2.0 * blow, 1e-6)
