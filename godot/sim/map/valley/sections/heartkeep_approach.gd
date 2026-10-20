## Section F, Heartkeep Approach: the last bends and the ramp to the Heartstone on the east edge.
## The road stays on the valley floor while the ground around the Heartstone rises in terraces;
## every cell stays walkable, so the hero can reach the Heartstone from the strip's entry.
class_name HeartkeepApproach
extends ValleySection

const KEEP := preload("res://content/valley/heartkeep_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = SectionRoad.snake(slot, rng)
	var blocked := reserved(slot)
	SectionPacking.pack(result, socket_range(), rng, blocked)
	(
		SectionGround
		. paint(
			result,
			KEEP.TERRACE_GAP,
			KEEP.FOREST_GAP,
			blocked[0],
			KEEP.RISE_GAP,
			KEEP.RISE_REACH,
		)
	)
	return result


func socket_range() -> Vector2i:
	return Vector2i(KEEP.SOCKET_MIN, KEEP.SOCKET_MAX)
