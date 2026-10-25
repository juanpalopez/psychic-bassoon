## Only foes about to reach the Heartstone get an arrow, the nearest first.
extends GutTest

const RULES := preload("res://content/indicators.gd")


func _foe(game: GameState, remaining: float, alive := true) -> Foe:
	var foe := Foe.new()
	foe.id = game.next_id
	game.next_id += 1
	foe.route = 0
	foe.distance = game.routes[0].total - remaining
	foe.alive = alive
	game.foes.append(foe)
	return foe


func _picked(game: GameState) -> Array[Foe]:
	var into: Array[Foe] = []
	ArrowTargets.foes_near_heartstone(
		game, RULES.FOE_NEAR_HEARTSTONE, 3, into, PackedFloat64Array()
	)
	return into


func test_a_foe_far_from_the_heartstone_gets_no_arrow() -> void:
	var game := Game.create(7)
	_foe(game, RULES.FOE_NEAR_HEARTSTONE + 1.0)
	assert_eq(_picked(game).size(), 0)


func test_near_foes_come_nearest_first_and_only_the_count_asked_for() -> void:
	var game := Game.create(7)
	var far := _foe(game, 6.0)
	var near := _foe(game, 1.0)
	var middle := _foe(game, 3.0)
	var last := _foe(game, 7.0)
	var picked := _picked(game)
	assert_eq(picked.size(), 3)
	assert_eq(picked[0], near)
	assert_eq(picked[1], middle)
	assert_eq(picked[2], far)
	assert_false(picked.has(last))


func test_a_dead_foe_gets_no_arrow() -> void:
	var game := Game.create(7)
	_foe(game, 1.0, false)
	assert_eq(_picked(game).size(), 0)


func test_a_flier_is_measured_along_its_straight_line() -> void:
	var game := Game.create(7)
	var flier := _foe(game, 1.0)
	flier.flying = true
	flier.distance = game.air_routes[0].total - 1.0
	assert_eq(_picked(game).size(), 1)


func test_a_foe_on_a_route_the_game_does_not_have_is_skipped() -> void:
	var game := Game.create(7)
	_foe(game, 1.0).route = 99
	assert_eq(_picked(game).size(), 0)
