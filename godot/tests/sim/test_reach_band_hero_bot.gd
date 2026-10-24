## The reach band (#446) for the Knight and the scripted bot: on a board with a band they measure a
## ground foe, or the road, to the band's edge as towers do; with no band nothing moves. The band
## is set by hand because the stitcher does not switch it on yet.
extends GutTest

const HEROES := preload("res://content/heroes.gd")
const PROFILES := preload("res://content/bot_profiles.gd")
const TOWERS := preload("res://content/towers.gd")

const BAND := 1.0
const INSIDE := 0.45
const OUTSIDE := 0.55
const WIDE_BAND := 4.0


func _game(band: float) -> GameState:
	var game := Game.create(42, 16, 11)
	Heroes.place(game, HEROES.KNIGHT)
	game.map.reach_band = band
	return game


## A foe on the hero's row, `extra` cells past the two bodies and the plain reach.
func _foe_beyond_reach(game: GameState, extra: float) -> Foe:
	var foe := FoeSpawner.spawn(game, "corrugatedOrc", 1, 0)
	foe.distance = 2.0
	game.hero.x = 4.0
	game.hero.y = 4.0
	game.hero.cell = Vector2i(4, 4)
	game.hero.path = [] as Array[Vector2i]
	foe.x = 4.0 + game.hero.radius + foe.radius + HEROES.REACH + extra
	foe.y = 4.0
	return foe


func test_the_knight_holds_a_foe_inside_the_margin() -> void:
	var game := _game(BAND)
	var foe := _foe_beyond_reach(game, INSIDE)
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, foe.id)


func test_the_knight_holds_nothing_beyond_the_margin() -> void:
	var game := _game(BAND)
	_foe_beyond_reach(game, OUTSIDE)
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, -1)


func test_without_a_band_the_knight_keeps_the_plain_reach() -> void:
	var game := _game(0.0)
	_foe_beyond_reach(game, INSIDE)
	Heroes.fight(game)
	assert_eq(game.hero.foe_id, -1)


## Road cells within a spool guard's reach of a block, plus the margin, counted without the bot.
func _coverage(game: GameState, anchor: Vector2i) -> int:
	var centre := game.map.socket_centre(anchor)
	var reach: float = (
		TOWERS.DEFS.spoolGuard.range[0] * game.map.range_multiplier(anchor)
		+ game.map.reach_margin()
	)
	var count := 0
	for cell in game.map.path:
		var road := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
		if centre.distance_to(road) <= reach:
			count += 1
	return count


func _best(game: GameState) -> Vector2i:
	var best := game.map.sockets[0]
	for anchor in game.map.sockets:
		if _coverage(game, anchor) > _coverage(game, best):
			best = anchor
	return best


func _first_tower_at(game: GameState) -> Vector2i:
	game.buttons = 1000
	var bot := ScriptedBot.new(PROFILES.PROFILES.spoolOnly)
	for i in 2:
		bot.act(game)
		Game.tick(game)
	assert_gt(game.towers.size(), 0)
	return Vector2i(game.towers[0].col, game.towers[0].row)


func test_the_first_tower_goes_where_the_reach_with_the_margin_covers_the_most_road() -> void:
	var differs := false
	for map_seed in [1, 7, 42, 99]:
		var plain := Game.create(map_seed)
		var banded := Game.create(map_seed)
		banded.map.reach_band = WIDE_BAND
		var want := _best(banded)
		if want != _best(plain):
			differs = true
		assert_eq(_first_tower_at(banded), want, "seed %d" % map_seed)
	assert_true(differs, "the band changes the best socket on at least one seed")


func _guards_covered(game: GameState, anchor: Vector2i, margin: float) -> int:
	var centre := game.map.socket_centre(anchor)
	var reach: float = TOWERS.DEFS.messTent.range[0] * game.map.range_multiplier(anchor) + margin
	var covered := 0
	for guard in game.guards:
		var at := Barracks.post_point(game, guard)
		if centre.distance_to(Vector2(at.x, at.y)) <= reach:
			covered += 1
	return covered


## A Mess Tent goes on the free socket whose aura, with the margin, reaches the most guards.
func test_a_mess_tent_counts_the_guards_its_aura_reaches_with_the_margin() -> void:
	var differs := false
	for map_seed in [1, 2, 3, 5, 7, 42]:
		var game := Game.create(map_seed)
		game.map.reach_band = WIDE_BAND
		game.buttons = 100000
		var bot := ScriptedBot.new(
			{"build_order": ["guardTent", "messTent"], "call_early": false, "early_foes_left": 0}
		)
		for i in 200:
			bot.act(game)
			Game.tick(game)
			if game.towers.size() >= 2:
				break
		if game.towers.size() < 2 or game.guards.is_empty():
			continue
		var tent := game.towers[0]
		var mess := game.towers[1]
		var best := 0
		var best_plain := 0
		for anchor in game.map.sockets:
			if anchor == Vector2i(tent.col, tent.row):
				continue
			best = maxi(best, _guards_covered(game, anchor, game.map.reach_margin()))
			best_plain = maxi(best_plain, _guards_covered(game, anchor, 0.0))
		var chosen := Vector2i(mess.col, mess.row)
		assert_eq(
			_guards_covered(game, chosen, game.map.reach_margin()), best, "seed %d" % map_seed
		)
		if best != best_plain:
			differs = true
	assert_true(differs, "the margin changes what an aura reaches on at least one seed")


func test_without_a_band_the_bot_ranks_by_the_plain_reach() -> void:
	for map_seed in [1, 7, 42]:
		var game := Game.create(map_seed)
		assert_eq(game.map.reach_band, 0.0)
		assert_eq(_first_tower_at(game), _best(game), "seed %d" % map_seed)
