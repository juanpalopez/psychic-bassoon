## A shot's hit shows when the drawn shot lands: the foe keeps its health, and a killed foe
## keeps standing (with the Golem's goblins inside it), until then.
extends GutTest

const DART := 3.0 / 12.0
const PELLET := 4.0 / 12.0


## One tick with a tower firing, told to the hold as main tells it: the frame before is
## observed, the tick is wrapped in before_tick and after_tick, and each shot is held to land
## `seconds` from now.
func _tick(scene: TowerFireKit.Scene, hold: HitHold, seconds: float = DART) -> void:
	hold.observe(scene.game)
	for tower in scene.game.towers:
		tower.cooldown = 0.0
	hold.before_tick(scene.game)
	Game.tick(scene.game)
	for event in scene.game.events:
		if event.kind == GameEvent.Kind.TOWER_FIRED:
			hold.hold(event, seconds)
		elif event.kind == GameEvent.Kind.FOE_KILLED:
			hold.hold_kill(event.foe_id)
		elif event.kind == GameEvent.Kind.FOE_LEAKED:
			hold.release(event.foe_id)
	hold.after_tick(scene.game)


func test_a_hit_foe_shows_its_health_until_the_shot_lands() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_tick(scene, hold)
	assert_lt(foe.hp, foe.max_hp, "the sim took the health off")
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.max_hp, "the drawn foe is not hit yet")
	hold.advance(DART - 0.05)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.max_hp, "the shot is still flying")
	hold.advance(0.05)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp, "it has landed")
	assert_false(hold.is_held(foe.id))


func test_a_killed_foe_stands_until_its_shot_lands_and_then_snaps_once() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_tick(scene, hold)
	assert_false(scene.game.foes.has(foe), "the sim removed it")
	hold.observe(scene.game)
	assert_true(hold.drawn_foes(scene.game).has(foe), "it is still drawn")
	assert_true(hold.is_ghost(foe.id))
	assert_eq(hold.shown_hp(foe), 1.0)
	assert_eq(hold.take_landed_kills(), 0, "no snap yet")
	hold.advance(DART)
	assert_eq(hold.take_landed_kills(), 1, "the snap plays as it lands")
	hold.advance(DART)
	assert_eq(hold.take_landed_kills(), 0, "and only once")
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe), "and it is gone")


func test_a_kill_that_lands_within_the_same_frame_still_snaps() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_tick(scene, hold)
	hold.advance(1.0)
	assert_eq(hold.take_landed_kills(), 1)
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe), "no ghost is left behind")


func test_a_blast_holds_the_foes_it_hurt_and_no_others() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var first := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var second := TowerFireKit.foe(scene.game, scene.near + 0.2, "cardboardGolem")
	var moth := TowerFireKit.foe(scene.game, scene.near + 0.1, "razorMoth")
	var hold := HitHold.new()
	_tick(scene, hold, PELLET)
	assert_lt(second.hp, second.max_hp, "the blast hit both on the ground")
	assert_eq(moth.hp, moth.max_hp, "the mortar cannot hit a flying foe")
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(first), first.max_hp)
	assert_eq(hold.shown_hp(second), second.max_hp)
	assert_false(hold.is_held(moth.id), "a foe the blast did not hurt is not held")
	hold.advance(PELLET)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(second), second.hp)


func test_a_foe_that_leaks_beside_a_blast_is_not_held_or_drawn() -> void:
	# map 5 of the 16 by 11 board has a socket within the mortar's reach of the end of the road
	var scene := TowerFireKit.scene("thimbleMortar", 5, true, TowerFireKit.landscape(5))
	var total := scene.game.routes[0].total
	var leaker := TowerFireKit.foe(scene.game, total - 0.01, "cardboardGolem")
	leaker.speed = 1.0
	var target := TowerFireKit.foe(scene.game, total - 0.3, "cardboardGolem")
	var hold := HitHold.new()
	_tick(scene, hold, PELLET)
	assert_eq(TowerFireKit.kinds(scene.game, GameEvent.Kind.FOE_LEAKED).size(), 1, "it leaked")
	assert_lt(target.hp, target.max_hp, "the blast went off beside it")
	assert_false(hold.is_held(leaker.id))
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(leaker), "it is not drawn back")


func test_two_shots_in_flight_each_show_their_own_hurt_as_they_land() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_tick(scene, hold)
	var after_first := foe.hp
	hold.advance(0.1)
	_tick(scene, hold)
	assert_lt(foe.hp, after_first)
	hold.advance(DART - 0.1)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), after_first, "the first has landed, the second not yet")
	hold.advance(0.1)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp)


func test_a_later_shot_that_lands_first_shows_only_its_own_hurt() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_tick(scene, hold, PELLET)
	var after_slow := foe.hp
	hold.advance(1.0 / 12.0)
	_tick(scene, hold, 1.0 / 12.0)
	var fast_hurt := after_slow - foe.hp
	hold.advance(1.0 / 12.0)
	hold.observe(scene.game)
	assert_almost_eq(hold.shown_hp(foe), foe.max_hp - fast_hurt, 1e-4, "only the fast one")
	hold.advance(PELLET)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp, "then both")


func test_two_shots_in_one_tick_show_the_ticks_hurt_with_the_last_to_land() -> void:
	var scene := TowerFireKit.pair("spoolGuard", "spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	hold.observe(scene.game)
	scene.tower.cooldown = 0.0
	scene.second.cooldown = 0.0
	hold.before_tick(scene.game)
	Game.tick(scene.game)
	var fired := TowerFireKit.kinds(scene.game, GameEvent.Kind.TOWER_FIRED)
	assert_eq(fired.size(), 2, "both towers fired in the tick")
	hold.hold(fired[0], DART)
	hold.hold(fired[1], PELLET)
	hold.after_tick(scene.game)
	hold.advance(DART)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.max_hp, "the first to land shows nothing yet")
	hold.advance(PELLET - DART)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp, "the last shows the whole tick")


func test_a_golems_goblins_stay_inside_it_until_it_falls() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var golem := TowerFireKit.foe(scene.game, scene.near + 1.0, "cardboardGolem")
	golem.hp = 1.0
	var hold := HitHold.new()
	_tick(scene, hold)
	assert_false(scene.game.foes.has(golem), "the sim killed it")
	assert_gt(scene.game.foes.size(), 0, "and its goblins are out")
	hold.observe(scene.game)
	var drawn := hold.drawn_foes(scene.game)
	assert_true(drawn.has(golem), "it still stands")
	for foe in scene.game.foes:
		assert_false(drawn.has(foe), "its goblins are still inside")
	hold.advance(DART)
	hold.observe(scene.game)
	drawn = hold.drawn_foes(scene.game)
	assert_false(drawn.has(golem))
	for foe in scene.game.foes:
		assert_true(drawn.has(foe), "they come out as it falls")


func test_hurt_with_no_shot_shows_at_once() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	hold.observe(scene.game)
	foe.hp -= 10.0
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp)
	assert_false(hold.hold_kill(foe.id), "a kill with no shot on its way is not held")


func test_reset_forgets_every_hold() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_tick(scene, hold)
	hold.observe(scene.game)
	hold.reset()
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe))
	assert_eq(hold.take_landed_kills(), 0)
