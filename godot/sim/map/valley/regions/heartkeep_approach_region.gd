## Region 5, Heartkeep Approach: the final defence, bottom right (#408). The road is the layout's
## composed spine to the Heartstone on the east edge (#434); the ground rises in terraces around
## the Heartstone block while the road stays on the floor and every cell stays walkable for the
## hero.
class_name HeartkeepApproachRegion
extends RegionStraightSection

const KEEP := preload("res://content/valley/heartkeep_region_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result: SectionResult = null
	for draw in KEEP.DRAWS:
		result = _draw(slot, rng)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	return result


func _draw(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var curve := RoadSpline.build(slot.spine)
	result.road = curve.cells
	result.road_curve = curve
	var blocked := reserved(slot)
	for cell in slot.river:
		result.river.append(cell)
		result.set_walkable(cell, false)
		blocked.append(Rect2i(cell, Vector2i.ONE))
	SectionSockets.place(result, socket_range(), rng, blocked)
	SectionGround.paint(
		result, KEEP.TERRACE_GAP, KEEP.FOREST_GAP, reserved(slot)[0], KEEP.RISE_GAP, KEEP.RISE_REACH
	)
	return result


func socket_range() -> Vector2i:
	return Vector2i(KEEP.SOCKET_MIN, KEEP.SOCKET_MAX)
