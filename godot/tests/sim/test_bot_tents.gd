## The bot's tent profile: Guard Tents where the guards hold the road, Mess Tents
## where their aura reaches the guards.
extends GutTest

const PROFILES := preload("res://content/bot_profiles.gd")
const TOWERS := preload("res://content/towers.gd")
const MAP_RULES := preload("res://content/map_rules.gd")


func _play(game: GameState, ticks: int) -> int:
	var bot := ScriptedBot.new(PROFILES.PROFILES.guardMix)
	var rejected := 0
	for i in ticks:
		bot.act(game)
		Game.tick(game)
		for event in game.events:
			if event.kind == GameEvent.Kind.COMMAND_REJECTED:
				rejected += 1
	return rejected


func _types(game: GameState) -> Array[String]:
	var types: Array[String] = []
	for tower in game.towers:
		types.append(tower.type)
	return types


func test_the_guard_mix_builds_both_tents_among_its_towers() -> void:
	# a Mess Tent needs a socket whose aura reaches the guards, which a small board does not
	# always have, so look over a few seeds
	var with_both: Array[int] = []
	for map_seed in range(1, 9):
		var game := Game.create(map_seed)
		game.buttons = 100000
		_play(game, 60)
		var types := _types(game)
		assert_true(types.has("guardTent"), "seed %d" % map_seed)
		assert_true(types.has("spoolGuard"), "seed %d" % map_seed)
		assert_gt(game.guards.size(), 0)
		if types.has("messTent"):
			with_both.append(map_seed)
	# on the valley (24 to 30 sockets, #320) seeds 1 to 7 have a socket near the guards' post
	# and seed 8 has none (on the 16 by 11 board only seeds 2 and 7 had one); a placement
	# change must move this
	assert_eq(with_both, [1, 2, 3, 4, 5, 6, 7] as Array[int])


func test_a_mess_tent_goes_where_its_aura_reaches_the_guards() -> void:
	for map_seed in [1, 2, 3, 7, 42]:
		var game := Game.create(map_seed)
		game.buttons = 100000
		_play(game, 60)
		for tower in game.towers:
			if tower.type != "messTent":
				continue
			var reach := TowerFire.reach_of(game, tower)
			var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
			var covered := 0
			for guard in game.guards:
				var at := game.routes[0].position_at(guard.post)
				if centre.distance_to(Vector2(at.x, at.y)) <= reach:
					covered += 1
			assert_gt(covered, 0, "seed %d: a Mess Tent that reaches no guard" % map_seed)


func test_no_mess_tent_is_built_before_a_guard_tent_exists() -> void:
	var game := Game.create(1)
	game.buttons = 100000
	var bot := ScriptedBot.new(
		{"build_order": ["messTent", "spoolGuard"], "call_early": false, "early_foes_left": 0}
	)
	for i in 5:
		bot.act(game)
		Game.tick(game)
	assert_false(_types(game).has("messTent"))
	assert_gt(game.towers.size(), 0, "it builds the next tower of its order instead")


## With the default Buttons and 3000 ticks this reaches both tents and every upgrade; the
## replay golden (a whole 20 wave game) is the longer check.
func test_the_guard_mix_never_sends_a_command_the_sim_rejects() -> void:
	for map_seed in [1, 7, 42]:
		var game := Game.create(map_seed)
		assert_eq(_play(game, 3000), 0, "seed %d" % map_seed)


func test_the_guard_mix_plays_a_whole_run_and_replays_the_same() -> void:
	var a := BotRunner.play(3, PROFILES.PROFILES.guardMix, 6)
	var b := BotRunner.play(3, PROFILES.PROFILES.guardMix, 6)
	assert_eq(a, b)
	assert_gt(a.waves_cleared, 0)


func test_a_guard_tent_of_the_bot_has_its_guards_on_road_within_touch_of_its_block() -> void:
	var touch: float = MAP_RULES.SOCKET_BLOCK_TOUCH_DISTANCE
	for map_seed in [1, 2, 3, 7, 42]:
		var game := Game.create(map_seed)
		game.buttons = 100000
		_play(game, 60)
		var tents := 0
		for tower in game.towers:
			if tower.type != "guardTent":
				continue
			tents += 1
			var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
			for guard in game.guards:
				if guard.tent_id != tower.id:
					continue
				# the block was placed within touch of some road (the main road or the second one);
				# its guards stand on the main road at the point nearest the block
				var nearest := INF
				for route in game.routes:
					for i in range(int(route.total * 4.0) + 1):
						var at := route.position_at(float(i) / 4.0)
						nearest = minf(nearest, centre.distance_to(Vector2(at.x, at.y)))
				assert_lte(nearest, touch + 0.3, "seed %d" % map_seed)
		assert_gt(tents, 0, "seed %d builds a Guard Tent" % map_seed)


func test_the_mess_tent_goes_on_the_candidate_nearest_the_guards() -> void:
	var checked_ties := 0
	for map_seed in range(1, 151):
		var game := GuardKit.game_with_tent(map_seed)
		var bot := ScriptedBot.new(
			{"build_order": ["messTent"], "call_early": false, "early_foes_left": 0}
		)
		bot.act(game)
		Game.tick(game)
		if game.towers.size() < 2:
			continue
		var chosen := game.towers[1]
		var reach: float = TOWERS.DEFS.messTent.range[0]
		var at_chosen := _candidate(game, Vector2i(chosen.col, chosen.row), reach)
		var others_equal := 0
		for anchor in game.map.sockets:
			if (
				anchor == Vector2i(chosen.col, chosen.row)
				or anchor == Vector2i(game.towers[0].col, game.towers[0].row)
			):
				continue
			var other := _candidate(game, anchor, reach)
			assert_lte(
				other.covered, at_chosen.covered, "seed %d: it covers the most guards" % map_seed
			)
			if other.covered == at_chosen.covered and other.covered > 0:
				others_equal += 1
				assert_gte(
					other.distance + 1e-9,
					at_chosen.distance,
					"seed %d: the nearest of those" % map_seed
				)
		checked_ties += 1 if others_equal > 0 else 0
	assert_gt(checked_ties, 0, "some seed has two candidates covering the same guards")


## How many guards a Mess Tent on `anchor` would reach and their summed distance.
func _candidate(game: GameState, anchor: Vector2i, reach_base: float) -> Dictionary:
	var centre := game.map.socket_centre(anchor)
	var reach := reach_base * game.map.range_multiplier(anchor)
	var covered := 0
	var distance := 0.0
	for guard in game.guards:
		var at := game.routes[0].position_at(guard.post)
		var gap := centre.distance_to(Vector2(at.x, at.y))
		if gap <= reach:
			covered += 1
			distance += gap
	return {"covered": covered, "distance": distance}
