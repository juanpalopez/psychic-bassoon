## Section A, Outer March: the road enters from the spawn gate on the west edge and winds in a
## long S over low, flat, walkable ground, with forest at the strip's edges.
class_name OuterMarch
extends ValleySection

const END := preload("res://content/valley/end_rules.gd")
const MARCH := preload("res://content/valley/outer_march_rules.gd")


## The first road shape that passes the section's checks, else the last one tried.
func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var first := rng.next_int(END.Z_VARIANT)
	var result: SectionResult = null
	for step in END.VARIANTS:
		result = _draw(
			slot, rng, (first + step) % END.Z_VARIANT if step < END.Z_VARIANT else END.Z_VARIANT
		)
		if ValleyChecks.section_problems(slot, result, self).is_empty():
			break
	return result


func _draw(slot: ValleyPlan.Slot, rng: Rng, variant: int) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = SectionRoad.snake(slot, variant)
	var join := SectionPacking.join_bend(result.road, true)
	SectionPacking.pack(result, socket_range(), rng, reserved(slot), join)
	SectionGround.paint(result, MARCH.TERRACE_GAP, MARCH.FOREST_GAP)
	return result


func socket_range() -> Vector2i:
	return Vector2i(MARCH.SOCKET_MIN, MARCH.SOCKET_MAX)


func extra_problems(_slot: ValleyPlan.Slot, result: SectionResult) -> Array[String]:
	return SectionPacking.join_problems(result, SectionPacking.join_bend(result.road, true))
