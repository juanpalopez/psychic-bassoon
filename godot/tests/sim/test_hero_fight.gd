extends GutTest

## The Knight holds foes, trades blows, breaks off, falls and returns (#451).

const HEROES := preload("res://content/heroes.gd")
const SEED := 42
const FAR := 3.0


func _game() -> GameState:
	var game := Game.create(SEED, 16, 11)
	Heroes.place(game, HEROES.KNIGHT)
	return game


## A foe of `type` on the main route, with the hero standing `gap` cells before it.
func _foe_with_hero_near(game: GameState, type: String, gap: float) -> Foe:
	var foe := FoeSpawner.spawn(game, type, 1, 0)
	foe.distance = 2.0
	var at := game.routes[0].position_at(foe.distance)
	foe.x = at.x
	foe.y = at.y
	_stand(game, at.x - gap, at.y)
	return foe


func _stand(game: GameState, x: float, y: float) -> void:
	game.hero.x = x
	game.hero.y = y
	game.hero.cell = Vector2i(int(floor(x)), int(floor(y)))
	game.hero.path = [] as Array[Vector2i]


func _tick(game: GameState, count: int) -> void:
	for i in count:
		Game.tick(game)


func _count(game: GameState, kind: GameEvent.Kind) -> int:
	var found := 0
	for event in game.events:
		if event.kind == kind:
			found += 1
	return found


func test_a_standing_knight_holds_a_foe_in_reach() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	_tick(game, 1)
	assert_eq(foe.engaged_guard_id, game.hero.id)
	assert_eq(game.hero.foe_id, foe.id)
	assert_eq(_count(game, GameEvent.Kind.HERO_ENGAGED), 1)


func test_a_knight_out_of_reach_holds_nothing() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", FAR)
	_tick(game, 1)
	assert_eq(foe.engaged_guard_id, -1)
	assert_eq(game.hero.foe_id, -1)


func test_a_walking_knight_holds_nothing() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	game.hero.path = [game.hero.cell + Vector2i(0, 1)] as Array[Vector2i]
	Heroes.fight(game)
	assert_eq(foe.engaged_guard_id, -1)


func test_flying_unblockable_and_held_foes_are_skipped() -> void:
	var game := _game()
	var moth := _foe_with_hero_near(game, "razorMoth", 0.3)
	var golem := _foe_with_hero_near(game, "cardboardGolem", 0.3)
	var held := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	held.engaged_guard_id = 9999
	moth.x = game.hero.x
	moth.y = game.hero.y
	golem.x = game.hero.x
	golem.y = game.hero.y
	held.x = game.hero.x
	held.y = game.hero.y
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, -1)
	assert_eq(held.engaged_guard_id, 9999)


func test_the_nearest_foe_is_taken() -> void:
	var game := _game()
	var near := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	var far := _foe_with_hero_near(game, "corrugatedOrc", 0.6)
	far.x = near.x + 0.2
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, near.id)


func test_a_tie_goes_to_the_lower_id_whatever_the_array_order() -> void:
	var game := _game()
	var first := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	var second := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	second.x = first.x
	second.y = first.y
	game.foes = [second, first] as Array[Foe]
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, first.id)


func test_reach_ends_exactly_at_the_two_bodies_and_the_reach() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	game.hero.radius = 0.25
	foe.radius = 0.25
	_stand(game, 4.0, 4.0)
	foe.x = 4.0 + 0.5 + HEROES.REACH
	foe.y = 4.0
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, foe.id, "on the edge is in reach")
	var past := _game()
	var other := _foe_with_hero_near(past, "corrugatedOrc", 0.3)
	past.hero.radius = 0.25
	other.radius = 0.25
	_stand(past, 4.0, 4.0)
	other.x = 4.0 + 0.5 + HEROES.REACH + 0.01
	other.y = 4.0
	Heroes.fight(past)
	assert_eq(past.hero.foe_id, -1, "just past is out")


func test_a_flying_foe_that_is_blockable_is_skipped() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	foe.flying = true
	assert_true(foe.blockable)
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, -1)


