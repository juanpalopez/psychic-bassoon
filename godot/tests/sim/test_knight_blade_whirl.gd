extends GutTest

## Blade Whirl, the Knight's active (#452): an ACTIVATE_ABILITY command naming the hero hits every
## ground foe next to it with physical damage, then cools down for 15 seconds.

const HEROES := preload("res://content/heroes.gd")
const TOWERS := preload("res://content/towers.gd")


func _game(on_layout: bool = false) -> GameState:
	var game := Game.create(7) if on_layout else Game.create_on_strip_valley(7)
	# a walking hero holds no foe, so only the whirl hurts them; at speed 0 it stays put
	game.hero.speed = 0.0
	game.hero.path = [game.hero.cell + Vector2i(1, 0)] as Array[Vector2i]
	return game


## A foe of `type` standing `gap` cells from the hero, held still and out of the Knight's blows.
func _foe_near(game: GameState, type: String, gap: float) -> Foe:
	var foe := FoeSpawner.spawn(game, type, 1, 0)
	foe.speed = 0.0
	foe.x = game.hero.x + gap
	foe.y = game.hero.y
	return foe


func _whirl(game: GameState) -> Array[GameEvent]:
	return GameTestKit.run(game, [Command.activate(game.hero.id)])


func _reason(events: Array[GameEvent]) -> int:
	for event in events:
		if event.kind == GameEvent.Kind.COMMAND_REJECTED:
			return event.reason
	return -1


func test_the_numbers_live_in_the_hero_content() -> void:
	var whirl: Dictionary = HEROES.DEFS[HEROES.KNIGHT].blade_whirl
	assert_eq(whirl.cooldown, 15.0)
	assert_gt(whirl.damage, 0.0)
	assert_gt(whirl.radius, 0.0)


func test_it_hurts_adjacent_ground_foes_with_physical_damage() -> void:
	var game := _game()
	var foe := _foe_near(game, "corrugatedOrc", 0.6)
	var before := foe.hp
	var events := _whirl(game)
	assert_eq(_reason(events), -1)
	var whirl: Dictionary = HEROES.DEFS[HEROES.KNIGHT].blade_whirl
	var expected := Damage.after_defence(foe, float(whirl.damage), Damage.Kind.PHYSICAL)
	assert_almost_eq(before - foe.hp, expected, 1e-9)
	var used := false
	for event in events:
		used = used or event.kind == GameEvent.Kind.ABILITY_USED
	assert_true(used)


func test_foes_out_of_reach_and_flying_foes_are_spared() -> void:
	var game := _game()
	var near := _foe_near(game, "corrugatedOrc", 0.6)
	var far := _foe_near(game, "corrugatedOrc", 3.0)
	var moth := _foe_near(game, "razorMoth", 0.3)
	var far_hp := far.hp
	var moth_hp := moth.hp
	var near_hp := near.hp
	_whirl(game)
	assert_lt(near.hp, near_hp)
	assert_eq(far.hp, far_hp)
	assert_eq(moth.hp, moth_hp)


func test_it_hits_every_adjacent_foe_once() -> void:
	var game := _game()
	var first := _foe_near(game, "corrugatedOrc", 0.5)
	var second := _foe_near(game, "corrugatedOrc", -0.5)
	var hp := first.hp
	_whirl(game)
	assert_eq(first.hp, second.hp)
	assert_lt(first.hp, hp)


func test_it_is_refused_with_nobody_next_to_the_knight() -> void:
	var game := _game()
	_foe_near(game, "corrugatedOrc", 4.0)
	var events := _whirl(game)
	assert_eq(_reason(events), GameEvent.RejectReason.NO_TARGET)
	# nothing was spent: a foe arriving now can be whirled at once
	_foe_near(game, "corrugatedOrc", 0.5)
	assert_eq(_reason(_whirl(game)), -1)


