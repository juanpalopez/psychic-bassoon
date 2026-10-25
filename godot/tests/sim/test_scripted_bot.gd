## The scripted bot: a player that only sends commands. It builds where a tower
## reaches the most road, spends what it has, upgrades when the sockets are used or it has
## `MAX_TOWERS` towers, and calls the waves.
extends GutTest

const PROFILES := preload("res://content/bot_profiles.gd")
const TOWERS := preload("res://content/towers.gd")


func _bot(profile_id: String = "mix") -> ScriptedBot:
	return ScriptedBot.new(PROFILES.PROFILES[profile_id])


## Runs `ticks` ticks of bot then game and returns how many commands were rejected.
func _play(game: GameState, bot: ScriptedBot, ticks: int) -> int:
	var rejected := 0
	for i in ticks:
		bot.act(game)
		Game.tick(game)
		for event in game.events:
			if event.kind == GameEvent.Kind.COMMAND_REJECTED:
				rejected += 1
	return rejected


## Road cells within a spool guard's reach of a block, counted without the bot.
func _coverage(game: GameState, anchor: Vector2i) -> int:
	var centre := game.map.socket_centre(anchor)
	var reach: float = TOWERS.DEFS.spoolGuard.range[0] * game.map.range_multiplier(anchor)
	var count := 0
	for cell in game.map.path:
		var road := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
		if centre.distance_to(road) <= reach:
			count += 1
	return count


func test_there_are_five_profiles_with_real_towers() -> void:
	assert_eq(
		PROFILES.PROFILE_IDS,
		["spoolOnly", "mortarHeavy", "prismHeavy", "mix", "guardMix"] as Array[String]
	)
	for id in PROFILES.PROFILE_IDS:
		var profile: Dictionary = PROFILES.PROFILES[id]
		assert_gt(profile.build_order.size(), 0, id)
		for tower in profile.build_order:
			assert_true(TOWERS.DEFS.has(tower), "%s: %s" % [id, tower])
		assert_true(profile.has("call_early"), id)
		assert_true(profile.has("early_foes_left"), id)


func test_the_prism_heavy_profile_builds_prism_spires_first_and_most() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 100000
	_play(game, _bot("prismHeavy"), 30)
	assert_gte(game.towers.size(), 6)
	var prisms := 0
	for tower in game.towers:
		if tower.type == "prismSpire":
			prisms += 1
	assert_eq(game.towers[0].type, "prismSpire", "the first tower is a Prism Spire")
	assert_gt(prisms, game.towers.size() / 2, "more than half are Prism Spires")


func test_the_first_tower_goes_on_the_socket_that_reaches_the_most_road() -> void:
	for map_seed in [1, 7, 42]:
		var game := Game.create_on_strip_valley(map_seed)
		game.buttons = 1000
		var best := game.map.sockets[0]
		for anchor in game.map.sockets:
			if _coverage(game, anchor) > _coverage(game, best):
				best = anchor
		_play(game, _bot("spoolOnly"), 2)
		assert_gt(game.towers.size(), 0, "seed %d" % map_seed)
		assert_eq(Vector2i(game.towers[0].col, game.towers[0].row), best, "seed %d" % map_seed)


func test_the_next_towers_go_on_the_next_best_sockets() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 100000
	_play(game, _bot("spoolOnly"), 8)
	assert_gte(game.towers.size(), 4)
	var scores: Array[int] = []
	for tower in game.towers:
		scores.append(_coverage(game, Vector2i(tower.col, tower.row)))
	for i in range(1, scores.size()):
		assert_lte(scores[i], scores[i - 1], "built in order of coverage")


func test_it_builds_the_profiles_towers_in_order_and_cycles() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 100000
	var bot := _bot("mix")
	var order: Array = PROFILES.PROFILES.mix.build_order
	_play(game, bot, order.size() * 2 + 4)
	assert_gte(game.towers.size(), order.size() * 2)
	for i in order.size() * 2:
		assert_eq(game.towers[i].type, order[i % order.size()], "tower %d" % i)


func test_it_waits_until_it_can_pay_and_never_overspends() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 10
	var bot := _bot("spoolOnly")
	_play(game, bot, 5)
	assert_eq(game.towers.size(), 0, "10 Buttons buy no tower")
	assert_eq(game.buttons, 10)
	game.buttons = 50
	_play(game, bot, 2)
	assert_eq(game.towers.size(), 1, "50 Buttons buy a Spool Guard")
	assert_eq(game.buttons, 0)


func test_it_never_sends_a_command_the_sim_rejects() -> void:
	for profile_id in PROFILES.PROFILE_IDS:
		var game := Game.create_on_strip_valley(7)
		var rejected := _play(game, _bot(profile_id), 3000)
		assert_eq(rejected, 0, profile_id)
		assert_gte(game.buttons, 0, profile_id)


func test_it_never_sends_an_upgrade_it_cannot_pay_for() -> void:
	var game := Game.create_on_strip_valley(1)
	# a tower on every socket and almost nothing to spend: it must wait, not try
	game.buttons = 50 * game.map.sockets.size()
	game.heartstone_health = 100000
	var bot := _bot("spoolOnly")
	_play(game, bot, game.map.sockets.size() * 3 + 5)
	game.buttons = 59
	var rejected := 0
	for i in 5:
		bot.act(game)
		game.heartstone_health = 100000
		Game.tick(game)
		for event in game.events:
			if event.kind == GameEvent.Kind.COMMAND_REJECTED:
				rejected += 1
		game.buttons = mini(game.buttons, 59)
	assert_eq(rejected, 0, "59 Buttons do not buy a 60 Button upgrade, and it did not try")


