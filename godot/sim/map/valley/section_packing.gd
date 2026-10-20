## Socket packing for the two end sections (#384). A strip is only four to seven columns wide, so
## blocks are packed in scan order along the road (three rows apart in a lane) after one block
## covers each bend; a shuffled fill leaves gaps that waste the few sites there are.
class_name SectionPacking
extends RefCounted

const VALLEY := preload("res://content/valley/valley_rules.gd")


## Fills the result's sockets with `blocks.x` to `blocks.y` blocks (never over `blocked`).
static func pack(result: SectionResult, blocks: Vector2i, rng: Rng, blocked: Array[Rect2i]) -> void:
	var sites := SectionSockets.candidates(result, blocked)
	if rng.next_int(2) == 1:
		sites.reverse()
	var target: int = blocks.y
	for bend in SectionSockets.bends(result.road):
		var best := _nearest(sites, bend, result.sockets)
		if (
			best != Vector2i(-1, -1)
			and SectionSockets.centre_gap(best, bend) <= VALLEY.BEND_COVER_REACH
		):
			result.add_socket(best, 0, SectionResult.Tag.BEND)
	for site in sites:
		if result.sockets.size() >= target:
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
