## The health bars over the foes: the pure rules (when a bar shows, its width and colour) and
## the one MultiMesh that draws them all.
extends GutTest


func test_a_bar_is_hidden_at_full_hp_and_for_dying_foes() -> void:
	assert_false(FoeBars.is_shown(20.0, 20.0, true), "full hp")
	assert_false(FoeBars.is_shown(25.0, 20.0, true), "above full hp")
	assert_true(FoeBars.is_shown(19.0, 20.0, true))
	assert_false(FoeBars.is_shown(0.0, 20.0, true), "no hp left")
	assert_false(FoeBars.is_shown(10.0, 20.0, false), "dying")
	assert_false(FoeBars.is_shown(5.0, 0.0, true), "no max hp")


func test_the_share_is_hp_over_max_hp_clamped() -> void:
	assert_eq(FoeBars.share(5.0, 20.0), 0.25)
	assert_eq(FoeBars.share(-3.0, 20.0), 0.0)
	assert_eq(FoeBars.share(30.0, 20.0), 1.0)
	assert_eq(FoeBars.share(1.0, 0.0), 0.0)


func test_fill_width_shrinks_with_the_share() -> void:
	assert_eq(FoeBars.fill_width(1.0, 0.8), 0.8)
	assert_eq(FoeBars.fill_width(0.5, 0.8), 0.4)
	assert_eq(FoeBars.fill_width(0.0, 0.8), 0.0)
	assert_eq(FoeBars.fill_width(2.0, 0.8), 0.8, "clamped")


func test_the_boss_bar_is_larger() -> void:
	var small := FoeBars.bar_size("scrapGoblin")
	var big := FoeBars.bar_size("cardboardGolem")
	assert_gt(big.x, small.x)
	assert_gt(big.y, small.y)


func test_fill_colour_runs_from_low_to_full() -> void:
	assert_eq(FoeBars.fill_colour(1.0), FoeBars.FULL_COLOUR)
	assert_eq(FoeBars.fill_colour(0.0), FoeBars.LOW_COLOUR)
	var mid := FoeBars.fill_colour(0.5)
	assert_ne(mid, FoeBars.FULL_COLOUR)
	assert_ne(mid, FoeBars.LOW_COLOUR)


func test_all_bars_are_one_multimesh_with_a_back_and_a_fill_each() -> void:
	var bars := FoeBars.new()
	add_child_autofree(bars)
	bars.begin()
	bars.add(Vector3(1, 2, 3), 0.5, "scrapGoblin")
	bars.add(Vector3(4, 2, 3), 0.25, "cardboardGolem")
	bars.finish()
	assert_eq(bars.multimesh.visible_instance_count, 4)
	assert_eq(bars.bar_count(), 2)
	var inner := FoeBars.bar_size("scrapGoblin").x - 2.0 * FoeBars.BORDER
	assert_eq(bars.drawn_fill_width(0), FoeBars.fill_width(0.5, inner))
	assert_gt(bars.drawn_fill_width(1), 0.0)
	assert_gt(bars.drawn_position(0).y, 2.0, "above the head")


func test_begin_clears_and_extra_bars_are_dropped() -> void:
	var bars := FoeBars.new()
	add_child_autofree(bars)
	bars.begin()
	for i in FoeBars.MAX_BARS + 5:
		bars.add(Vector3.ZERO, 0.5, "scrapGoblin")
	bars.finish()
	assert_eq(bars.bar_count(), FoeBars.MAX_BARS)
	bars.begin()
	bars.finish()
	assert_eq(bars.multimesh.visible_instance_count, 0)
