## The render-only offset that keeps a crowd of foes from drawing as one blob.
extends GutTest

const FOES := preload("res://content/foes.gd")
const HEADING := Vector2.RIGHT


func _foe(id: int, type: String, x: float, y: float) -> Foe:
	var foe := Foe.new()
	foe.id = id
	foe.type = type
	foe.x = x
	foe.y = y
	foe.hp = 20
	foe.max_hp = 20
	foe.radius = float(FOES.DEFS[type].radius)
	return foe


func _game_with(foes: Array[Foe], tick: int = 1) -> GameState:
	var game := GameState.new()
	game.tick_count = tick
	game.foes = foes
	return game


func _drawn_view() -> FoesView:
	var view := FoesView.new()
	add_child_autofree(view)
	return view


func test_same_id_gives_the_same_offset() -> void:
	assert_eq(FoeSpread.offset(7, HEADING), FoeSpread.offset(7, HEADING))
	assert_eq(FoeSpread.offset(7, HEADING, true), FoeSpread.offset(7, HEADING, true))


func test_walkers_stay_inside_the_lane_and_stagger() -> void:
	for id in 500:
		var o := FoeSpread.offset(id, HEADING)
		assert_lte(absf(o.z), FoeSpread.LANE + FoeSpread.JITTER + 1e-6, "across %d" % id)
		assert_lte(absf(o.x), FoeSpread.STAGGER + 1e-6, "along %d" % id)
		assert_eq(o.y, 0.0, "walkers keep their height")


func test_lane_follows_the_heading() -> void:
	# heading down the board (+z): across is x, along is z
	for id in 100:
		var o := FoeSpread.offset(id, Vector2(0, 1))
		assert_lte(absf(o.x), FoeSpread.LANE + FoeSpread.JITTER + 1e-6)
		assert_lte(absf(o.z), FoeSpread.STAGGER + 1e-6)


func test_neighbouring_ids_draw_visibly_apart() -> void:
	for id in 200:
		var a := FoeSpread.offset(id, HEADING)
		var b := FoeSpread.offset(id + 1, HEADING)
		assert_gte(Vector2(a.x - b.x, a.z - b.z).length(), 0.2, "ids %d and %d" % [id, id + 1])


func test_offsets_spread_over_both_sides_and_many_values() -> void:
	var left := 0
	var right := 0
	var seen := {}
	for id in 200:
		var o := FoeSpread.offset(id, HEADING)
		if o.z < 0.0:
			left += 1
		elif o.z > 0.0:
			right += 1
		seen[snappedf(o.z, 0.001)] = true
	assert_gt(left, 50)
	assert_gt(right, 50)
	assert_gt(seen.size(), 20)


func test_a_zero_heading_falls_back_to_along_the_road() -> void:
	assert_eq(FoeSpread.offset(5, Vector2.ZERO), FoeSpread.offset(5, Vector2.RIGHT))


func test_flyers_vary_in_height_and_spread_wider() -> void:
	var heights := {}
	var widest := 0.0
	for id in 200:
		var o := FoeSpread.offset(id, HEADING, true)
		assert_gte(o.y, 0.0)
		assert_lte(o.y, FoeSpread.AIR_HEIGHT + 1e-6)
		heights[snappedf(o.y, 0.01)] = true
		widest = maxf(widest, absf(o.z))
	assert_gt(heights.size(), 10)
	assert_gt(widest, FoeSpread.LANE + FoeSpread.JITTER)


func test_two_foes_at_one_sim_position_draw_apart() -> void:
	var view := _drawn_view()
	view.update(
		_game_with(
			[_foe(0, "scrapGoblin", 4.5, 3.5), _foe(1, "scrapGoblin", 4.5, 3.5)] as Array[Foe]
		),
		1.0
	)
	var a := view.drawn_position("scrapGoblin", 0)
	var b := view.drawn_position("scrapGoblin", 1)
	assert_gte(Vector2(a.x - b.x, a.z - b.z).length(), 0.2)


func test_a_standing_foe_keeps_one_spot_and_stays_near_the_sim_point() -> void:
	var view := _drawn_view()
	var game := _game_with([_foe(3, "scrapGoblin", 4.5, 3.5)] as Array[Foe])
	view.update(game, 1.0)
	var first := view.drawn_position("scrapGoblin", 0)
	game.tick_count = 2
	view.update(game, 0.5)
	assert_eq(view.drawn_position("scrapGoblin", 0), first, "no jitter while standing")
	var truth := BoardSpace.point_to_world(4.5, 3.5)
	assert_lte(absf(first.z - truth.z), FoeSpread.LANE + FoeSpread.JITTER + 1e-5)


