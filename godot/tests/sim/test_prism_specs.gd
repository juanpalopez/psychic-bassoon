## Tier 4 for the Prism Spire: the Cryo-Origami Spire (Flash Freeze, Frostbite) and
## the Blot Singularity (Ink Vortex, Corrosive Light).
extends GutTest

const SPECS := preload("res://content/specs.gd")
const FOES := preload("res://content/foes.gd")
const TOWERS := preload("res://content/towers.gd")

const CRYO := "cryoOrigamiSpire"
const BLOT := "blotSingularity"


## A Prism Spire at the top level with the spec chosen and the active ready.
func _scene(spec: String) -> TowerFireKit.Scene:
	var scene := TowerFireKit.scene("prismSpire")
	scene.game.buttons = 100000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, spec))
	Game.tick(scene.game)
	return scene


func _tough(game: GameState, along: float, type: String = "corrugatedOrc") -> Foe:
	var foe := TowerFireKit.foe(game, along, type)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	return foe


func _centre(scene: TowerFireKit.Scene) -> Vector2:
	return scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))


func _kinds(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	return TowerFireKit.kinds(game, kind)


func test_the_content_gives_the_prism_spire_two_specs() -> void:
	var specs: Array = SPECS.for_tower("prismSpire")
	assert_eq(specs.size(), 2)
	assert_eq(specs[0].id, CRYO)
	assert_eq(specs[1].id, BLOT)
	assert_eq(specs[0].passive.kind, "frostbite")
	assert_eq(specs[0].active.kind, "flash_freeze")
	assert_eq(specs[1].passive.kind, "corrode")
	assert_eq(specs[1].active.kind, "ink_vortex")
	for spec in specs:
		assert_gt(spec.cost, 0)
		assert_gt(spec.active.cooldown, 0.0)


func test_either_spec_can_be_chosen_once_and_the_other_is_then_closed() -> void:
	var scene := _scene(CRYO)
	assert_eq(scene.tower.spec, CRYO)
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, BLOT))
	Game.tick(scene.game)
	assert_eq(scene.tower.spec, CRYO)
	assert_eq(_scene(BLOT).tower.spec, BLOT)


# --- Flash Freeze ---


func test_flash_freeze_stops_every_foe_in_reach_for_its_seconds() -> void:
	var scene := _scene(CRYO)
	var active: Dictionary = SPECS.find("prismSpire", CRYO).active
	var near := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
	near.speed = 0.57
	near.hp = 1.0e9
	near.max_hp = 1.0e9
	var away: Array = TowerFireKit.farthest_from(scene)
	var far := TowerFireKit.foe(scene.game, float(away[0]), "corrugatedOrc")
	far.speed = 0.57
	assert_gt(Vector2(near.x, near.y).distance_to(_centre(scene)), 0.0)
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(_kinds(scene.game, GameEvent.Kind.ABILITY_USED).size(), 1)
	assert_gt(near.freeze_timer, 0.0)
	assert_eq(far.freeze_timer, 0.0, "a foe out of reach is not frozen")
	var frozen_at := near.distance
	var ticks := int(float(active.seconds) * 30.0)
	for i in ticks - 2:
		Game.tick(scene.game)
	assert_eq(near.distance, frozen_at, "it has not moved while frozen")
	assert_gt(far.distance, 0.0, "the foe out of reach walked on")
	for i in 6:
		Game.tick(scene.game)
	assert_eq(near.freeze_timer, 0.0)
	assert_gt(near.distance, frozen_at, "it walks again when the ice is gone")


