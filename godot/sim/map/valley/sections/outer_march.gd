## Section A, Outer March: the road enters from the spawn gate on the west edge and winds in a
## long S over low, flat, walkable ground, with forest at the strip's edges.
class_name OuterMarch
extends ValleySection

const MARCH := preload("res://content/valley/outer_march_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	result.road = SectionRoad.snake(slot, rng)
	SectionPacking.pack(result, socket_range(), rng, reserved(slot))
	SectionGround.paint(result, MARCH.TERRACE_GAP, MARCH.FOREST_GAP)
	return result


func socket_range() -> Vector2i:
	return Vector2i(MARCH.SOCKET_MIN, MARCH.SOCKET_MAX)
