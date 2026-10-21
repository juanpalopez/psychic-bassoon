## One valley section's generator (#381). A section draws its strip from the stream it is given
## and returns a `SectionResult`; it never reads another section or the board.
class_name ValleySection
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## The strip's road, sockets and terrain. Subclasses override it.
func generate(_slot: ValleyPlan.Slot, _rng: Rng) -> SectionResult:
	push_error("ValleySection.generate is not implemented")
	return null


## The fewest and most socket blocks the section keeps, as (least, most).
func socket_range() -> Vector2i:
	return Vector2i.ZERO


## Cells a socket block may not cover: the Heartstone's footprint, in the last section.
func reserved(slot: ValleyPlan.Slot) -> Array[Rect2i]:
	var blocked: Array[Rect2i] = []
	if slot.id == ValleyPlan.Id.HEARTKEEP_APPROACH:
		var cols := slot.rect.end.x
		var rows := slot.rect.size.y
		blocked.append(MapGen._heartstone_block(slot.exit, cols, rows, RULES.GAME_SOCKET_FOOTPRINT))
	return blocked


## Checks only this section has (a bridge, a meadow, a merge): the problems found, or none. It
## runs with the common checks, and a problem makes the stitcher draw this section again.
func extra_problems(_slot: ValleyPlan.Slot, _result: SectionResult) -> Array[String]:
	return []