func test_it_cools_down_for_fifteen_seconds() -> void:
	var game := _game()
	var foe := _foe_near(game, "corrugatedOrc", 0.6)
	foe.hp = 100000.0
	foe.max_hp = 100000.0
	_whirl(game)
	var after_first := foe.hp
	assert_eq(_reason(_whirl(game)), GameEvent.RejectReason.ABILITY_COOLING_DOWN)
	assert_eq(foe.hp, after_first)
	# 15 seconds is 450 ticks; the two commands above took the first two
	for i in 447:
		Game.tick(game)
	assert_eq(_reason(_whirl(game)), GameEvent.RejectReason.ABILITY_COOLING_DOWN)
	# the foe walked on in 15 seconds; bring it back next to the Knight
	foe.x = game.hero.x + 0.6
	foe.y = game.hero.y
	assert_eq(_reason(_whirl(game)), -1)


func test_a_fallen_knight_cannot_whirl() -> void:
	var game := _game()
	_foe_near(game, "corrugatedOrc", 0.6)
	game.hero.alive = false
	game.hero.respawn_timer = 100.0
	assert_eq(_reason(_whirl(game)), GameEvent.RejectReason.HERO_FALLEN)


func test_a_command_naming_nothing_is_still_refused() -> void:
	var game := _game()
	var events := GameTestKit.run(game, [Command.activate(999999)])
	assert_eq(_reason(events), GameEvent.RejectReason.NO_SUCH_TOWER)


func test_the_whirl_can_finish_a_foe_and_pays_its_reward() -> void:
	var game := _game()
	var foe := _foe_near(game, "scrapGoblin", 0.4)
	foe.hp = 1.0
	var before := game.buttons
	var events := _whirl(game)
	assert_false(foe.alive)
	assert_gt(game.buttons, before)
	var killed := false
	for event in events:
		killed = killed or event.kind == GameEvent.Kind.FOE_KILLED
	assert_true(killed)


## Adjacent is the whirl's radius plus the Knight's and the foe's bodies, from the centres, on
## every board: the road band's reach margin (1.0 on the layout valley) does not widen it.
func test_the_reach_is_the_radii_and_not_the_road_band() -> void:
	var whirl: Dictionary = HEROES.DEFS[HEROES.KNIGHT].blade_whirl
	for on_layout in [false, true]:
		var label := "layout" if on_layout else "strip"
		var probe := _game(on_layout)
		assert_eq(probe.map.reach_margin() > 0.0, on_layout, label)
		var edge: float = (
			float(whirl.radius) + probe.hero.radius + _foe_near(probe, "corrugatedOrc", 0.0).radius
		)
		var inside := _game(on_layout)
		var near := _foe_near(inside, "corrugatedOrc", edge - 0.01)
		var near_hp := near.hp
		assert_eq(_reason(_whirl(inside)), -1, label + ": just inside")
		assert_lt(near.hp, near_hp, label + ": just inside is hit")
		var outside := _game(on_layout)
		var far := _foe_near(outside, "corrugatedOrc", edge + 0.01)
		var far_hp := far.hp
		assert_eq(
			_reason(_whirl(outside)), GameEvent.RejectReason.NO_TARGET, label + ": just outside"
		)
		assert_eq(far.hp, far_hp, label + ": just outside is spared")


## The cooldown is a clock of the Knight and runs while it is fallen too (`Heroes.fight` counts it
## down before it looks at `alive`), so a Knight that returns after 15 seconds can whirl at once.
func test_the_cooldown_keeps_counting_while_the_knight_is_fallen() -> void:
	var game := _game()
	var foe := _foe_near(game, "corrugatedOrc", 0.6)
	foe.hp = 100000.0
	foe.max_hp = 100000.0
	_whirl(game)
	assert_gt(game.hero.ability_cooldown, 0.0)
	game.hero.alive = false
	game.hero.respawn_timer = 1000.0
	for i in 460:
		Game.tick(game)
	assert_eq(game.hero.ability_cooldown, 0.0)