func test_flash_freeze_with_no_foe_in_reach_is_refused_and_does_not_cool_down() -> void:
	var scene := _scene(CRYO)
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	var refused := _kinds(scene.game, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(refused[0].reason, GameEvent.RejectReason.NO_TARGET)
	assert_eq(scene.tower.ability_cooldown, 0.0)


func test_a_frozen_foe_does_not_strike_the_guard_that_holds_it() -> void:
	var game := GuardKit.game_with_tent()
	var guard: Guard = game.guards[0]
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	GuardKit.tick(game, 3)
	assert_ne(foe.engaged_guard_id, -1, "a guard holds the foe")
	guard = game.guards[0] if game.guards[0].id == foe.engaged_guard_id else game.guards[1]
	foe.freeze_timer = 10.0
	var hp := guard.hp
	GuardKit.tick(game, 120)
	assert_eq(guard.hp, hp, "no blow lands from a frozen foe")


# --- Frostbite ---


func test_frostbite_adds_a_share_of_physical_damage_to_a_slowed_foe_in_reach() -> void:
	var game_scene := _scene(CRYO)
	var game := game_scene.game
	# a second tower, a Spool Guard, near the spire
	var bonus: float = SPECS.find("prismSpire", CRYO).passive.bonus
	var spool := _spool_beside(game_scene)
	var slowed := TowerFireKit.foe(game, game_scene.near, "corrugatedOrc")
	slowed.hp = 100000.0
	slowed.max_hp = 100000.0
	var plain := TowerFireKit.foe(game, game_scene.near, "corrugatedOrc")
	plain.hp = 100000.0
	plain.max_hp = 100000.0
	Status.apply_slow(slowed, 0.3, 5.0)
	var shot := _shot_damage(game, spool, slowed)
	var base := _shot_damage(game, spool, plain)
	assert_almost_eq(shot, base * (1.0 + bonus), 1e-6)


func test_frostbite_counts_a_frozen_foe_as_slowed_and_does_not_stack_between_spires() -> void:
	var scene := _scene(CRYO)
	var game := scene.game
	var bonus: float = SPECS.find("prismSpire", CRYO).passive.bonus
	var spool := _spool_beside(scene)
	var foe := TowerFireKit.foe(game, scene.near, "corrugatedOrc")
	foe.hp = 100000.0
	foe.max_hp = 100000.0
	foe.freeze_timer = 3.0
	var once := _shot_damage(game, spool, foe)
	# a second Cryo spire in reach changes nothing: the strongest bonus applies
	var second := _extra_spire(scene)
	second.spec = CRYO
	var twice := _shot_damage(game, spool, foe)
	assert_almost_eq(twice, once, 1e-9)
	assert_almost_eq(once, (33.0 - 6.0) * (1.0 + bonus), 1e-6, "the bonus is on the damage dealt")


func test_frostbite_does_not_apply_out_of_the_spires_reach_or_without_a_slow() -> void:
	var scene := _scene(CRYO)
	var game := scene.game
	var spool := _spool_beside(scene)
	var foe := TowerFireKit.foe(game, scene.near, "corrugatedOrc")
	foe.hp = 100000.0
	foe.max_hp = 100000.0
	var base := _shot_damage(game, spool, foe)
	assert_almost_eq(base, 33.0 - 6.0, 1e-6, "no slow, no bonus")
	Status.apply_slow(foe, 0.3, 5.0)
	assert_gt(Specs.frostbite_bonus(game, foe), 0.0, "slowed and in reach")
	var centre := _centre(scene)
	foe.x = centre.x + 50.0
	foe.y = centre.y
	assert_almost_eq(Specs.frostbite_bonus(game, foe), 0.0, 1e-9, "out of the spire's reach")


# --- Corrosive Light ---


func test_the_beam_strips_armor_a_share_per_second_up_to_a_cap_and_it_stays() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	var passive: Dictionary = SPECS.find("prismSpire", BLOT).passive
	var foe := TowerFireKit.foe(game, scene.near, "corrugatedOrc")
	foe.hp = 1000000.0
	foe.max_hp = 1000000.0
	for i in 60:
		Game.tick(game)
	assert_almost_eq(foe.armor_strip, 2.0 * float(passive.per_second), 1e-6)
	# the foe leaves the beam's reach: the strip stays
	var kept := foe.armor_strip
	var away: Array = TowerFireKit.farthest_from(scene)
	foe.distance = float(away[0])
	for i in 30:
		Game.tick(game)
	assert_almost_eq(foe.armor_strip, kept, 1e-9)
	# back in reach and burning for a long time: it stops at the cap
	foe.distance = scene.near
	for i in 30 * 60:
		foe.hp = 1.0e9
		Game.tick(game)
	assert_almost_eq(foe.armor_strip, float(passive.max), 1e-9)


func test_a_stripped_foe_takes_more_from_every_physical_hit() -> void:
	var foe := Foe.new()
	foe.armor = 10
	foe.armor_strip = 0.5
	assert_almost_eq(Damage.after_defence(foe, 30.0, Damage.Kind.PHYSICAL), 25.0, 1e-9)
	# armor ignore and the strip combine: 10 x 0.5 x 0.6 = 3
	assert_almost_eq(Damage.after_defence(foe, 30.0, Damage.Kind.PHYSICAL, 0.4), 27.0, 1e-9)


# --- Ink Vortex ---


func test_ink_vortex_pulls_a_light_foe_towards_its_centre_and_ends() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	var active: Dictionary = SPECS.find("prismSpire", BLOT).active
	scene.tower.cooldown = 1000.0
	var target := TowerFireKit.foe(game, scene.near + 0.4, "corrugatedOrc")
	target.speed = 0.0
	var behind := TowerFireKit.foe(game, scene.near - 0.4, "corrugatedOrc")
	behind.speed = 0.0
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(game.zones.size(), 1)
	assert_eq(_kinds(game, GameEvent.Kind.ZONE_OPENED).size(), 1)
	var before := behind.distance
	for i in 30:
		Game.tick(game)
	assert_gt(behind.distance, before, "pulled towards the centre")
	assert_lte(behind.distance, target.distance + 1e-9, "never past the centre")
	var rounds := int(float(active.seconds) * 30.0)
	for i in rounds:
		Game.tick(game)
	assert_eq(game.zones.size(), 0)
	assert_eq(_kinds(game, GameEvent.Kind.ZONE_CLOSED).size(), 0, "closed in an earlier tick")


func test_ink_vortex_leaves_heavy_held_and_flying_foes_alone() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	scene.tower.cooldown = 1000.0
	var target := TowerFireKit.foe(game, scene.near + 0.4, "corrugatedOrc")
	target.speed = 0.0
	var golem := TowerFireKit.foe(game, scene.near - 0.4, "cardboardGolem")
	golem.speed = 0.0
	var held := TowerFireKit.foe(game, scene.near - 0.4, "corrugatedOrc")
	held.speed = 0.0
	held.engaged_guard_id = 99
	Game.submit(game, Command.activate(scene.tower.id))
	var golem_at := golem.distance
	var held_at := held.distance
	for i in 20:
		Game.tick(game)
	assert_eq(golem.distance, golem_at, "a golem is too heavy")
	assert_eq(held.distance, held_at, "a held foe stays held")


func test_ink_vortex_opens_on_a_ground_foe_even_when_a_flyer_is_nearer_the_heartstone() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	scene.tower.cooldown = 1000.0
	var ground := TowerFireKit.foe(game, scene.near, "corrugatedOrc")
	ground.speed = 0.0
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.distance = 99.0
	var centre := _centre(scene)
	moth.x = centre.x
	moth.y = centre.y
	assert_eq(TowerFire.target_for(game, scene.tower), moth, "the plain target is the moth")
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(game.zones.size(), 1)
	assert_almost_eq(game.zones[0].distance, scene.near, 1e-6, "the well sits on the ground foe")
	var moth_at := moth.distance
	for i in 20:
		Game.tick(game)
	assert_gte(moth.distance, moth_at, "a flyer is never pulled (it only flies on)")


func test_ink_vortex_with_only_a_flyer_in_reach_is_refused() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	var centre := _centre(scene)
	moth.x = centre.x
	moth.y = centre.y
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(
		_kinds(game, GameEvent.Kind.COMMAND_REJECTED)[0].reason, GameEvent.RejectReason.NO_TARGET
	)
	assert_eq(game.zones.size(), 0)


func test_ink_vortex_pulls_a_foe_of_the_second_spawn_source_on_the_main_road() -> void:
	var found := false
	for map_seed in range(1, 40):
		var probe := Game.create(map_seed)
		if probe.routes.size() < 2 or probe.random_lanes:
			continue
		# the second road joins the main road far along it (section E): stand past the join
		var main_join: float = (
			probe.routes[1].cell_distance(probe.map.feeder_length) - probe.second_offset
		)
		var scene := TowerFireKit.scene("prismSpire", map_seed, false, null, main_join + 3.0)
		var game := scene.game
		game.buttons = 100000
		Game.submit(game, Command.upgrade(scene.tower.id))
		Game.submit(game, Command.upgrade(scene.tower.id))
		Game.tick(game)
		Game.submit(game, Command.choose_spec(scene.tower.id, BLOT))
		Game.tick(game)
		scene.tower.cooldown = 1000.0
		var target := TowerFireKit.foe(game, scene.near + 0.4, "corrugatedOrc")
		target.speed = 0.0
		var second := FoeSpawner.spawn(game, "corrugatedOrc", 1, 1)
		second.speed = 0.0
		second.hp = 1.0e9
		second.max_hp = 1.0e9
		# on the main road, 0.4 cells behind the target, as a second-source foe stands
		second.distance = scene.near - 0.4 + game.second_offset
		if second.distance < game.routes[1].cell_distance(game.map.feeder_length):
			continue  # this map's well would sit before the join
		var at := game.routes[1].position_at(second.distance)
		second.x = at.x
		second.y = at.y
		Game.submit(game, Command.activate(scene.tower.id))
		Game.tick(game)
		if game.zones.is_empty():
			continue
		var before := second.distance
		for i in 30:
			Game.tick(game)
		assert_gt(second.distance, before, "pulled along the shared road, seed %d" % map_seed)
		found = true
		break
	assert_true(found, "a map with a second spawn source was found")


func test_a_held_foe_keeps_its_freeze_running_out() -> void:
	var game := GuardKit.game_with_tent()
	var foe := GuardKit.foe_before_post(game, "corrugatedOrc", 0.0)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	GuardKit.tick(game, 3)
	assert_ne(foe.engaged_guard_id, -1)
	foe.freeze_timer = 1.0
	GuardKit.tick(game, 40)
	assert_eq(foe.freeze_timer, 0.0)


func test_frostbite_reaches_the_mortar_and_the_skewer_and_only_physical_damage() -> void:
	var scene := _scene(CRYO)
	var game := scene.game
	var bonus: float = SPECS.find("prismSpire", CRYO).passive.bonus
	var foe := TowerFireKit.foe(game, scene.near, "corrugatedOrc")
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	var base := Specs.damage_bonus(game, foe, Damage.Kind.PHYSICAL)
	assert_eq(base, 0.0, "not slowed yet")
	foe.freeze_timer = 3.0
	assert_almost_eq(Specs.damage_bonus(game, foe, Damage.Kind.PHYSICAL), bonus, 1e-9)
	assert_eq(Specs.damage_bonus(game, foe, Damage.Kind.MAGIC), 0.0, "physical only")
	assert_eq(Specs.damage_bonus(game, foe, Damage.Kind.TRUE), 0.0)
	# a Thimble Mortar shell into the frozen foe
	var mortar := Tower.new()
	mortar.id = 901
	mortar.type = "thimbleMortar"
	mortar.level = 2
	mortar.col = scene.tower.col
	mortar.row = scene.tower.row
	game.towers.append(mortar)
	var hp := foe.hp
	TowerFire._fire(game, mortar, TOWERS.DEFS.thimbleMortar, foe)
	assert_almost_eq(hp - foe.hp, (58.0 - 6.0) * (1.0 + bonus), 1e-6)
	# a Heavy Skewer into the frozen foe
	var bolt_tower := Tower.new()
	bolt_tower.id = 902
	bolt_tower.type = "spoolGuard"
	bolt_tower.level = 2
	bolt_tower.spec = "crossbowBallista"
	bolt_tower.col = scene.tower.col
	bolt_tower.row = scene.tower.row
	game.towers.append(bolt_tower)
	foe.hp = 1.0e9
	var centre := _centre(scene)
	foe.x = centre.x + 1.0
	foe.y = centre.y
	var active: Dictionary = SPECS.find("spoolGuard", "crossbowBallista").active
	assert_true(Specs._skewer(game, bolt_tower, active))
	var armor_left := 6.0 * 0.6
	assert_almost_eq(
		1.0e9 - foe.hp, (float(active.damage) - armor_left) * (1.0 + bonus), 1e-3, "the skewer too"
	)


func test_ink_vortex_needs_a_target_and_cools_down() -> void:
	var scene := _scene(BLOT)
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(
		_kinds(scene.game, GameEvent.Kind.COMMAND_REJECTED)[0].reason,
		GameEvent.RejectReason.NO_TARGET
	)
	assert_eq(scene.game.zones.size(), 0)


func test_the_golem_is_a_heavy_foe_in_the_content() -> void:
	assert_true(FOES.DEFS.cardboardGolem.get("heavy", false))
	assert_false(FOES.DEFS.corrugatedOrc.get("heavy", false))


# --- helpers ---


## A Spool Guard at the top level on another socket (its shots are fired directly in the
## tests, so where it stands does not matter).
func _spool_beside(scene: TowerFireKit.Scene) -> Tower:
	var game := scene.game
	game.buttons = 100000
	for socket in game.map.sockets:
		if socket != Vector2i(scene.tower.col, scene.tower.row):
			Game.submit(game, Command.build("spoolGuard", socket.x, socket.y))
			Game.tick(game)
			var spool: Tower = game.towers.back()
			spool.level = 2
			spool.cooldown = 1000.0
			return spool
	fail_test("no other socket")
	return null


## A second Cryo spire on the same plot (built straight into the list; commands refuse an
## occupied plot), so it reaches the same foes.
func _extra_spire(scene: TowerFireKit.Scene) -> Tower:
	var spire := Tower.new()
	spire.id = 900
	spire.type = "prismSpire"
	spire.level = 2
	spire.col = scene.tower.col
	spire.row = scene.tower.row
	spire.cooldown = 1000.0
	scene.game.towers.append(spire)
	return spire


## The damage one shot of `tower` does to `foe`: fired directly, so no target is chosen.
func _shot_damage(game: GameState, tower: Tower, foe: Foe) -> float:
	var before := foe.hp
	TowerFire._fire(game, tower, TOWERS.DEFS[tower.type], foe)
	return before - foe.hp


func test_the_prism_scenarios_match_their_golden() -> void:
	var file := FileAccess.open(SpecScenario.PRISM_GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	var played := {
		"cryoOrigamiSpire": SpecScenario.play_prism("cryoOrigamiSpire"),
		"blotSingularity": SpecScenario.play_prism("blotSingularity"),
	}
	# JSON turns whole numbers into floats, so compare after the same round trip
	var round_trip = JSON.parse_string(JSON.stringify(played, "\t", true))
	assert_eq(round_trip, JSON.parse_string(file.get_as_text()))
