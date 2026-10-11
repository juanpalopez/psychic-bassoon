## The four commands. Ported from `src/sim/game/game.test.ts`.
extends GutTest

const RULES := preload("res://content/game_rules.gd")
const MAP_RULES := preload("res://content/map_rules.gd")
const TOWERS := preload("res://content/towers.gd")
const SEED := 42
const REASON := GameEvent.RejectReason
const KIND := GameEvent.Kind


func assert_rejected_by(events: Array[GameEvent], command: Command, reason: REASON) -> void:
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, KIND.COMMAND_REJECTED)
	assert_eq(events[0].command, command)
	assert_eq(events[0].reason, reason)


func test_build_places_a_level_1_tower_and_charges_its_cost() -> void:
	var game := Game.create(SEED)
	var cell := GameTestKit.socket(game)
	var events := GameTestKit.run(game, [GameTestKit.build_at("ballista", cell)])
	var cost: int = TOWERS.DEFS.ballista.cost[0]
	assert_eq(game.buttons, RULES.START_BUTTONS - cost)
	assert_eq(game.towers.size(), 1)
	var tower := game.towers[0]
	assert_eq(tower.id, 0)
	assert_eq(tower.type, "ballista")
	assert_eq(tower.level, 0)
	assert_eq(Vector2i(tower.col, tower.row), cell)
	assert_eq(tower.invested, cost)
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, KIND.TOWER_BUILT)
	assert_eq(events[0].tower_id, 0)


func test_each_tower_gets_its_own_id() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(
		game,
		[
			GameTestKit.build_at("ballista", GameTestKit.socket(game, 0)),
			GameTestKit.build_at("ballista", GameTestKit.socket(game, 1))
		]
	)
	assert_eq([game.towers[0].id, game.towers[1].id], [0, 1])


func test_build_on_the_path_is_rejected() -> void:
	var game := Game.create(SEED)
	var command := GameTestKit.build_at("ballista", game.map.path[3])
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NOT_A_SOCKET)
	assert_eq(game.buttons, RULES.START_BUTTONS)


func test_unknown_tower_is_rejected_not_thrown() -> void:
	var game := Game.create(SEED)
	var command := GameTestKit.build_at("laser", GameTestKit.socket(game))
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.UNKNOWN_TOWER)
	assert_eq(game.buttons, RULES.START_BUTTONS)


func test_build_off_the_board_is_rejected() -> void:
	var game := Game.create(SEED)
	for cell in [
		Vector2i(-1, 0),
		Vector2i(MAP_RULES.GRID_COLS, 0),
		Vector2i(0, MAP_RULES.GRID_ROWS),
		Vector2i(0, -1)
	]:
		var command := GameTestKit.build_at("ballista", cell)
		assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NOT_A_SOCKET)


func test_build_on_an_occupied_plot_is_rejected() -> void:
	var game := Game.create(SEED)
	var cell := GameTestKit.socket(game)
	GameTestKit.run(game, [GameTestKit.build_at("ballista", cell)])
	var command := GameTestKit.build_at("ballista", cell)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.OCCUPIED)
	assert_eq(game.towers.size(), 1)


func test_build_needs_the_buttons_and_allows_an_exact_fit() -> void:
	var game := Game.create(SEED)
	var cost: int = TOWERS.DEFS.stormSpire.cost[0]
	game.buttons = cost - 1
	var command := GameTestKit.build_at("stormSpire", GameTestKit.socket(game))
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NOT_ENOUGH_BUTTONS)
	game.buttons = cost
	GameTestKit.run(game, [command])
	assert_eq(game.buttons, 0)
	assert_eq(game.towers.size(), 1)


func _with_tower(type: String) -> GameState:
	var game := Game.create(SEED)
	GameTestKit.run(game, [GameTestKit.build_at(type, GameTestKit.socket(game))])
	game.buttons = 1000
	return game


func test_upgrade_raises_the_level_and_charges_the_next_cost() -> void:
	var game := _with_tower("ballista")
	var events := GameTestKit.run(game, [Command.upgrade(0)])
	var costs: Array = TOWERS.DEFS.ballista.cost
	assert_eq(game.buttons, 1000 - int(costs[1]))
	assert_eq(game.towers[0].level, 1)
	assert_eq(game.towers[0].invested, int(costs[0]) + int(costs[1]))
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, KIND.TOWER_UPGRADED)
	assert_eq([events[0].tower_id, events[0].level], [0, 1])


