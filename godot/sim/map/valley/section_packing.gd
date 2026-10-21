## Socket packing for the two end sections (#384): one block per bend, then scan order along the
## road, since a shuffled fill wastes the few sites of a narrow strip.
class_name SectionPacking
extends RefCounted

const END := preload("res://content/valley/end_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
## "No join bend", a cell off every board.
const NO_BEND := Vector2i(-1, -1)


## The turn a strip's road makes with its neighbour: its last cell (`at_end`) when the road
## arrives there vertically, since the next strip's road leaves it sideways, or its first cell
## when it leaves it vertically, since the previous strip's road arrives sideways.
static func join_bend(road: Array[Vector2i], at_end: bool) -> Vector2i:
	if at_end:
		var last := road[road.size() - 1]
		return last if road[road.size() - 2].x == last.x else NO_BEND
	return road[0] if road[1].x == road[0].x else NO_BEND


## Fills the result's sockets with up to `blocks.y` blocks (never over `blocked`). `join_bend` is
## a turn on the road's first or last cell, covered like the bends inside the strip.
static func pack(
	result: SectionResult,
	blocks: Vector2i,
	rng: Rng,
	blocked: Array[Rect2i],
	join_bend: Vector2i = NO_BEND
) -> void:
	var sites := SectionSockets.candidates(result, blocked)
	if rng.next_int(2) == 1:
		sites.reverse()
	var bends := SectionSockets.bends(result.road)
	if join_bend != NO_BEND:
		bends.push_front(join_bend)
	for bend in bends:
		var best := _nearest(sites, bend, result.sockets)
		if (
			best != Vector2i(-1, -1)
			and SectionSockets.centre_gap(best, bend) <= VALLEY.BEND_COVER_REACH
		):
			result.add_socket(best, 0, SectionResult.Tag.BEND)
	for site in sites:
		if result.sockets.size() >= blocks.y:
			break
		if SectionSockets.keeps_distance(site, result.sockets):
			result.add_socket(site, 0, SectionResult.Tag.LOW)


static func _nearest(sites: Array[Vector2i], bend: Vector2i, chosen: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_gap := 1.0e30
	for site in sites:
		var gap := SectionSockets.centre_gap(site, bend)
		if gap < best_gap and SectionSockets.keeps_distance(site, chosen):
			best = site
			best_gap = gap
	return best


## No problems when a block of the strip covers the join bend (the valley check accepts any
## strip's block, but a section must not count on one).
static func join_problems(result: SectionResult, join_bend: Vector2i) -> Array[String]:
	for anchor in result.sockets:
		if SectionSockets.centre_gap(anchor, join_bend) <= VALLEY.BEND_COVER_REACH:
			return []
	return (
		[] if join_bend == NO_BEND else ["no socket block covers the join bend at %s" % join_bend]
	)


## The first road shape (a `variant` of `SectionRoad.snake`, the Z last) whose draw passes the
## section's checks, else the last one tried; `draw` takes the variant.
static func first_passing(
	section: ValleySection, slot: ValleyPlan.Slot, rng: Rng, draw: Callable
) -> SectionResult:
	var start := rng.next_int(END.Z_VARIANT)
	var result: SectionResult = null
	for step in END.VARIANTS:
		var variant := (start + step) % END.Z_VARIANT if step < END.Z_VARIANT else END.Z_VARIANT
		result = draw.call(variant)
		if ValleyChecks.section_problems(slot, result, section).is_empty():
			break
	return result
