## Section F, Heartkeep Approach: the last bends and the ramp to the Heartstone on the east edge.
## The road stays on the valley floor while the ground around the Heartstone rises in terraces;
## every cell stays walkable, so the hero can reach the Heartstone from the strip's entry.
class_name HeartkeepApproach
extends ValleySection

const KEEP := preload("res://content/valley/heartkeep_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	return SectionPacking.first_passing(
		self, slot, rng, func(v: int) -> SectionResult: return _draw(slot, rng, v)
	)


func _draw(slot: ValleyPlan.Slot, rng: Rng, variant: int) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = SectionRoad.snake(slot, variant)
	var blocked := reserved(slot)
	var join := SectionPacking.join_bend(result.road, false)
	SectionPacking.pack(result, socket_range(), rng, blocked, join)
	SectionGround.paint(
		result, KEEP.TERRACE_GAP, KEEP.FOREST_GAP, blocked[0], KEEP.RISE_GAP, KEEP.RISE_REACH
	)
	return result


func socket_range() -> Vector2i:
	return Vector2i(KEEP.SOCKET_MIN, KEEP.SOCKET_MAX)


func extra_problems(_slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	return SectionPacking.join_problems(result, SectionPacking.join_bend(result.road, false))
