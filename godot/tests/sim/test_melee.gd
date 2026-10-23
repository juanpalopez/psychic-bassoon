## The melee context: one fighter holds one foe and they trade blows. Shared by the Guard Tent's
## guards and, later, the hero; which foe a fighter may take is left to each of them.
extends GutTest

const TICK := 1.0 / 30.0


func _fighter() -> Fighter:
	var fighter := Fighter.new()
	fighter.id = 7
	fighter.hp = 100.0
	fighter.max_hp = 100.0
	fighter.damage = 10.0
	fighter.interval = 1.0
	return fighter


func _foe(id: int = 3) -> Foe:
	var foe := Foe.new()
	foe.id = id
	foe.hp = 1000.0
	foe.max_hp = 1000.0
	foe.attack_damage = 8.0
	foe.attack_interval = 0.5
	return foe


func test_hold_ties_the_foe_and_the_fighter_and_resets_both_cooldowns() -> void:
	var fighter := _fighter()
	var foe := _foe()
	fighter.cooldown = 0.4
	foe.attack_cooldown = 0.3
	Melee.hold(fighter, foe)
	assert_eq(foe.engaged_guard_id, 7)
	assert_eq(fighter.foe_id, 3)
	assert_eq(fighter.cooldown, 0.0)
	assert_eq(foe.attack_cooldown, 0.0)
	Melee.release(foe, fighter)
	assert_eq(foe.engaged_guard_id, -1)
	assert_eq(fighter.foe_id, -1)


func test_held_foe_is_the_living_foe_it_holds() -> void:
	var game := GameState.new()
	var fighter := _fighter()
	var other := _foe(2)
	var foe := _foe(3)
	game.foes.append(other)
	game.foes.append(foe)
	assert_null(Melee.held_foe(game, fighter), "it holds nothing")
	Melee.hold(fighter, foe)
	assert_eq(Melee.held_foe(game, fighter), foe)
	foe.alive = false
	assert_null(Melee.held_foe(game, fighter), "a fallen foe is not held")


func test_strike_hits_when_the_cooldown_runs_out_and_waits_out_the_interval() -> void:
	var game := GameState.new()
	var fighter := _fighter()
	var foe := _foe()
	game.foes.append(foe)
	Melee.hold(fighter, foe)
	assert_true(Melee.strike(game, fighter, foe, 0.0), "the first blow is at once")
	assert_eq(foe.hp, 990.0)
	assert_almost_eq(fighter.cooldown, 1.0 - TICK, 1e-12)
	var strikes := 0
	for i in 29:
		if Melee.strike(game, fighter, foe, 0.0):
			strikes += 1
	assert_eq(strikes, 1, "the next one comes a second later")
	assert_eq(foe.hp, 980.0)


func test_a_speed_bonus_shortens_the_wait() -> void:
	var game := GameState.new()
	var fighter := _fighter()
	var foe := _foe()
	game.foes.append(foe)
	Melee.strike(game, fighter, foe, 1.0)
	assert_almost_eq(fighter.cooldown, 0.5 - TICK, 1e-12)


func test_foe_strikes_on_its_own_cooldown_but_not_while_frozen_or_fallen() -> void:
	var foe := _foe()
	assert_true(Melee.foe_strikes(foe))
	assert_almost_eq(foe.attack_cooldown, 0.5 - TICK, 1e-12)
	foe.attack_cooldown = 0.25
	foe.freeze_timer = 1.0
	assert_false(Melee.foe_strikes(foe), "a frozen foe's blow waits for the ice")
	assert_eq(foe.attack_cooldown, 0.25, "its cooldown stands still")
	foe.freeze_timer = 0.0
	foe.attack_cooldown = 0.0
	foe.alive = false
	assert_false(Melee.foe_strikes(foe))


func test_blow_is_cut_by_armor_but_never_below_a_share() -> void:
	var foe := _foe()
	assert_eq(Melee.blow(foe, 3.0), 5.0)
	assert_eq(Melee.blow(foe, 100.0), 2.0)


func test_blind_miss_counts_a_tally() -> void:
	var foe := _foe()
	foe.blind = 0.5
	assert_false(Melee.blind_miss(foe))
	assert_true(Melee.blind_miss(foe))


func test_fall_releases_the_foe_and_waits_the_respawn() -> void:
	var fighter := _fighter()
	var foe := _foe()
	Melee.hold(fighter, foe)
	fighter.hp = -3.0
	Melee.fall(fighter, foe, 2.0 * TICK)
	assert_false(fighter.alive)
	assert_eq(fighter.hp, 0.0)
	assert_eq(foe.engaged_guard_id, -1)
	assert_eq(fighter.foe_id, -1)
	assert_false(Melee.wait_to_return(fighter))
	assert_true(Melee.wait_to_return(fighter), "it is back after the delay")
	assert_true(fighter.alive)
	assert_eq(fighter.hp, 100.0)
	assert_eq(fighter.respawn_timer, 0.0)
