## Towers shoot: each tick, after the foes move, a tower whose cooldown is up
## fires at the foe nearest the kingdom within its reach. Everything goes
## through `Game.tick` and the game's public state.
extends GutTest

const TOWERS := preload("res://content/towers.gd")


## A game with one tower of `type` built (cooldown 0) on the level-0 socket
## nearest the road, and a way to put a foe on the road in its reach.
class Scene:
	extends RefCounted
	var game: GameState
	var tower: Tower
	var near: float = 0.0
	var gap: float = 0.0


func _scene(type: String = "spoolGuard", map_seed: int = 1) -> Scene:
	var scene := Scene.new()
	scene.game = Game.create(map_seed)
	var route := scene.game.routes[0]
	var best_socket := Vector2i(-1, -1)
	scene.gap = INF
	for socket in scene.game.map.sockets:
		if scene.game.map.elevation_at(socket) != 0:
			continue
		var centre := Vector2(float(socket.x) + 0.5, float(socket.y) + 0.5)
		var along := 0.0
		while along <= route.total:
			var point := route.position_at(along)
			var gap := centre.distance_to(Vector2(point.x, point.y))
			if gap < scene.gap:
				scene.gap = gap
				scene.near = along
				best_socket = socket
			along += 0.05
	Game.submit(scene.game, Command.build(type, best_socket.x, best_socket.y))
	Game.tick(scene.game)
	scene.tower = scene.game.towers[0]
	# the build tick already let the tower look for a target: nothing was there
	scene.tower.cooldown = 0.0
	return scene


## A foe standing still on route 0 at `along`, `type` of wave 1.
func _foe(game: GameState, along: float, type: String = "scrapGoblin", route: int = 0) -> Foe:
	var foe := FoeSpawner.spawn(game, type, 1, route)
	foe.speed = 0.0
	foe.distance = along
	var point := game.routes[route].position_at(along)
	foe.x = point.x
	foe.y = point.y
	return foe


func _kinds(game: GameState, kind: GameEvent.Kind) -> Array[GameEvent]:
	var found: Array[GameEvent] = []
	for event in game.events:
		if event.kind == kind:
			found.append(event)
	return found


func test_the_scene_puts_the_tower_within_reach_of_the_road() -> void:
	var scene := _scene()
	assert_lt(scene.gap, 2.3, "within a Spool Guard's reach")
	assert_eq(scene.game.map.elevation_at(Vector2i(scene.tower.col, scene.tower.row)), 0)


func test_a_foe_in_reach_is_hit_and_the_shot_is_reported() -> void:
	var scene := _scene()
	var foe := _foe(scene.game, scene.near)
	Game.tick(scene.game)
	assert_eq(foe.hp, 11.0, "20 hp less 9 physical damage, no armor")
	var shots := _kinds(scene.game, GameEvent.Kind.TOWER_FIRED)
	assert_eq(shots.size(), 1)
	assert_eq(shots[0].tower_id, scene.tower.id)
	assert_eq(shots[0].foe_id, foe.id)
	assert_eq([shots[0].x, shots[0].y], [foe.x, foe.y])
	assert_eq(shots[0].splash, 0.0)


func test_a_foe_out_of_reach_is_left_alone() -> void:
	var scene := _scene()
	var route := scene.game.routes[0]
	var centre := Vector2(float(scene.tower.col) + 0.5, float(scene.tower.row) + 0.5)
	# the point of the road farthest from the tower
	var farthest := 0.0
	var gap := 0.0
	var along := 0.0
	while along <= route.total:
		var point := route.position_at(along)
		if centre.distance_to(Vector2(point.x, point.y)) > gap:
			gap = centre.distance_to(Vector2(point.x, point.y))
			farthest = along
		along += 0.05
	assert_gt(gap, 2.3, "some of the road is out of reach")
	var foe := _foe(scene.game, farthest)
	Game.tick(scene.game)
	assert_eq(foe.hp, 20.0)
	assert_eq(_kinds(scene.game, GameEvent.Kind.TOWER_FIRED).size(), 0)


func test_the_reach_is_the_levels_range_times_the_elevation_bonus() -> void:
	var scene := _scene()
	assert_eq(TowerFire.reach_of(scene.game, scene.tower), 2.3)
	scene.tower.level = 2
	assert_eq(TowerFire.reach_of(scene.game, scene.tower), 3.0)
	for socket in scene.game.map.sockets:
		if scene.game.map.elevation_at(socket) == 2:
			var high := Tower.new()
			high.type = "spoolGuard"
			high.col = socket.x
			high.row = socket.y
			assert_almost_eq(TowerFire.reach_of(scene.game, high), 2.3 * 1.15, 1e-9)
			return
	fail_test("no level 2 socket on seed 1")


