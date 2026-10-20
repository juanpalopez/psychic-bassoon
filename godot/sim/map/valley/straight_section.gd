## A stand-in section (#381): the road runs straight to the middle of the strip, turns to the exit
## row and runs on, with socket blocks beside it. Each real section replaces it by extending
## `ValleySection` instead; until then the six section classes extend this one.
class_name StraightSection
extends ValleySection

const VALLEY := preload("res://content/valley/valley_rules.gd")


func generate(slot: ValleyPlan.Slot, rng: Rng) -> SectionResult:
	var result := SectionResult.create(slot)
	var turn := slot.rect.position.x + slot.rect.size.x / 2
	var row := slot.entry.y
	for x in range(slot.entry.x, turn + 1):
		result.road.append(Vector2i(x, row))
	while row != slot.exit.y:
		row += signi(slot.exit.y - row)
		result.road.append(Vector2i(turn, row))
	for x in range(turn + 1, slot.exit.x + 1):
		result.road.append(Vector2i(x, slot.exit.y))
	SectionSockets.place(result, socket_range(), rng, reserved(slot))
	return result


func socket_range() -> Vector2i:
	return Vector2i(VALLEY.STUB_SOCKET_MIN, VALLEY.STUB_SOCKET_MAX)