func test_it_builds_at_most_max_towers_and_then_upgrades() -> void:
	var game := Game.create_on_strip_valley(1)
	assert_gt(game.map.sockets.size(), PROFILES.MAX_TOWERS, "the valley has sockets to spare")
	# enough for MAX_TOWERS Spool Guards and one upgrade (60), not for another tower as well
	game.buttons = 50 * PROFILES.MAX_TOWERS + 60
	game.heartstone_health = 100000
	var rejected := _play(game, _bot("spoolOnly"), PROFILES.MAX_TOWERS * 3 + 5)
	assert_eq(rejected, 0)
	assert_eq(game.towers.size(), PROFILES.MAX_TOWERS, "it stops building at the cap")
	var upgraded := 0
	for tower in game.towers:
		upgraded += tower.level
	assert_eq(upgraded, 1, "the spare Buttons went into an upgrade, not a sixteenth tower")


func test_a_profile_can_set_its_own_tower_cap() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 100000
	game.heartstone_health = 100000
	var profile: Dictionary = PROFILES.PROFILES.spoolOnly.duplicate(true)
	profile.max_towers = 3
	_play(game, ScriptedBot.new(profile), 6)
	assert_eq(game.towers.size(), 3)
	assert_gt(game.towers[0].level + game.towers[1].level + game.towers[2].level, 0)


func test_it_upgrades_once_every_socket_has_a_tower() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 100000
	game.heartstone_health = 100000
	var bot := _bot("spoolOnly")
	# MAX_TOWERS towers, all of them to the top level, then the rest of the sockets
	var rejected := _play(game, bot, game.map.sockets.size() * 3 + 20)
	assert_eq(game.towers.size(), game.map.sockets.size(), "one tower on every socket")
	# afterwards the spare Buttons go into upgrades, lowest level first
	rejected += _play(game, bot, 200)
	assert_eq(rejected, 0, "no build or upgrade was refused")
	var levels: Array[int] = []
	for tower in game.towers:
		levels.append(tower.level)
	assert_eq(levels.min(), 2, "everything reaches level 3 with 100,000 Buttons")


func test_it_upgrades_the_lowest_level_tower_first() -> void:
	var game := Game.create_on_strip_valley(1)
	# exactly enough for a Spool Guard on every socket it fills and nothing over
	var towers := mini(game.map.sockets.size(), PROFILES.MAX_TOWERS)
	game.buttons = 50 * towers
	var bot := _bot("spoolOnly")
	_play(game, bot, towers * 3 + 5)
	assert_eq(game.towers.size(), towers)
	# now just enough for three upgrades (60 each); the first kills pay a few more
	# Buttons, far from a fourth
	game.buttons = 60 * 3
	var rejected := _play(game, bot, 20)
	assert_eq(rejected, 0)
	var upgraded := 0
	var high := 0
	for tower in game.towers:
		if tower.level > 0:
			upgraded += 1
		high = maxi(high, tower.level)
	assert_gte(upgraded, 3, "three upgrades paid for")
	assert_eq(high, 1, "no tower gets a second upgrade while another is still level 1")


func test_it_launches_the_first_wave_on_the_first_tick_and_waits_while_a_wave_runs() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 0
	var bot := _bot("spoolOnly")
	bot.act(game)
	Game.tick(game)
	assert_eq(game.wave, 1)
	var launched := 0
	for i in 60:
		bot.act(game)
		Game.tick(game)
		for event in game.events:
			if event.kind == GameEvent.Kind.WAVE_LAUNCHED:
				launched += 1
	assert_eq(launched, 0, "it does not call a second wave while the first is walking")


## Plays `ticks` ticks and counts the waves launched while foes were still walking
## (the early calls).
func _early_calls(profile: Dictionary, ticks: int) -> int:
	var game := Game.create_on_strip_valley(1)
	var bot := ScriptedBot.new(profile)
	game.buttons = 0
	game.heartstone_health = 100000
	var early := 0
	for i in ticks:
		var walking := game.foes.size()
		var was_running := game.running
		bot.act(game)
		Game.tick(game)
		for event in game.events:
			if (
				event.kind == GameEvent.Kind.WAVE_LAUNCHED
				and was_running
				and walking > 0
				and game.spawners.size() > 0
			):
				early += 1
	return early


func test_a_profile_waiting_for_no_foes_never_calls_a_wave_while_foes_walk() -> void:
	var profile := {"build_order": [], "call_early": true, "early_foes_left": 0}
	assert_eq(_early_calls(profile, 600), 0)


func test_a_profile_with_a_high_threshold_calls_waves_early() -> void:
	var profile := {"build_order": [], "call_early": true, "early_foes_left": 100}
	assert_gt(_early_calls(profile, 600), 0)


func test_a_profile_that_calls_early_does_so_when_few_foes_are_left() -> void:
	var game := Game.create_on_strip_valley(1)
	var profile := {"build_order": ["spoolGuard"], "call_early": true, "early_foes_left": 100}
	var bot := ScriptedBot.new(profile)
	game.buttons = 0
	game.heartstone_health = 100000
	var launched := 0
	for i in 400:
		bot.act(game)
		Game.tick(game)
		for event in game.events:
			if event.kind == GameEvent.Kind.WAVE_LAUNCHED:
				launched += 1
	assert_gt(launched, 1, "it called waves early")


func test_it_uses_only_commands_and_leaves_the_game_to_the_tick() -> void:
	var game := Game.create_on_strip_valley(1)
	game.buttons = 1000
	_bot("mix").act(game)
	assert_eq(game.towers.size(), 0, "a command waits for the tick")
	assert_gt(game.pending.size(), 0)
