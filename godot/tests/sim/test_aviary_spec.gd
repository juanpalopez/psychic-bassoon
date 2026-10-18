## Tier 4 for the Spool Guard's second spec, the Paper-Plane Aviary: High Recon (adjacent towers see
## 20 percent further) and Squadron Launch (three paper planes patrol and drop dart bombs).
extends GutTest

const SPECS := preload("res://content/specs.gd")
const TOWERS := preload("res://content/towers.gd")

const AVIARY := "paperPlaneAviary"


func _scene(existing: GameState = null) -> TowerFireKit.Scene:
	var scene := TowerFireKit.scene("spoolGuard", 1, false, existing)
	scene.game.buttons = 100000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	Game.submit(scene.game, Command.choose_spec(scene.tower.id, AVIARY))
	Game.tick(scene.game)
	scene.tower.cooldown = 1000.0
	return scene


func _tough(game: GameState, along: float, type: String = "corrugatedOrc") -> Foe:
	var foe := TowerFireKit.foe(game, along, type)
	foe.hp = 1.0e9
	foe.max_hp = 1.0e9
	return foe


## A tower of `type` at the socket `anchor`, put straight into the list.
func _tower_at(game: GameState, type: String, anchor: Vector2i, level: int = 0) -> Tower:
	var tower := Tower.new()
	tower.id = game.next_id
	game.next_id += 1
	tower.type = type
	tower.level = level
	tower.col = anchor.x
	tower.row = anchor.y
	tower.cooldown = 1000.0
	game.towers.append(tower)
	return tower


## A socket whose block touches the tower's (within the content's gap) and one that does not.
func _neighbour_and_stranger(game: GameState, tower: Tower) -> Array:
	var gap: float = SPECS.find("spoolGuard", AVIARY).passive.gap
	var here := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var near := Vector2i(-1, -1)
	var far := Vector2i(-1, -1)
	for socket in game.map.sockets:
		if socket == Vector2i(tower.col, tower.row):
			continue
		var there := game.map.socket_centre(socket)
		var reach := float(game.map.footprint) + gap
		if absf(there.x - here.x) <= reach and absf(there.y - here.y) <= reach:
			near = socket
		elif absf(there.x - here.x) > reach + 1.0 or absf(there.y - here.y) > reach + 1.0:
			far = socket
	return [near, far]


func test_the_content_gives_the_spool_guard_a_second_spec() -> void:
	var specs: Array = SPECS.for_tower("spoolGuard")
	assert_eq(specs.size(), 2)
	assert_eq(specs[1].id, AVIARY)
	assert_eq(specs[1].passive.kind, "recon")
	assert_eq(specs[1].active.kind, "squadron")


func test_adjacent_blocks_are_within_the_gap_on_both_axes() -> void:
	var a := Vector2(2.0, 1.0)
	# footprint 2 and gap 1: up to 3 cells between centres on each axis
	assert_true(Specs.adjacent(a, Vector2(2.0, 4.0), 2.0, 1.0), "straight below, exactly the gap")
	assert_true(Specs.adjacent(a, Vector2(5.0, 4.0), 2.0, 1.0), "diagonal")
	assert_false(Specs.adjacent(a, Vector2(2.0, 4.01), 2.0, 1.0), "just past the gap")
	assert_false(Specs.adjacent(a, Vector2(6.0, 1.0), 2.0, 1.0), "past it on one axis only")
	assert_true(Specs.adjacent(a, Vector2(4.0, 2.0), 1.0, 1.0), "a 1-cell footprint map")
	assert_false(Specs.adjacent(a, Vector2(4.5, 2.0), 1.0, 1.0))


func test_high_recon_widens_the_reach_of_a_tower_next_to_the_aviary_only() -> void:
	var scene := _scene()
	var game := scene.game
	var bonus: float = SPECS.find("spoolGuard", AVIARY).passive.bonus
	var sockets := _neighbour_and_stranger(game, scene.tower)
	assert_ne(sockets[0], Vector2i(-1, -1), "a neighbouring socket exists on this map")
	var neighbour := _tower_at(game, "thimbleMortar", sockets[0], 1)
	var base: float = (
		float(TOWERS.DEFS.thimbleMortar.range[1])
		* game.map.range_multiplier(Vector2i(neighbour.col, neighbour.row))
	)
	assert_almost_eq(TowerFire.reach_of(game, neighbour), base * (1.0 + bonus), 1e-9)
	# a tower of no spec and a tower far away: no bonus
	if sockets[1] != Vector2i(-1, -1):
		var stranger := _tower_at(game, "thimbleMortar", sockets[1], 1)
		var plain: float = (
			float(TOWERS.DEFS.thimbleMortar.range[1])
			* game.map.range_multiplier(Vector2i(stranger.col, stranger.row))
		)
		assert_almost_eq(TowerFire.reach_of(game, stranger), plain, 1e-9, "across the board")
	var own: float = (
		float(TOWERS.DEFS.spoolGuard.range[2])
		* game.map.range_multiplier(Vector2i(scene.tower.col, scene.tower.row))
	)
	assert_almost_eq(TowerFire.reach_of(game, scene.tower), own, 1e-9, "not for the Aviary itself")


func test_two_aviaries_do_not_add_up() -> void:
	var scene := _scene()
	var game := scene.game
	var bonus: float = SPECS.find("spoolGuard", AVIARY).passive.bonus
	var sockets := _neighbour_and_stranger(game, scene.tower)
	var neighbour := _tower_at(game, "thimbleMortar", sockets[0], 1)
	var second := _tower_at(game, "spoolGuard", sockets[0], 2)
	second.spec = AVIARY
	second.col = scene.tower.col
	second.row = scene.tower.row
	var base: float = (
		float(TOWERS.DEFS.thimbleMortar.range[1])
		* game.map.range_multiplier(Vector2i(neighbour.col, neighbour.row))
	)
	assert_almost_eq(TowerFire.reach_of(game, neighbour), base * (1.0 + bonus), 1e-9)


