extends GutTest
## The bridge, the yard and the bed cut follow the road's drawn width (#509, #446). At the old
## width (0.9) every number is the one the diorama always used, exactly; a wide band widens them.

const LOOKS := preload("res://render/diorama/diorama_looks.gd")
const OLD := 0.9
const WIDE := 2.4


func test_at_the_old_width_every_number_is_the_old_one_exactly() -> void:
	assert_eq(RoadDimensions.deck_width(OLD), LOOKS.DECK_WIDTH)
	assert_eq(RoadDimensions.post_out(OLD), LOOKS.POST_OUT)
	assert_eq(RoadDimensions.trestle_out(OLD), LOOKS.TRESTLE_OUT)
	assert_eq(RoadDimensions.bed_cut_across(OLD), LOOKS.BED_CUT_ACROSS)
	assert_eq(RoadDimensions.heart_yard_radius(OLD), LOOKS.HEART_YARD_RADIUS)
	assert_eq(RoadDimensions.heart_cap_radius(OLD), LOOKS.HEART_CAP_RADIUS)


func test_the_old_width_is_the_looks_road_width() -> void:
	assert_eq(OLD, LOOKS.ROAD_WIDTH)


func test_a_wide_band_gets_a_wide_deck_with_its_posts_and_legs_outside_it() -> void:
	assert_almost_eq(RoadDimensions.deck_width(WIDE), LOOKS.DECK_WIDTH + 1.5, 1e-6)
	assert_gt(RoadDimensions.deck_width(WIDE), WIDE, "the deck covers the whole band")
	# the posts stand outside the deck's edge by the same margin as on the old bridge
	var margin := LOOKS.POST_OUT - LOOKS.DECK_WIDTH / 2.0
	assert_almost_eq(
		RoadDimensions.post_out(WIDE) - RoadDimensions.deck_width(WIDE) / 2.0, margin, 1e-6
	)
	var inset := LOOKS.DECK_WIDTH / 2.0 - LOOKS.TRESTLE_OUT
	assert_almost_eq(
		RoadDimensions.deck_width(WIDE) / 2.0 - RoadDimensions.trestle_out(WIDE), inset, 1e-6
	)


func test_the_bed_cut_reaches_across_the_whole_band_and_its_wobble() -> void:
	# half the cut's cell (0.5) plus the growth reaches the bed's outer edge on both sides
	for width: float in [OLD, 1.6, WIDE, 4.0]:
		var reach := 0.5 + RoadDimensions.bed_cut_across(width)
		assert_gte(reach, width / 2.0 + LOOKS.ROAD_WOBBLE, "width %s" % width)


func test_the_yard_is_wider_than_the_band_it_ends() -> void:
	for width: float in [OLD, 1.6, WIDE]:
		assert_gt(RoadDimensions.heart_yard_radius(width), width / 2.0 + LOOKS.LIP_WIDTH)
		assert_gt(RoadDimensions.heart_cap_radius(width), width / 2.0)
	assert_almost_eq(
		RoadDimensions.heart_yard_radius(WIDE), WIDE / 2.0 + LOOKS.HEART_YARD_MARGIN, 1e-6
	)
	assert_almost_eq(RoadDimensions.heart_cap_radius(WIDE), LOOKS.HEART_CAP_RADIUS + 0.75, 1e-6)


func test_the_deck_rect_follows_the_map_width() -> void:
	var bridge := GameMap.Bridge.new()
	bridge.cell = Vector2i(5, 5)
	bridge.horizontal = true
	var old := RoadBedBuilder.deck_rect(bridge)
	assert_eq(old, RoadBedBuilder.deck_rect(bridge, OLD))
	var wide := RoadBedBuilder.deck_rect(bridge, WIDE)
	assert_almost_eq(wide.size.y - old.size.y, 1.5, 1e-6)
	assert_eq(wide.size.x, old.size.x, "the span along the road is the same")
	assert_eq(wide.get_center(), old.get_center())
	bridge.horizontal = false
	var upright := RoadBedBuilder.deck_rect(bridge, WIDE)
	assert_almost_eq(upright.size.x, wide.size.y, 1e-6)


func test_the_bridge_mesh_is_as_wide_as_the_maps_road() -> void:
	# the strip valley: one bridge, so the deck's growth is the road's
	var game := Game.create_on_strip_valley(1)
	var field := TerrainField.from_map(game.map, game.routes)
	var top := Callable(field, "top_at")
	var narrow := RoadBedBuilder.bridge_mesh(game.map, top).get_aabb()
	game.map.road_width = WIDE
	var wide := RoadBedBuilder.bridge_mesh(game.map, top).get_aabb()
	# the board is drawn turned, so the road's across is world x or z: either grows by the growth
	var grown := maxf(wide.size.x - narrow.size.x, wide.size.z - narrow.size.z)
	assert_almost_eq(grown, 1.5, 0.05, "the deck and posts spread by the growth")
