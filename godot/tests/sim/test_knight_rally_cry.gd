extends GutTest

## Rally Cry, the Knight's passive aura (#452): towers and guards within 3 cells of the standing
## Knight shoot or strike 15 percent faster, and guards heal 10 percent faster. It does not add
## to itself; it does add to a Kitchen Mess Tent's aura (different sources).

const HEROES := preload("res://content/heroes.gd")
const TOWERS := preload("res://content/towers.gd")


func _stand(game: GameState, at: Vector2) -> void:
	game.hero.x = at.x
	game.hero.y = at.y
	game.hero.cell = Vector2i(int(floor(at.x)), int(floor(at.y)))
	game.hero.path = [] as Array[Vector2i]


func _post_point(game: GameState) -> Vector2:
	var at := Barracks.post_point(game, game.guards[0])
	return Vector2(at.x, at.y)


func test_the_numbers_live_in_the_hero_content() -> void:
	var rally: Dictionary = HEROES.DEFS[HEROES.KNIGHT].rally_cry
	assert_eq(rally.radius, 3.0)
	assert_eq(rally.attack_speed, 0.15)
	assert_eq(rally.regen, 0.1)


func test_a_tower_in_reach_of_the_knight_shoots_faster() -> void:
	var plain := TowerFireKit.scene("spoolGuard")
	var rallied := TowerFireKit.scene("spoolGuard")
	var centre := rallied.game.map.socket_centre(Vector2i(rallied.tower.col, rallied.tower.row))
	_stand(rallied.game, centre + Vector2(2.9, 0.0))
	_stand(plain.game, centre + Vector2(3.1, 0.0))
	for scene in [plain, rallied]:
		TowerFireKit.foe(scene.game, scene.near)
		Game.tick(scene.game)
	var rate: float = TOWERS.DEFS.spoolGuard.rate[0]
	assert_almost_eq(plain.tower.cooldown, 1.0 / rate, 1e-9)
	assert_almost_eq(rallied.tower.cooldown, 1.0 / (rate * 1.15), 1e-9)


func test_a_fallen_knight_rallies_nobody() -> void:
	var scene := TowerFireKit.scene("spoolGuard")
	var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
	_stand(scene.game, centre)
	scene.game.hero.alive = false
	scene.game.hero.respawn_timer = 100.0
	TowerFireKit.foe(scene.game, scene.near)
	Game.tick(scene.game)
	var rate: float = TOWERS.DEFS.spoolGuard.rate[0]
	assert_almost_eq(scene.tower.cooldown, 1.0 / rate, 1e-9)


func test_a_beam_tower_burns_faster_in_reach_of_the_knight() -> void:
	var hp := []
	for near in [true, false]:
		var scene := TowerFireKit.scene("prismSpire")
		var centre := scene.game.map.socket_centre(Vector2i(scene.tower.col, scene.tower.row))
		_stand(scene.game, centre + Vector2(1.0 if near else 6.0, 0.0))
		var foe := TowerFireKit.foe(scene.game, scene.near, "corrugatedOrc")
		var before := foe.hp
		Game.tick(scene.game)
		hp.append(before - foe.hp)
	assert_gt(hp[1], 0.0)
	assert_almost_eq(hp[0], hp[1] * 1.15, 1e-9)


func test_guards_in_reach_strike_faster_and_heal_faster() -> void:
	var game := GuardKit.game_with_tent()
	_stand(game, _post_point(game) + Vector2(2.9, 0.0))
	GuardKit.tick(game, 1)
	for guard in game.guards:
		assert_almost_eq(guard.speed_bonus, 0.15, 1e-12)
		# 10 percent of the level's 1 hp a second
		assert_almost_eq(guard.regen_bonus, 0.1, 1e-12)
	_stand(game, _post_point(game) + Vector2(3.5, 0.0))
	GuardKit.tick(game, 1)
	assert_eq(game.guards[0].speed_bonus, 0.0)
	assert_eq(game.guards[0].regen_bonus, 0.0)


func test_rally_cry_does_not_stack_with_itself() -> void:
	var game := GuardKit.game_with_tent()
	_stand(game, _post_point(game))
	GuardKit.tick(game, 1)
	var first: float = game.guards[0].speed_bonus
	GuardKit.tick(game, 60)
	assert_eq(game.guards[0].speed_bonus, first)
	assert_almost_eq(game.guards[0].regen_bonus, 0.1, 1e-12)


func test_rally_cry_adds_to_the_mess_tent_aura() -> void:
	var game := GuardKit.game_with_both(0)
	_stand(game, _post_point(game))
	GuardKit.tick(game, 1)
	# the Mess Tent's 12 percent and 2 hp a second, plus the hero's 15 percent and 0.1 hp a second
	assert_almost_eq(game.guards[0].speed_bonus, 0.12 + 0.15, 1e-12)
	assert_almost_eq(game.guards[0].regen_bonus, 2.0 + 0.1, 1e-12)
	_stand(game, _post_point(game) + Vector2(9.0, 0.0))
	GuardKit.tick(game, 1)
	assert_almost_eq(game.guards[0].speed_bonus, 0.12, 1e-12)
	assert_almost_eq(game.guards[0].regen_bonus, 2.0, 1e-12)


func test_a_rallied_guard_heals_faster() -> void:
	var rallied := GuardKit.game_with_tent()
	var plain := GuardKit.game_with_tent()
	_stand(rallied, _post_point(rallied))
	_stand(plain, _post_point(plain) + Vector2(9.0, 0.0))
	for game in [rallied, plain]:
		game.guards[0].hp = 10.0
		GuardKit.tick(game, 60)
	assert_almost_eq(plain.guards[0].hp, 12.0, 0.2)
	assert_almost_eq(rallied.guards[0].hp, 12.2, 0.2)
	assert_gt(rallied.guards[0].hp, plain.guards[0].hp)