# --- Squadron Launch ---


func test_squadron_launch_needs_a_foe_in_reach() -> void:
	var scene := _scene()
	Game.submit(scene.game, Command.activate(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(
		TowerFireKit.kinds(scene.game, GameEvent.Kind.COMMAND_REJECTED)[0].reason,
		GameEvent.RejectReason.NO_TARGET
	)
	assert_eq(scene.game.zones.size(), 0)


func test_the_squadron_drops_a_bomb_per_plane_each_interval_and_then_leaves() -> void:
	var scene := _scene()
	var game := scene.game
	var active: Dictionary = SPECS.find("spoolGuard", AVIARY).active
	var lead := _tough(game, scene.near + 0.3)
	var rear := _tough(game, scene.near - 0.3)
	var away: Array = TowerFireKit.farthest_from(scene)
	var far := _tough(game, float(away[0]))
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(game.zones.size(), 1)
	assert_eq(game.zones[0].kind, "squadron")
	var fired := 0
	var bombs := 0
	var ticks := int(float(active.seconds) * 30.0) + 5
	for i in ticks:
		Game.tick(game)
		for event in TowerFireKit.kinds(game, GameEvent.Kind.TOWER_FIRED):
			if event.tower_id == scene.tower.id:
				bombs += 1
		fired += 1
	assert_eq(game.zones.size(), 0, "the squadron has gone home")
	var drops := int(float(active.seconds) / float(active.every))
	assert_eq(bombs, drops * int(active.planes), "one bomb per plane per drop")
	assert_lt(lead.hp, lead.max_hp)
	assert_lt(rear.hp, rear.max_hp)
	assert_eq(far.hp, far.max_hp, "out of the patrol")


func test_a_bomb_hits_a_flyer_and_applies_frostbite_like_any_tower_damage() -> void:
	# the 16 by 11 board's map 1, where the moth's straight line passes the tower
	var scene := _scene(TowerFireKit.landscape())
	var game := scene.game
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.hp = 1.0e9
	moth.max_hp = 1.0e9
	# a foe stands where its distance puts it, so hold the moth at the point of its line nearest
	# the tower (put on the tower, it went back to its line's start on the first tick)
	var centre := game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	var line := game.air_routes[0]
	var gap := INF
	var along := 0.0
	while along <= line.total:
		var point := line.position_at(along)
		var here := centre.distance_to(Vector2(point.x, point.y))
		if here < gap:
			gap = here
			moth.distance = along
		along += 0.05
	var at := line.position_at(moth.distance)
	moth.x = at.x
	moth.y = at.y
	assert_lt(gap, TowerFire.reach_of(game, scene.tower), "the moth's line passes in reach")
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	for i in 40:
		Game.tick(game)
	assert_lt(moth.hp, moth.max_hp, "an anti-air tower's planes hit a flyer")


func test_the_squadron_is_the_same_game_every_time() -> void:
	var snapshots := []
	for run in 2:
		var scene := _scene()
		_tough(scene.game, scene.near)
		_tough(scene.game, scene.near + 0.4)
		Game.submit(scene.game, Command.activate(scene.tower.id))
		for i in 400:
			Game.tick(scene.game)
		snapshots.append(GameTestKit.snapshot(scene.game))
	assert_eq(snapshots[0], snapshots[1])


func test_the_aviary_scenario_matches_its_golden() -> void:
	var file := FileAccess.open(SpecScenario.AVIARY_GOLDEN_PATH, FileAccess.READ)
	assert_not_null(file, "run tools/write_specs_golden.gd")
	# JSON turns whole numbers into floats, so compare after the same round trip
	var round_trip = JSON.parse_string(JSON.stringify(SpecScenario.play_aviary(), "\t", true))
	assert_eq(round_trip, JSON.parse_string(file.get_as_text()))


func test_a_bomb_carries_frostbite_from_a_cryo_spire() -> void:
	var scene := _scene()
	var game := scene.game
	var foe := _tough(game, scene.near)
	foe.freeze_timer = 3.0
	var spire := _tower_at(game, "prismSpire", Vector2i(scene.tower.col, scene.tower.row), 2)
	spire.spec = "cryoOrigamiSpire"
	var bonus: float = SPECS.find("prismSpire", "cryoOrigamiSpire").passive.bonus
	var zone := Zone.new()
	zone.tower_id = scene.tower.id
	zone.damage = 18.0
	zone.splash = 0.1
	var before := foe.hp
	Zones._bomb(game, zone, foe)
	assert_almost_eq(before - foe.hp, (18.0 - float(foe.armor)) * (1.0 + bonus), 1e-6)


func test_a_plane_skips_a_foe_an_earlier_bomb_of_the_drop_killed() -> void:
	var scene := _scene()
	var game := scene.game
	var lead := _tough(game, scene.near + 0.4)
	lead.hp = 1.0
	var rear := _tough(game, scene.near - 0.4)
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	var bombs: Array[GameEvent] = []
	for i in 40:
		Game.tick(game)
		bombs.append_array(TowerFireKit.kinds(game, GameEvent.Kind.TOWER_FIRED))
	assert_lt(rear.hp, rear.max_hp, "the survivors still get bombed")
	var on_lead := 0
	for event in bombs:
		if event.foe_id == lead.id:
			on_lead += 1
	assert_eq(on_lead, 1, "one bomb killed the lead and none fell on it afterwards")
