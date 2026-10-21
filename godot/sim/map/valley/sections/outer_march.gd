## Section A, Outer March: the road enters from the spawn gate on the west edge and winds in a
## long S over low, flat, walkable ground, with forest at the strip's edges.
class_name OuterMarch
extends ValleySection

const MARCH := preload("res://content/valley/outer_march_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	return SectionPacking.first_passing(
		self, slot, rng, func(v: int) -> SectionResult: return _draw(slot, rng, v)
	)


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
