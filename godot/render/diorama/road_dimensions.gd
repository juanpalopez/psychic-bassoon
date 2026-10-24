## The diorama's sizes that depend on how wide the road is (`GameMap.road_width`, in cells): the
## bridge's deck, posts and trestle legs, the cut the bed makes at a bridge, and the Heartstone's
## yard. Each is the number the diorama always used at the old width (`DioramaLooks.ROAD_WIDTH`,
## exactly) and grows with the road beyond it, so a wide band (#446) keeps a bridge as wide as the
## road, a yard that ends it, and posts and legs outside the deck.
class_name RoadDimensions
extends RefCounted

const LOOKS := preload("res://render/diorama/diorama_looks.gd")


## How much wider than the old road a road of `road_width` is, in cells (0 at the old width, so
## adding it leaves the old numbers untouched).
static func growth(road_width: float) -> float:
	return road_width - LOOKS.ROAD_WIDTH


## The width of a bridge's deck: planks, hand-rope hangers and the ropes under the plank ends.
static func deck_width(road_width: float) -> float:
	return LOOKS.DECK_WIDTH + growth(road_width)


## How far across from the road's middle a bridge's posts stand.
static func post_out(road_width: float) -> float:
	return LOOKS.POST_OUT + growth(road_width) / 2.0


## How far across from the road's middle a trestle's legs stand.
static func trestle_out(road_width: float) -> float:
	return LOOKS.TRESTLE_OUT + growth(road_width) / 2.0


## How far (cells, each side) the bed's cut at a bridge reaches across the road beyond the bridge
## cell: far enough that the cut covers the bed's edge and its wobble at any width.
static func bed_cut_across(road_width: float) -> float:
	return maxf(LOOKS.BED_CUT_ACROSS, road_width / 2.0 + LOOKS.ROAD_WOBBLE)


## The radius of the flagstone yard under the Heartstone: never smaller than the old yard, and
## wider than the road's half width where the road is wide.
static func heart_yard_radius(road_width: float) -> float:
	return maxf(LOOKS.HEART_YARD_RADIUS, road_width / 2.0 + LOOKS.HEART_YARD_MARGIN)


## The radius of the round end of the road in its last cell (where the yard would run into a
## terrace); it grows with a wide road, so the road never ends in a smaller cap than itself.
static func heart_cap_radius(road_width: float) -> float:
	return LOOKS.HEART_CAP_RADIUS + maxf(0.0, growth(road_width)) / 2.0
