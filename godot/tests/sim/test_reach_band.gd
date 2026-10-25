## The reach band (#446, option B): on a board with a reach band a tower hits a ground foe on the
## centre line up to half the band further than its reach, a flying foe never, and with no band
## (every board but the wide layout valley) nothing moves. The boards here are the default game
## board with `reach_band` set by hand, because the stitcher does not switch the band on yet.
extends GutTest

const SPECS := preload("res://content/specs.gd")
const TOWERS := preload("res://content/towers.gd")

## A band 1 cell wide: a margin of half a cell either side of the centre line.
const BAND := 1.0
## Just inside and just outside the margin.
const INSIDE := 0.45
const OUTSIDE := 0.55


func _centre(game: GameState, tower: Tower) -> Vector2:
	return game.map.socket_centre(Vector2i(tower.col, tower.row))


## A foe that stands still `gap` cells east of `centre`, hp to spare.
func _foe_at(game: GameState, centre: Vector2, gap: float, type: String = "corrugatedOrc") -> Foe:
	var foe := TowerFireKit.foe(game, 10.0, type)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	# held, so the walk does not put it back on the road
	foe.engaged_guard_id = 1000000
	foe.x = centre.x + gap
	foe.y = centre.y
	return foe


func _top(type: String, spec: String) -> TowerFireKit.Scene:
	var scene := TowerFireKit.scene(type)
	scene.game.buttons = 100000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, spec))
	Game.tick(scene.game)
	scene.tower.cooldown = 0.0
	return scene


func _fired(game: GameState) -> int:
	return TowerFireKit.kinds(game, GameEvent.Kind.TOWER_FIRED).size()


func test_no_board_has_a_reach_band_until_the_stitcher_sets_one() -> void:
	for map_seed in [1, 2, 3]:
		var map := Game.create_on_strip_valley(map_seed).map
		assert_eq(map.reach_band, 0.0)
		assert_eq(map.reach_margin(), 0.0)
		assert_eq(map.road_width, 0.9, "the old width is not the band")
	var landscape := TowerFireKit.landscape(1).map
	assert_eq(landscape.reach_band, 0.0)


func test_the_margin_is_half_the_band() -> void:
	var map := Game.create_on_strip_valley(1).map
	map.reach_band = BAND
	assert_eq(map.reach_margin(), BAND / 2.0)


func test_with_no_band_the_ground_reach_is_the_reach_to_the_bit() -> void:
	var scene := TowerFireKit.scene()
	var foe := _foe_at(scene.game, _centre(scene.game, scene.tower), 1.0)
	var reach := TowerFire.reach_of(scene.game, scene.tower)
	assert_eq(TowerFire.ground_reach_of(scene.game, scene.tower), reach)
	assert_eq(TowerFire.reach_to(scene.game, scene.tower, foe), reach)


func test_a_ground_foe_just_past_the_reach_is_hit_only_with_a_band() -> void:
	var plain := TowerFireKit.scene()
	plain.game.map.reach_band = 0.0
	var reach := TowerFire.reach_of(plain.game, plain.tower)
	var foe := _foe_at(plain.game, _centre(plain.game, plain.tower), reach + INSIDE)
	Game.tick(plain.game)
	assert_eq(foe.hp, foe.max_hp, "out of reach without a band")
	assert_eq(_fired(plain.game), 0)
	var banded := TowerFireKit.scene()
	banded.game.map.reach_band = BAND
	var hit := _foe_at(banded.game, _centre(banded.game, banded.tower), reach + INSIDE)
	Game.tick(banded.game)
	assert_lt(hit.hp, hit.max_hp, "inside reach plus half the band")
	assert_eq(_fired(banded.game), 1)


func test_a_ground_foe_beyond_the_margin_is_left_alone() -> void:
	var scene := TowerFireKit.scene()
	scene.game.map.reach_band = BAND
	var reach := TowerFire.reach_of(scene.game, scene.tower)
	var foe := _foe_at(scene.game, _centre(scene.game, scene.tower), reach + OUTSIDE)
	Game.tick(scene.game)
	assert_eq(foe.hp, foe.max_hp)
	assert_eq(_fired(scene.game), 0)


