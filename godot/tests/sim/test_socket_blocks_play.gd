## Playing on 2x2 socket blocks: building on the anchor, the reach from the
## block's centre, and the golden the GDScript sim wrote.
extends GutTest

const COLS := 22
const ROWS := 16
const GOLDEN := "res://tests/goldens/socket_blocks.json"


func _blocks(map_seed: int) -> GameMap:
	return MapGen.generate(map_seed, COLS, ROWS, false, 2)


func _tower_on_first_block(game: GameState) -> Tower:
	game.buttons = 1000
	var anchor := game.map.sockets[0]
	Game.submit(game, Command.build("spoolGuard", anchor.x, anchor.y))
	Game.tick(game)
	return game.towers[0]


func test_a_tower_is_built_on_the_anchor() -> void:
	var game := Game.create(1)
	game.map = _blocks(1)
	var tower := _tower_on_first_block(game)
	assert_eq(Vector2i(tower.col, tower.row), game.map.sockets[0])


func test_building_on_another_cell_of_the_block_is_refused() -> void:
	var game := Game.create(1)
	game.map = _blocks(1)
	game.buttons = 1000
	var anchor := game.map.sockets[0]
	Game.submit(game, Command.build("spoolGuard", anchor.x + 1, anchor.y + 1))
	Game.tick(game)
	assert_eq(game.towers.size(), 0)
	assert_eq(game.events[0].kind, GameEvent.Kind.COMMAND_REJECTED)
	assert_eq(game.events[0].reason, GameEvent.RejectReason.NOT_A_SOCKET)


func test_a_second_tower_on_the_same_block_is_refused() -> void:
	var game := Game.create(1)
	game.map = _blocks(1)
	_tower_on_first_block(game)
	var anchor := game.map.sockets[0]
	Game.submit(game, Command.build("thimbleMortar", anchor.x, anchor.y))
	Game.tick(game)
	assert_eq(game.towers.size(), 1)
	assert_eq(game.events[0].reason, GameEvent.RejectReason.OCCUPIED)


func test_reach_is_measured_from_the_centre_of_the_block() -> void:
	var game := Game.create(1)
	game.map = _blocks(1)
	var tower := _tower_on_first_block(game)
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var reach := TowerFire.reach_of(game, tower)
	var foe := FoeSpawner.spawn(game, "scrapGoblin", 1, 0)
	# just inside the reach measured from the centre, to the right of it
	foe.x = centre.x + reach - 0.01
	foe.y = centre.y
	assert_eq(TowerFire.target_for(game, tower), foe)
	# just outside it
	foe.x = centre.x + reach + 0.01
	assert_null(TowerFire.target_for(game, tower))
	# and to the left: measured from the anchor cell's centre it would be in reach
	foe.x = centre.x - reach - 0.01
	assert_null(TowerFire.target_for(game, tower))


func test_blocks_match_the_golden_written_by_the_gdscript_sim() -> void:
	# regenerate with: godot --headless --path godot -s tools/write_socket_blocks_golden.gd
	# (only by a reviewed balance change)
	var golden: Array = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	assert_gt(golden.size(), 5)
	for entry in golden:
		var map := _blocks(int(entry.seed))
		var anchors := []
		var levels := []
		for anchor in map.sockets:
			anchors.append([anchor.x, anchor.y])
			levels.append(map.elevation_at(anchor))
		# JSON numbers come back as floats
		var golden_anchors := []
		for pair in entry.sockets:
			golden_anchors.append([int(pair[0]), int(pair[1])])
		var golden_levels := []
		for level in entry.levels:
			golden_levels.append(int(level))
		assert_eq(anchors, golden_anchors, "anchors of seed %d" % entry.seed)
		assert_eq(levels, golden_levels, "levels of seed %d" % entry.seed)
		assert_eq(
			[map.heartstone.position.x, map.heartstone.position.y],
			[int(entry.heartstone[0]), int(entry.heartstone[1])],
			"Heartstone of seed %d" % entry.seed
		)