func test_a_level_2_socket_reaches_a_foe_a_level_0_socket_would_miss() -> void:
	for map_seed in range(1, 80):
		var game := Game.create(map_seed)
		var route := game.routes[0]
		for socket in game.map.sockets:
			if game.map.elevation_at(socket) != 2:
				continue
			var centre := Vector2(float(socket.x) + 0.5, float(socket.y) + 0.5)
			var along := 0.0
			while along <= route.total:
				var point := route.position_at(along)
				var gap := centre.distance_to(Vector2(point.x, point.y))
				if gap > 2.3 + 0.05 and gap < 2.3 * 1.15 - 0.05:
					Game.submit(game, Command.build("spoolGuard", socket.x, socket.y))
					Game.tick(game)
					var foe := _foe(game, along)
					Game.tick(game)
					assert_lt(foe.hp, 20.0, "seed %d, gap %f" % [map_seed, gap])
					return
				along += 0.05
	fail_test("no level 2 socket with a road point in the bonus band")


func test_the_foe_nearest_the_kingdom_is_the_target() -> void:
	var scene := _scene()
	var behind := _foe(scene.game, scene.near - 0.3)
	var ahead := _foe(scene.game, scene.near + 0.3)
	Game.tick(scene.game)
	assert_eq(ahead.hp, 11.0)
	assert_eq(behind.hp, 20.0)


func test_a_tie_goes_to_the_foe_that_spawned_first() -> void:
	var scene := _scene()
	var first := _foe(scene.game, scene.near)
	var second := _foe(scene.game, scene.near)
	assert_lt(first.id, second.id)
	Game.tick(scene.game)
	assert_eq(first.hp, 11.0)
	assert_eq(second.hp, 20.0)


func test_foes_on_different_routes_are_compared_by_distance_left() -> void:
	var scene := _scene()
	var game := scene.game
	assert_gt(game.routes.size(), 1, "this seed has a detour")
	var centre := Vector2(float(scene.tower.col) + 0.5, float(scene.tower.row) + 0.5)
	var far := _foe(game, 1.0, "scrapGoblin", 0)
	var close := _foe(game, 1.0, "scrapGoblin", 1)
	# both stand at the tower; what differs is how far each has left to walk
	for foe in [far, close]:
		foe.x = centre.x
		foe.y = centre.y
	far.distance = 1.0
	close.distance = 1.0 + (game.routes[1].total - game.routes[0].total) + 0.5
	var left_far := game.routes[0].total - far.distance
	var left_close := game.routes[1].total - close.distance
	assert_lt(left_close, left_far)
	assert_eq(TowerFire.target_for(game, scene.tower), close)
	# and the other way round
	close.distance = 1.0
	far.distance = 1.0 + (game.routes[0].total - game.routes[1].total) + 0.5
	assert_eq(TowerFire.target_for(game, scene.tower), far)


func test_a_fallen_foe_is_not_a_target() -> void:
	var scene := _scene()
	var dead := _foe(scene.game, scene.near + 0.3)
	dead.alive = false
	var alive := _foe(scene.game, scene.near)
	assert_eq(TowerFire.target_for(scene.game, scene.tower), alive)


func test_a_tower_with_no_foe_in_reach_has_no_target() -> void:
	var scene := _scene()
	assert_null(TowerFire.target_for(scene.game, scene.tower))


func _shot_ticks(scene: Scene, foe: Foe, ticks: int) -> Array[int]:
	var at: Array[int] = []
	for i in ticks:
		var before := foe.hp
		Game.tick(scene.game)
		if foe.hp < before:
			at.append(i)
	return at


func test_a_tower_fires_at_its_rate_not_every_tick() -> void:
	var scene := _scene()
	var foe := _foe(scene.game, scene.near, "cardboardGolem")
	var at := _shot_ticks(scene, foe, 90)
	# 3 shots a second for 3 seconds: 9 or 10 shots, 10 or 11 ticks apart
	assert_between(at.size(), 9, 10)
	for i in range(1, at.size()):
		assert_between(at[i] - at[i - 1], 10, 11)