func test_a_knight_at_the_heartstone_holds_a_foe_that_would_leak() -> void:
	var game := Game.create(SEED)
	var foe := FoeSpawner.spawn(game, "corrugatedOrc", 1, 0)
	foe.x = game.hero.x
	foe.y = game.hero.y
	foe.distance = game.routes[0].total - 0.1
	Game.tick(game)
	assert_eq(foe.engaged_guard_id, game.hero.id)
	assert_eq(game.heartstone_health, 20)


func test_a_fall_while_walking_stops_the_walk() -> void:
	var game := _game()
	game.hero.path = [game.hero.cell + Vector2i(0, 1)] as Array[Vector2i]
	game.hero.hp = 0.0
	Heroes.fight(game)
	assert_false(game.hero.alive, "exactly 0 hp falls")
	assert_true(game.hero.path.is_empty())
	# and a fall that holds nothing clears the held id
	var fighter := Fighter.new()
	fighter.foe_id = 7
	Melee.fall(fighter, null, 5.0)
	assert_eq(fighter.foe_id, -1)
	assert_false(fighter.alive)


func test_a_chaser_taken_back_strikes_once_in_that_tick() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	game.hero.chaser_id = foe.id
	foe.attack_cooldown = 0.0
	var hp := game.hero.hp
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, foe.id, "taken back")
	assert_eq(hp - game.hero.hp, Melee.blow(foe, float(game.hero.armor)))


func test_a_retaken_chaser_strikes_once_a_tick() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	_tick(game, 1)
	assert_eq(game.hero.foe_id, foe.id)
	GameTestKit.run(game, [Command.move_hero(game.hero.cell.x, game.hero.cell.y)] as Array[Command])
	for i in 120:
		if game.hero.foe_id == foe.id:
			break
		Game.tick(game)
	assert_eq(game.hero.foe_id, foe.id, "held again")
	foe.attack_cooldown = 0.5
	Game.tick(game)
	assert_almost_eq(foe.attack_cooldown, 0.5 - Game.TICK_SECONDS, 1e-9)


func test_a_knight_killed_by_its_chaser_does_not_engage_or_strike() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	var other := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	# standing at a cell centre, so the order to its own cell ends in the same tick
	_stand(game, floorf(foe.x) + 0.5, foe.y)
	foe.x = game.hero.x + 0.3
	foe.y = game.hero.y
	other.x = game.hero.x + 0.35
	other.y = game.hero.y
	_tick(game, 1)
	assert_eq(game.hero.foe_id, foe.id)
	game.hero.hp = 0.1
	foe.attack_cooldown = 0.0
	var foe_hp := foe.hp
	var other_hp := other.hp
	# the order's own tick: the released foe strikes, the hero (path empty at once) could re-engage
	GameTestKit.run(game, [Command.move_hero(game.hero.cell.x, game.hero.cell.y)] as Array[Command])
	assert_false(game.hero.alive)
	assert_eq(_count(game, GameEvent.Kind.HERO_ENGAGED), 0)
	assert_eq(foe.hp, foe_hp)
	assert_eq(other.hp, other_hp)


func test_blows_are_traded_with_armor() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	var foe_hp := foe.hp
	var hero_hp := game.hero.hp
	_tick(game, 1)
	var armor := float(HEROES.DEFS[HEROES.KNIGHT].armor)
	var expected := Melee.blow(foe, armor)
	assert_lt(foe.hp, foe_hp, "the knight struck")
	assert_eq(game.hero.hp, hero_hp - expected)
	assert_gt(expected, 0.0)


func test_the_held_foe_is_released_when_it_dies() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "scrapGoblin", 0.3)
	_tick(game, 2)
	assert_false(foe.alive)
	assert_eq(game.hero.foe_id, -1)
	assert_eq(foe.engaged_guard_id, -1)