func test_the_band_is_added_after_the_elevation_bonus() -> void:
	var scene := TowerFireKit.scene()
	scene.game.map.reach_band = BAND
	for socket in scene.game.map.sockets:
		if scene.game.map.elevation_at(socket) == 2:
			var high := Tower.new()
			high.type = "spoolGuard"
			high.col = socket.x
			high.row = socket.y
			assert_almost_eq(TowerFire.ground_reach_of(scene.game, high), 2.3 * 1.15 + 0.5, 1e-9)
			return
	fail_test("some socket is on high ground")


func test_a_flying_foe_gets_no_band() -> void:
	var scene := TowerFireKit.scene()
	scene.game.map.reach_band = BAND
	var reach := TowerFire.reach_of(scene.game, scene.tower)
	var moth := _foe_at(scene.game, _centre(scene.game, scene.tower), reach + INSIDE, "razorMoth")
	assert_eq(TowerFire.reach_to(scene.game, scene.tower, moth), reach)
	assert_eq(TowerFire.target_for(scene.game, scene.tower), null)
	moth.x = _centre(scene.game, scene.tower).x + reach - 0.05
	assert_eq(TowerFire.target_for(scene.game, scene.tower), moth, "still hit inside the reach")


func test_a_beam_lock_holds_while_the_foe_is_inside_the_margin() -> void:
	var scene := TowerFireKit.scene("prismSpire")
	scene.game.map.reach_band = BAND
	var reach := TowerFire.reach_of(scene.game, scene.tower)
	var foe := _foe_at(scene.game, _centre(scene.game, scene.tower), reach + INSIDE)
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, foe.id, "locked inside the margin")
	var after_lock := foe.hp
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, foe.id, "the lock holds as the target does")
	assert_lt(foe.hp, after_lock)
	var nearer := _foe_at(scene.game, _centre(scene.game, scene.tower), reach - 0.5)
	nearer.distance = foe.distance + 5.0
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, foe.id, "a foe in the margin keeps its lock")
	foe.x += OUTSIDE - INSIDE + 0.1
	Game.tick(scene.game)
	assert_eq(scene.tower.target_id, nearer.id, "past the margin the lock goes to the target")


func test_frostbite_counts_a_slowed_foe_inside_the_margin() -> void:
	var scene := _top("prismSpire", "cryoOrigamiSpire")
	var game := scene.game
	var reach := TowerFire.reach_of(game, scene.tower)
	var foe := _foe_at(game, _centre(game, scene.tower), reach + INSIDE)
	Status.apply_slow(foe, 0.3, 5.0)
	game.map.reach_band = 0.0
	assert_eq(Specs.frostbite_bonus(game, foe), 0.0, "no band, out of the spire's reach")
	game.map.reach_band = BAND
	assert_gt(Specs.frostbite_bonus(game, foe), 0.0, "inside the margin")
	foe.x += OUTSIDE - INSIDE
	assert_eq(Specs.frostbite_bonus(game, foe), 0.0, "past the margin")


func test_flash_freeze_reaches_a_foe_inside_the_margin() -> void:
	var scene := _top("prismSpire", "cryoOrigamiSpire")
	var game := scene.game
	game.map.reach_band = BAND
	var centre := _centre(game, scene.tower)
	var reach := TowerFire.reach_of(game, scene.tower)
	var inside := _foe_at(game, centre, reach + INSIDE)
	var outside := _foe_at(game, centre, reach + OUTSIDE)
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_gt(inside.freeze_timer, 0.0)
	assert_eq(outside.freeze_timer, 0.0)