func test_a_walking_foe_is_offset_across_its_heading() -> void:
	var view := _drawn_view()
	var foe := _foe(1, "scrapGoblin", 4.0, 3.5)
	var game := _game_with([foe] as Array[Foe])
	view.update(game, 1.0)
	foe.y = 4.5
	game.tick_count = 2
	view.update(game, 1.0)
	# walking +z: across is x
	var truth := BoardSpace.point_to_world(4.0, 4.5)
	var o := FoeSpread.offset(1, Vector2(0, 1))
	var at := view.drawn_position("scrapGoblin", 0)
	assert_almost_eq(at.x, truth.x + o.x, 1e-5)
	assert_almost_eq(at.z, truth.z + o.z, 1e-5)


func test_the_offset_glides_round_a_road_corner() -> void:
	# a foe walks right, then turns down; its drawn spot may not jump across the road
	var view := _drawn_view()
	var foe := _foe(1, "scrapGoblin", 2.0, 2.0)
	var previous := Vector3.ZERO
	var biggest := 0.0
	for tick in 20:
		if tick < 10:
			foe.x += 0.1
		else:
			foe.y += 0.1
		view.update(_game_with([foe] as Array[Foe], tick + 1), 1.0)
		var sim := BoardSpace.point_to_world(foe.x, foe.y)
		var drawn := view.drawn_position("scrapGoblin", 0)
		var offset := Vector3(drawn.x - sim.x, 0.0, drawn.z - sim.z)
		if tick > 0:
			biggest = maxf(biggest, offset.distance_to(previous))
		previous = offset
	assert_lt(biggest, 0.1, "no jump of more than a tenth of a cell between ticks")


func test_a_foe_that_turns_right_round_takes_the_new_heading() -> void:
	var view := _drawn_view()
	var foe := _foe(2, "scrapGoblin", 5.0, 2.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	foe.x += 0.1
	view.update(_game_with([foe] as Array[Foe], 2), 1.0)
	foe.x -= 0.1
	view.update(_game_with([foe] as Array[Foe], 3), 1.0)
	assert_lt((view._headings[2] as Vector2).x, 0.0, "now walking back")


func test_a_flyer_glides_round_a_corner_too() -> void:
	var view := _drawn_view()
	var flyer := _foe(3, "razorMoth", 2.0, 2.0)
	flyer.flying = true
	var previous := Vector3.ZERO
	var biggest := 0.0
	for tick in 20:
		if tick < 10:
			flyer.x += 0.1
		else:
			flyer.y += 0.1
		view.update(_game_with([flyer] as Array[Foe], tick + 1), 1.0)
		var sim := BoardSpace.point_to_world(flyer.x, flyer.y)
		var drawn := view.drawn_position("razorMoth", 0)
		var offset := Vector3(drawn.x - sim.x, 0.0, drawn.z - sim.z)
		if tick > 0:
			biggest = maxf(biggest, offset.distance_to(previous))
		previous = offset
	assert_lt(biggest, 0.12)


func test_headings_of_gone_foes_are_forgotten() -> void:
	var view := _drawn_view()
	var foe := _foe(5, "scrapGoblin", 2.0, 2.0)
	view.update(_game_with([foe] as Array[Foe], 1), 1.0)
	foe.x += 0.1
	view.update(_game_with([foe] as Array[Foe], 2), 1.0)
	assert_true(view._headings.has(5))
	view.update(_game_with([] as Array[Foe], 3), 1.0)
	assert_false(view._headings.has(5), "pruned when the foe is gone")


func test_health_bars_follow_the_offset_foe() -> void:
	var view := _drawn_view()
	var foe := _foe(2, "scrapGoblin", 4.5, 3.5)
	foe.hp = 5
	view.update(_game_with([foe] as Array[Foe]), 1.0)
	var at := view.drawn_position("scrapGoblin", 0)
	var bars: FoeBars = view._bars
	assert_almost_eq(bars.drawn_position(0).x, at.x, 1e-5)
	assert_almost_eq(bars.drawn_position(0).z, at.z, 1e-5)


func test_a_flyer_is_drawn_higher_by_its_offset_and_bar_follows() -> void:
	var view := _drawn_view()
	var foe := _foe(9, "razorMoth", 4.5, 3.5)
	foe.flying = true
	foe.hp = 2
	view.update(_game_with([foe] as Array[Foe]), 1.0)
	var o := FoeSpread.offset(9, Vector2.RIGHT, true)
	var base := BoardSpace.point_to_world(4.5, 3.5)
	var at := view.drawn_position("razorMoth", 0)
	assert_almost_eq(at.x, base.x + o.x, 1e-5)
	assert_almost_eq(at.z, base.z + o.z, 1e-5)
	assert_almost_eq(view._bars.drawn_position(0).x, at.x, 1e-5)


func test_draw_calls_unchanged_one_multimesh_per_type() -> void:
	var view := _drawn_view()
	var foes: Array[Foe] = []
	for id in 30:
		foes.append(_foe(id, "scrapGoblin", 4.5, 3.5))
	view.update(_game_with(foes), 1.0)
	assert_eq(view.get_child_count(), FOES.FOE_IDS.size() + 1)
	assert_eq(view.visible_count("scrapGoblin"), 30)
