## A shot's hit shows when the drawn shot lands: the foe keeps its health, and a killed foe
## keeps standing, until then.
extends GutTest

const LANDS := 0.25


## One tick of a tower firing at a foe it can reach, with the hold told about it as main
## tells it: the frame before is observed, then the shot is held.
func _fire(scene: TowerFireKit.Scene, hold: HitHold, seconds: float = LANDS) -> GameEvent:
	hold.observe(scene.game)
	scene.tower.cooldown = 0.0
	Game.tick(scene.game)
	var fired := TowerFireKit.kinds(scene.game, GameEvent.Kind.TOWER_FIRED)
	assert_eq(fired.size(), 1, "the tower fired")
	hold.hold(scene.game, fired[0], seconds)
	for killed in TowerFireKit.kinds(scene.game, GameEvent.Kind.FOE_KILLED):
		hold.hold_kill(killed.foe_id)
	return fired[0]


func test_a_hit_foe_shows_its_health_until_the_shot_lands() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_fire(scene, hold)
	assert_lt(foe.hp, foe.max_hp, "the sim took the health off")
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.max_hp, "the drawn foe is not hit yet")
	assert_true(hold.is_held(foe.id))
	hold.advance(LANDS - 0.05)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.max_hp, "the shot is still flying")
	hold.advance(0.05)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp, "it has landed")
	assert_false(hold.is_held(foe.id))


func test_a_killed_foe_stands_until_its_shot_lands_and_then_snaps() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_fire(scene, hold)
	assert_false(scene.game.foes.has(foe), "the sim removed it")
	hold.observe(scene.game)
	assert_true(hold.drawn_foes(scene.game).has(foe), "it is still drawn")
	assert_true(hold.is_ghost(foe.id))
	assert_eq(hold.shown_hp(foe), 1.0)
	assert_eq(hold.take_landed_kills(), 0, "no snap yet")
	hold.advance(LANDS)
	assert_eq(hold.take_landed_kills(), 1, "the snap plays as it lands")
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe), "and it is gone")


func test_a_kill_that_lands_within_the_same_frame_still_snaps_once() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_fire(scene, hold)
	hold.advance(1.0)
	assert_eq(hold.take_landed_kills(), 1)
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe), "no ghost is left behind")


func test_a_blast_holds_every_foe_in_its_splash() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var first := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var second := TowerFireKit.foe(scene.game, scene.near + 0.2, "cardboardGolem")
	var hold := HitHold.new()
	_fire(scene, hold)
	assert_lt(first.hp, first.max_hp)
	assert_lt(second.hp, second.max_hp, "the blast hit both")
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(first), first.max_hp)
	assert_eq(hold.shown_hp(second), second.max_hp)
	hold.advance(LANDS)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(second), second.hp)


func test_two_shots_in_flight_each_show_their_own_hit_as_they_land() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_fire(scene, hold)
	var after_first := foe.hp
	hold.advance(0.1)
	_fire(scene, hold)
	assert_lt(foe.hp, after_first)
	hold.advance(LANDS - 0.1)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), after_first, "the first has landed, the second not yet")
	hold.advance(0.1)
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp)


func test_hurt_with_no_shot_shows_at_once() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	hold.observe(scene.game)
	foe.hp -= 10.0
	hold.observe(scene.game)
	assert_eq(hold.shown_hp(foe), foe.hp)
	assert_false(hold.hold_kill(foe.id), "a kill with no shot on its way is not held")


func test_a_foe_that_leaks_is_let_go() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near, "cardboardGolem")
	var hold := HitHold.new()
	_fire(scene, hold)
	hold.release(foe.id)
	hold.observe(scene.game)
	assert_false(hold.is_held(foe.id))
	assert_eq(hold.shown_hp(foe), foe.hp)


func test_reset_forgets_every_hold() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var foe := TowerFireKit.foe(scene.game, scene.near)
	foe.hp = 1.0
	var hold := HitHold.new()
	_fire(scene, hold)
	hold.observe(scene.game)
	hold.reset()
	hold.observe(scene.game)
	assert_false(hold.drawn_foes(scene.game).has(foe))
	assert_eq(hold.take_landed_kills(), 0)