func test_upgrade_stops_at_level_3() -> void:
	var game := _with_tower("ballista")
	GameTestKit.run(game, [Command.upgrade(0)])
	GameTestKit.run(game, [Command.upgrade(0)])
	assert_eq(game.towers[0].level, 2)
	var command := Command.upgrade(0)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.MAX_LEVEL)


func test_upgrade_needs_the_buttons() -> void:
	var game := _with_tower("ballista")
	var costs: Array = TOWERS.DEFS.ballista.cost
	game.buttons = int(costs[1]) - 1
	var command := Command.upgrade(0)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NOT_ENOUGH_BUTTONS)
	assert_eq(game.towers[0].level, 0)


func test_upgrade_of_an_unknown_tower_is_rejected() -> void:
	var game := Game.create(SEED)
	var command := Command.upgrade(99)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NO_SUCH_TOWER)


func test_sell_refunds_70_percent_rounded_down_and_frees_the_plot() -> void:
	var game := Game.create(SEED)
	var cell := GameTestKit.socket(game)
	GameTestKit.run(game, [GameTestKit.build_at("ballista", cell)])
	game.buttons = 1000
	GameTestKit.run(game, [Command.upgrade(0)])
	var costs: Array = TOWERS.DEFS.ballista.cost
	var invested := int(costs[0]) + int(costs[1])
	var events := GameTestKit.run(game, [Command.sell(0)])
	var refund := 77  # 70% of 50 + 60 Buttons, written out so the rate is checked too
	assert_eq(invested, 110)
	assert_eq(game.buttons, 1000 - int(costs[1]) + refund)
	assert_eq(game.towers.size(), 0)
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, KIND.TOWER_SOLD)
	assert_eq([events[0].tower_id, events[0].refund], [0, refund])
	GameTestKit.run(game, [GameTestKit.build_at("catapult", cell)])
	assert_eq(game.towers.size(), 1)


func test_sell_rounds_the_refund_down_like_the_typescript() -> void:
	# 90 * 0.7 is 62.99999999999999 in 64-bit floats, so the refund is 62, not 63
	var game := Game.create(SEED)
	GameTestKit.run(game, [GameTestKit.build_at("catapult", GameTestKit.socket(game))])
	game.buttons = 0
	GameTestKit.run(game, [Command.sell(0)])
	assert_eq(game.buttons, 62)


func test_build_checks_the_tower_before_the_cell() -> void:
	var game := Game.create(SEED)
	var command := Command.build("laser", -1, 0)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.UNKNOWN_TOWER)


func test_sell_of_an_unknown_tower_is_rejected() -> void:
	var game := Game.create(SEED)
	var command := Command.sell(3)
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.NO_SUCH_TOWER)


func test_launch_wave_starts_wave_1_with_no_bonus() -> void:
	var game := Game.create(SEED)
	var events := GameTestKit.run(game, [Command.launch_wave()])
	assert_eq(game.wave, 1)
	assert_true(game.running)
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, KIND.WAVE_LAUNCHED)
	assert_eq([events[0].wave, events[0].early_bonus], [1, 0])
	assert_eq(game.buttons, RULES.START_BUTTONS)


func test_calling_a_wave_early_pays_the_bonus() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [Command.launch_wave()])
	# no spawner exists yet (Phase 4, step 5), so a second launch counts as early
	var events := GameTestKit.run(game, [Command.launch_wave()])
	var bonus: int = RULES.EARLY_CALL_BASE + 1 * RULES.EARLY_CALL_PER_WAVE
	assert_eq(events[0].early_bonus, bonus)
	assert_eq(game.buttons, RULES.START_BUTTONS + bonus)
	assert_eq(game.wave, 2)


func test_launch_is_rejected_while_a_spawner_is_still_releasing() -> void:
	var game := Game.create(SEED)
	GameTestKit.run(game, [Command.launch_wave()])
	game.spawners.append("a spawner")
	var command := Command.launch_wave()
	assert_rejected_by(GameTestKit.run(game, [command]), command, REASON.WAVE_IN_PROGRESS)
	assert_eq(game.wave, 1)
