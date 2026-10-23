## Region 0, Outer March: the main entrance, top left (#408). The road is the layout's composed
## spine from the west gate (#434); the region lays low, flat, walkable ground around it, with
## sockets spread around the road and forest at its outer edges.
class_name OuterMarchRegion
extends RegionStraightSection

const MARCH := preload("res://content/valley/outer_march_region_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result: SectionResult = null
	for draw in MARCH.DRAWS:
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
	SectionGround.paint(result, MARCH.TERRACE_GAP, MARCH.FOREST_GAP)
	return result


func socket_range() -> Vector2i:
	return Vector2i(MARCH.SOCKET_MIN, MARCH.SOCKET_MAX)
