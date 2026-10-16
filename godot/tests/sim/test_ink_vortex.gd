## The Ink Vortex on the board: where a well sits (main-road distance, the second spawn source),
## who it pulls (never a flyer) and where the pulled foes end.
extends GutTest

const SPECS := preload("res://content/specs.gd")
const BLOT := "blotSingularity"


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


## A game with a second spawn source and a Blot spire, where a foe of the second road stands on
## the shared main road. Returns the scene, or null when this seed has no such road.
func _two_road_scene(map_seed: int) -> TowerFireKit.Scene:
	var probe := Game.create(map_seed)
	if probe.routes.size() < 2 or probe.random_lanes:
		return null
	var scene := TowerFireKit.scene("prismSpire", map_seed)
	var game := scene.game
	game.buttons = 100000
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.submit(game, Command.upgrade(scene.tower.id))
	Game.tick(game)
	Game.submit(game, Command.choose_spec(scene.tower.id, BLOT))
	Game.tick(game)
	scene.tower.cooldown = 1000.0
	return scene


func test_a_well_opened_on_a_second_road_foe_sits_at_its_main_road_distance() -> void:
	var checked := 0
	for map_seed in range(1, 40):
		var scene := _two_road_scene(map_seed)
		if scene == null:
			continue
		var game := scene.game
		var join: float = game.routes[1].cumulative[game.map.feeder_length + 1]
		var on_second := FoeSpawner.spawn(game, "corrugatedOrc", 1, 1)
		on_second.speed = 0.0
		on_second.distance = join + 1.0
		var at := game.routes[1].position_at(on_second.distance)
		on_second.x = at.x
		on_second.y = at.y
		var mover := _tough(game, scene.near)
		mover.speed = 0.0
		var centre := _centre(scene)
		if (
			Vector2(on_second.x, on_second.y).distance_to(centre)
			> TowerFire.reach_of(game, scene.tower)
		):
			continue
		Zones.open_vortex(game, scene.tower, on_second, 1.5, 1.2, 5.0)
		var want := Barracks.main_distance(game, on_second)
		assert_almost_eq(
			game.zones[0].distance, want, 1e-9, "main-road distance, seed %d" % map_seed
		)
		assert_ne(game.zones[0].distance, on_second.distance)
		checked += 1
		break
	assert_gt(checked, 0, "found a map where a second road foe stands in reach")


func test_a_flying_foe_inside_the_well_is_not_pulled() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	var target := _tough(game, scene.near)
	target.speed = 0.0
	Zones.open_vortex(game, scene.tower, target, 1.5, 1.2, 5.0)
	var moth := FoeSpawner.spawn(game, "razorMoth", 1, 0)
	moth.speed = 0.0
	moth.distance = scene.near + 3.0
	moth.x = target.x
	moth.y = target.y
	for i in 10:
		Zones.step(game)
	assert_eq(moth.distance, scene.near + 3.0, "the flyer's air-route distance is left alone")


func test_a_well_pulls_a_foe_to_its_centre_and_no_further() -> void:
	var scene := _scene(BLOT)
	var game := scene.game
	var target := _tough(game, scene.near + 0.4)
	target.speed = 0.0
	var behind := _tough(game, scene.near - 0.4)
	behind.speed = 0.0
	Zones.open_vortex(game, scene.tower, target, 1.5, 1.2, 5.0)
	for i in 90:
		Zones.step(game)
	assert_almost_eq(behind.distance, target.distance, 1e-9, "it ends at the centre")


func test_ink_vortex_with_only_a_feeder_foe_in_reach_is_refused() -> void:
	var scene := _two_road_scene(5)
	assert_not_null(scene, "seed 5 has a second spawn source")
	var game := scene.game
	var feeder := FoeSpawner.spawn(game, "corrugatedOrc", 1, 1)
	feeder.speed = 0.0
	feeder.distance = 0.2
	var centre := _centre(scene)
	feeder.x = centre.x
	feeder.y = centre.y
	assert_lt(Barracks.main_distance(game, feeder), 0.0, "still on the feeder")
	Game.submit(game, Command.activate(scene.tower.id))
	Game.tick(game)
	assert_eq(game.zones.size(), 0)
	assert_eq(
		_kinds(game, GameEvent.Kind.COMMAND_REJECTED)[0].reason, GameEvent.RejectReason.NO_TARGET
	)