func test_a_move_order_breaks_off_and_the_foe_keeps_striking_only_in_reach() -> void:
	var game := _game()
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	_tick(game, 1)
	assert_eq(game.hero.foe_id, foe.id)
	game.hero.path = [] as Array[Vector2i]
	Game.submit(game, Command.move_hero(game.hero.cell.x, game.hero.cell.y))
	# an order to its own cell is a move: the foe is released and remembered as the chaser
	foe.attack_cooldown = 0.0
	var hp := game.hero.hp
	Game.tick(game)
	assert_eq(foe.engaged_guard_id, -1)
	assert_eq(game.hero.foe_id, -1)
	assert_lt(game.hero.hp, hp, "the foe still strikes while in reach")
	foe.x += FAR
	foe.attack_cooldown = 0.0
	hp = game.hero.hp
	Heroes.fight(game)
	assert_eq(game.hero.chaser_id, -1, "out of reach, the chase is over")
	assert_eq(game.hero.hp, hp)


func test_the_knight_falls_rejects_orders_and_rises_at_home() -> void:
	var game := _game()
	var home := game.hero.cell
	var foe := _foe_with_hero_near(game, "corrugatedOrc", 0.3)
	_tick(game, 1)
	game.hero.hp = 0.5
	foe.attack_cooldown = 0.0
	_tick(game, 1)
	assert_false(game.hero.alive)
	assert_eq(_count(game, GameEvent.Kind.HERO_FELL), 1)
	assert_eq(foe.engaged_guard_id, -1)
	GameTestKit.run(game, [Command.move_hero(home.x, home.y)] as Array[Command])
	var rejected := false
	for event in game.events:
		if event.kind == GameEvent.Kind.COMMAND_REJECTED:
			rejected = event.reason == GameEvent.RejectReason.HERO_FALLEN
	assert_true(rejected)
	var respawn := float(HEROES.DEFS[HEROES.KNIGHT].respawn)
	var rose := false
	for i in int(respawn / Game.TICK_SECONDS) + 5:
		Game.tick(game)
		if _count(game, GameEvent.Kind.HERO_ROSE) > 0:
			rose = true
			break
	assert_true(rose)
	assert_true(game.hero.alive)
	assert_eq(game.hero.hp, game.hero.max_hp)
	assert_eq(game.hero.cell, Heroes._home(game))


func test_the_hero_id_is_unique_among_guards() -> void:
	var game := Game.create(SEED)
	game.buttons = 5000
	var anchor := game.map.sockets[0]
	GameTestKit.run(game, [Command.build("guardTent", anchor.x, anchor.y)])
	var ids := {game.hero.id: true}
	for guard in game.guards:
		assert_false(ids.has(guard.id))
		ids[guard.id] = true
	assert_false(ids.has(game.towers[0].id))


func test_the_same_seed_and_commands_give_the_same_fight() -> void:
	var a := _game()
	var b := _game()
	for game in [a, b]:
		_foe_with_hero_near(game, "corrugatedOrc", 0.3)
		_tick(game, 60)
	assert_eq(GameTestKit.snapshot(a).hash(), GameTestKit.snapshot(b).hash(), "same state")
	assert_ne(a.hero.hp, a.hero.max_hp, "and it was a fight")


func test_ordering_the_hero_to_its_own_cell_mid_leg_walks_it_back() -> void:
	var game := _game()
	var start := game.hero.cell
	var next := Vector2i(-1, -1)
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if game.hero_graph.is_open(start + step):
			next = start + step
			break
	assert_ne(next, Vector2i(-1, -1))
	GameTestKit.run(game, [Command.move_hero(next.x, next.y)] as Array[Command])
	_tick(game, 3)
	assert_ne(Vector2(game.hero.x, game.hero.y), Vector2(start) + Vector2(0.5, 0.5))
	GameTestKit.run(game, [Command.move_hero(start.x, start.y)] as Array[Command])
	var arrived := false
	for i in 90:
		Game.tick(game)
		if _count(game, GameEvent.Kind.HERO_ARRIVED) > 0:
			arrived = true
			break
	assert_true(arrived)
	assert_eq(Vector2(game.hero.x, game.hero.y), Vector2(start) + Vector2(0.5, 0.5))
