## A stand-in section for the 2D layout (#407): the road is the spline through the region's spine,
## and socket blocks sit beside it, off the river. A real section replaces it later.
class_name RegionStraightSection
extends ValleySection

const LAYOUT := preload("res://content/valley/layout_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var curve := RoadSpline.build(slot.spine)
	result.road = curve.cells
	result.road_curve = curve
	var blocked := reserved(slot)
	for cell in slot.river:
		result.river.append(cell)
		result.set_walkable(cell, curve.cells.has(cell))
		blocked.append(Rect2i(cell, Vector2i.ONE))
		if curve.cells.has(cell):
			var bridge := GameMap.Bridge.new()
			bridge.cell = cell
			result.bridges.append(bridge)
	SectionSockets.place(result, socket_range(), rng, blocked)
	return result


func socket_range() -> Vector2i:
	return LAYOUT.STAND_IN_BLOCKS