func test_the_skewer_reaches_a_foe_inside_the_margin_and_the_bolt_runs_to_its_edge() -> void:
	var scene := _top("spoolGuard", "crossbowBallista")
	var game := scene.game
	game.map.reach_band = BAND
	var centre := _centre(game, scene.tower)
	var reach := TowerFire.reach_of(game, scene.tower)
	var inside := _foe_at(game, centre, reach + INSIDE)
	var outside := _foe_at(game, centre, reach + OUTSIDE)
	scene.tower.cooldown = 1000.0
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_lt(inside.hp, inside.max_hp)
	assert_eq(outside.hp, outside.max_hp)
	var event := TowerFireKit.kinds(game, GameEvent.Kind.ABILITY_USED)[0]
	assert_almost_eq(event.x2, centre.x + reach + BAND / 2.0, 1e-9)


func test_the_squadron_patrols_the_whole_margin() -> void:
	var scene := _top("spoolGuard", "paperPlaneAviary")
	var game := scene.game
	game.map.reach_band = BAND
	var reach := TowerFire.reach_of(game, scene.tower)
	var foe := _foe_at(game, _centre(game, scene.tower), reach + INSIDE)
	scene.tower.cooldown = 1000.0
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(game.zones.size(), 1)
	var every := int(float(SPECS.find("spoolGuard", "paperPlaneAviary").active.every) * 30.0) + 2
	for i in every:
		Game.tick(game)
	assert_lt(foe.hp, foe.max_hp, "a bomb fell on a foe only the band put in the patrol")


func test_the_precision_snipe_reaches_a_foe_inside_the_margin() -> void:
	for gap in [INSIDE, OUTSIDE]:
		var game := GuardKit.game_with_tent()
		var tent := GuardKit.tent(game)
		game.buttons = 100000
		Game.submit(game, Command.upgrade(tent.id))
		Game.submit(game, Command.upgrade(tent.id))
		Game.tick(game)
		Game.submit(game, Command.choose_spec(tent.id, "scissorRogues"))
		Game.tick(game)
		game.map.reach_band = BAND
		var foe := _foe_at(game, _centre(game, tent), TowerFire.reach_of(game, tent) + gap)
		for guard in game.guards:
			guard.cooldown = 1000.0
		Game.submit(game, Command.activate(tent.id))
		Game.tick(game)
		var used := GuardKit.events_of(game, GameEvent.Kind.ABILITY_USED).size()
		assert_eq(used, 1 if gap == INSIDE else 0, "gap %s past the reach" % gap)
		assert_eq(foe.hp < foe.max_hp, gap == INSIDE)


## A game with a Guard Tent and the anchor and gap of a level-0 socket whose block centre is
## between 0.1 and 0.4 cells past `reach` from the first guard's post: `[game, anchor, gap]`.
func _tent_with_socket_past(reach: float) -> Array:
	for map_seed in range(1, 40):
		var game := GuardKit.game_with_tent(map_seed)
		var at := game.routes[0].position_at(game.guards[0].post)
		for anchor in game.map.sockets:
			if anchor == Vector2i(game.towers[0].col, game.towers[0].row):
				continue
			if game.map.elevation_at(anchor) != 0:
				continue
			var gap := game.map.socket_centre(anchor).distance_to(Vector2(at.x, at.y))
			if gap >= reach + 0.1 and gap <= reach + 0.4:
				return [game, anchor, gap]
	return []


func test_the_mess_aura_holds_a_guard_post_inside_the_margin() -> void:
	var reach: float = TOWERS.DEFS.messTent.range[0]
	var found := _tent_with_socket_past(reach)
	assert_false(found.is_empty(), "some seed has a socket just past a level 1 aura")
	var game: GameState = found[0]
	var gap: float = found[2]
	game.map.reach_band = 0.0
	GameTestKit.run(game, [Command.build("messTent", found[1].x, found[1].y)])
	GuardKit.tick(game, 1)
	assert_eq(game.guards[0].speed_bonus, 0.0, "without a band the post is out of reach")
	game.map.reach_band = 2.0 * (gap - reach - 0.05)
	GuardKit.tick(game, 1)
	assert_eq(game.guards[0].speed_bonus, 0.0, "a band that falls short")
	game.map.reach_band = 2.0 * (gap - reach + 0.05)
	GuardKit.tick(game, 1)
	assert_gt(game.guards[0].speed_bonus, 0.0, "a band that reaches the post")