func test_an_upgrade_speeds_the_rate_up() -> void:
	var scene := _scene()
	scene.game.buttons = 1000
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.submit(scene.game, Command.upgrade(scene.tower.id))
	Game.tick(scene.game)
	assert_eq(scene.tower.level, 2)
	scene.tower.cooldown = 0.0
	var foe := _foe(scene.game, scene.near, "cardboardGolem")
	var at := _shot_ticks(scene, foe, 90)
	# 4.5 shots a second: about 7 ticks apart
	assert_between(at.size(), 13, 14)
	for i in range(1, at.size()):
		assert_between(at[i] - at[i - 1], 6, 7)


func test_a_kill_pays_buttons_reports_it_and_removes_the_foe() -> void:
	var scene := _scene()
	var foe := _foe(scene.game, scene.near)
	foe.hp = 5.0
	var buttons := scene.game.buttons
	Game.tick(scene.game)
	assert_false(foe.alive)
	assert_eq(scene.game.buttons, buttons + foe.reward)
	assert_eq(scene.game.foes.size(), 0)
	var kinds: Array[int] = []
	for event in scene.game.events:
		kinds.append(event.kind)
	assert_eq(
		kinds, [GameEvent.Kind.TOWER_FIRED, GameEvent.Kind.FOE_KILLED], "shot first, then the kill"
	)


func test_a_foe_killed_on_its_last_step_does_not_leak() -> void:
	var scene := _scene()
	var route := scene.game.routes[0]
	var foe := _foe(scene.game, scene.near)
	foe.hp = 5.0
	var health := scene.game.kingdom_health
	Game.tick(scene.game)
	assert_eq(scene.game.kingdom_health, health)
	assert_lt(foe.distance, route.total)


func test_a_mortar_shell_hurts_every_foe_within_its_splash() -> void:
	var scene := _scene("thimbleMortar")
	var game := scene.game
	var target := _foe(game, scene.near + 0.2, "corrugatedOrc")
	var beside := _foe(game, scene.near + 0.2, "corrugatedOrc")
	var far := _foe(game, scene.near - 3.0, "corrugatedOrc")
	var centre := Vector2(target.x, target.y)
	assert_gt(centre.distance_to(Vector2(far.x, far.y)), 0.95, "outside the blast")
	Game.tick(game)
	# 32 physical damage against 4 armor
	assert_eq(target.hp, 130.0 - 28.0)
	assert_eq(beside.hp, 130.0 - 28.0)
	assert_eq(far.hp, 130.0)
	var shots := _kinds(game, GameEvent.Kind.TOWER_FIRED)
	assert_eq(shots.size(), 1)
	assert_eq(shots[0].splash, 0.95)


func test_a_prism_spire_fires_no_shots() -> void:
	# the beam comes in a later ticket; until then the tower stays quiet
	var scene := _scene("prismSpire")
	var foe := _foe(scene.game, scene.near)
	for i in 30:
		Game.tick(scene.game)
	assert_eq(foe.hp, 20.0)
	assert_eq(_kinds(scene.game, GameEvent.Kind.TOWER_FIRED).size(), 0)


func test_firing_draws_no_random_numbers() -> void:
	var with_tower := _scene()
	var without := Game.create(1)
	for game in [with_tower.game, without]:
		Game.submit(game, Command.launch_wave())
	for i in 600:
		Game.tick(with_tower.game)
		Game.tick(without)
	assert_eq(with_tower.game.rng.state, without.rng.state)
	assert_eq(with_tower.game.route_rng.state, without.route_rng.state)


func test_the_same_seed_and_commands_replay_the_same_with_towers() -> void:
	var snapshots: Array[Dictionary] = []
	for run in 2:
		var scene := _scene()
		Game.submit(scene.game, Command.launch_wave())
		for i in 900:
			Game.tick(scene.game)
		snapshots.append(GameTestKit.snapshot(scene.game))
	assert_eq(snapshots[0], snapshots[1])


func test_towers_clear_a_first_wave() -> void:
	var game := Game.create(1)
	var scene := _scene()
	game = scene.game
	game.buttons = 1000
	var built := 0
	for socket in game.map.sockets:
		if built >= 5:
			break
		if socket == Vector2i(scene.tower.col, scene.tower.row):
			continue
		if game.map.elevation_at(socket) == 0:
			Game.submit(game, Command.build("spoolGuard", socket.x, socket.y))
			built += 1
	Game.submit(game, Command.launch_wave())
	var cleared := false
	var kills := 0
	for i in 3000:
		Game.tick(game)
		kills += _kinds(game, GameEvent.Kind.FOE_KILLED).size()
		if not _kinds(game, GameEvent.Kind.WAVE_CLEARED).is_empty():
			cleared = true
			break
	assert_true(cleared, "wave 1 cleared")
	assert_gt(kills, 0)
