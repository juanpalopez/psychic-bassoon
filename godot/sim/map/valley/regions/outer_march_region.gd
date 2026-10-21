## Region 0, Outer March: the main entrance, top left (#408). The road enters from the west gate
## and winds in a long smooth S over low, flat, walkable ground, with sockets spread around it
## and forest at the region's outer edges.
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
	var curve := RoadSpline.build(_waypoints(slot, rng))
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


## Gate, a straight lead, the crest, the apex, the turn back along the lower stretch, and down
## the exit column to the gate on the region's bottom edge.
func _waypoints(slot: ValleyPlan.Slot, rng: Rng) -> Array[Vector2]:
	var rect := slot.rect
	var width := float(rect.size.x)
	var height := float(rect.end.y)
	var wet := width
	for cell in slot.river:
		wet = minf(wet, float(cell.x) - MARCH.APEX_RIVER_GAP)
	var apex := minf(width - MARCH.APEX_MARGIN, wet) - float(rng.next_int(2))
	var crest := MARCH.CREST_ROW + float(rng.next_int(MARCH.CREST_JITTER + 1))
	var low := height - MARCH.LOW_ROWS
	var gate_y := float(slot.entry.y) + 0.5
	var exit_x := float(slot.exit.x) + 0.5
	return [
		Vector2(slot.entry) + Vector2(0.5, 0.5),
		Vector2(MARCH.LEAD, gate_y),
		Vector2(apex * MARCH.CREST_AT, crest),
		Vector2(apex, (crest + low) / 2.0),
		Vector2(exit_x + (apex - exit_x) * MARCH.TURN_AT, low),
		Vector2(exit_x, height - MARCH.EXIT_LEAD),
		Vector2(slot.exit) + Vector2(0.5, 0.5),
	]


func socket_range() -> Vector2i:
	return Vector2i(MARCH.SOCKET_MIN, MARCH.SOCKET_MAX)
