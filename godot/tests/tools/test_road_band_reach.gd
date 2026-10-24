## The road-time tool measures reach to the band's edge (#446, option B): a ground foe on the
## centre line is in reach when its distance is at most the reach plus half the band.
extends GutTest

const BAND := preload("res://tools/road_band_reach.gd")
const SPOOL_GUARD_L1 := 2.3


func test_half_the_band_is_half_its_width() -> void:
	assert_eq(BAND.half_band(0.9), 0.45)
	assert_eq(BAND.half_band(2.4), 1.2)


func test_a_negative_width_has_no_half_band() -> void:
	assert_eq(BAND.half_band(-1.0), 0.0)


func test_no_band_keeps_the_centre_line_reach_exactly() -> void:
	assert_eq(BAND.edge_reach(SPOOL_GUARD_L1, 0.0), SPOOL_GUARD_L1)


func test_the_spool_guard_reaches_the_drawn_band_edge() -> void:
	assert_almost_eq(BAND.edge_reach(SPOOL_GUARD_L1, 0.9), 2.75, 0.000001)


func test_the_spool_guard_reaches_the_wide_band_edge() -> void:
	assert_almost_eq(BAND.edge_reach(SPOOL_GUARD_L1, 2.4), 3.5, 0.000001)


func test_a_foe_just_inside_the_band_edge_is_in_reach() -> void:
	var edge := BAND.edge_reach(SPOOL_GUARD_L1, 0.9)
	assert_lte(2.7, edge, "a foe 2.7 cells from the centre line is in reach at width 0.9")
	assert_gt(2.8, edge, "a foe 2.8 cells from the centre line is out of reach at width 0.9")
