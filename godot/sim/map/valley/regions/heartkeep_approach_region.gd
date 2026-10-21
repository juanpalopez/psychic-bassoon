## Region 5, Heartkeep Approach: the final defence, bottom right (#408). The road bends twice on
## its way to the Heartstone on the east edge; the ground rises in terraces around the Heartstone
## block while the road stays on the floor and every cell stays walkable for the hero.
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
	var curve := RoadSpline.build(_waypoints(slot, rng))
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


## Gate, straight down, a sweep to the far side, and a last stretch east along the exit row.
func _waypoints(slot: ValleyPlan.Slot, rng: Rng) -> Array[Vector2]:
	var rect := slot.rect
	var gate_x := float(slot.entry.x) + 0.5
	var top := float(rect.position.y)
	var exit_y := float(slot.exit.y) + 0.5
	var near := gate_x - float(rect.position.x) < float(rect.size.x) / 2.0
	var side := (
		float(rect.end.x) - KEEP.SIDE_MARGIN - float(rng.next_int(2))
		if near
		else float(rect.position.x) + KEEP.SIDE_MARGIN + float(rng.next_int(2))
	)
	var sweep_y := top + (exit_y - top) * KEEP.SWEEP_AT
	var final_x := float(rect.end.x) - KEEP.FINAL_LEAD
	return [
		Vector2(slot.entry) + Vector2(0.5, 0.5),
		Vector2(gate_x, top + KEEP.LEAD),
		Vector2(side, sweep_y),
		Vector2(minf(final_x, (side + final_x) / 2.0), exit_y),
		Vector2(final_x, exit_y),
		Vector2(slot.exit) + Vector2(0.5, 0.5),
	]


func socket_range() -> Vector2i:
	return Vector2i(KEEP.SOCKET_MIN, KEEP.SOCKET_MAX)