func test_fortified_feast_shields_a_guard_whose_post_is_inside_the_margin() -> void:
	var top: float = TOWERS.DEFS.messTent.range[2]
	var found := _tent_with_socket_past(top)
	assert_false(found.is_empty(), "some seed has a socket just past a level 3 aura")
	var game: GameState = found[0]
	var gap: float = found[2]
	game.buttons = 100000
	game.map.reach_band = 0.0
	GameTestKit.run(game, [Command.build("messTent", found[1].x, found[1].y)])
	var mess: Tower = game.towers[1]
	Game.submit(game, Command.upgrade(mess.id))
	Game.submit(game, Command.upgrade(mess.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(mess.id, "ironRations"))
	Game.tick(game)
	Game.submit(game, Command.activate(mess.id))
	Game.tick(game)
	assert_eq(game.guards[0].shield_hp, 0.0, "no band: the post is outside the aura")
	game.map.reach_band = 2.0 * (gap - top + 0.05)
	Game.submit(game, Command.activate(mess.id))
	Game.tick(game)
	assert_gt(game.guards[0].shield_hp, 0.0, "the band brings the post into the aura")


# --- areas around a point are not reaches: the band does not widen them ---


func test_a_mortar_blast_does_not_get_the_band() -> void:
	var scene := TowerFireKit.scene("thimbleMortar")
	var game := scene.game
	game.map.reach_band = BAND
	var centre := _centre(game, scene.tower)
	var splash: float = TOWERS.DEFS.thimbleMortar.splash[0]
	var target := _foe_at(game, centre, 1.0)
	target.distance = 20.0
	var beside := _foe_at(game, centre, 1.0 + splash - 0.05)
	var past := _foe_at(game, centre, 1.0 + splash + INSIDE)
	Game.tick(game)
	assert_lt(target.hp, target.max_hp, "the shell landed")
	assert_lt(beside.hp, beside.max_hp, "inside the blast")
	assert_eq(past.hp, past.max_hp, "just past the blast, inside what the band would add")


func test_a_pool_does_not_get_the_band() -> void:
	var scene := _top("thimbleMortar", "stickyGlueMortar")
	var game := scene.game
	game.map.reach_band = BAND
	var centre := _centre(game, scene.tower)
	var target := _foe_at(game, centre, 1.0)
	Game.tick(game)
	assert_eq(game.zones.size(), 1, "the shell left a pool")
	var pool: Zone = game.zones[0]
	scene.tower.cooldown = 1000.0
	var inside := _foe_at(game, Vector2(pool.x, pool.y), pool.radius - 0.05)
	var past := _foe_at(game, Vector2(pool.x, pool.y), pool.radius + INSIDE)
	Game.tick(game)
	assert_gt(target.slow, 0.0)
	assert_gt(inside.slow, 0.0, "inside the pool")
	assert_eq(past.slow, 0.0, "just past the pool")


func test_a_squadron_bomb_does_not_get_the_band() -> void:
	var scene := _top("spoolGuard", "paperPlaneAviary")
	var game := scene.game
	game.map.reach_band = BAND
	var centre := _centre(game, scene.tower)
	var reach := TowerFire.reach_of(game, scene.tower)
	var foe := _foe_at(game, centre, reach + INSIDE)
	scene.tower.cooldown = 1000.0
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	var zone: Zone = game.zones[0]
	# out of the patrol (past the margin), just past the bomb's blast from the foe the planes hit
	var past := _foe_at(game, centre, reach + INSIDE + zone.splash + INSIDE)
	var every := int(zone.every * 30.0) + 2
	for i in every:
		Game.tick(game)
	assert_lt(foe.hp, foe.max_hp, "the planes bombed the foe in the margin")
	assert_eq(past.hp, past.max_hp, "the blast stopped short of the foe past it")
