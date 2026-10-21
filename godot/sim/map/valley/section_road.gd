## Road shape of the two end sections (#384): long vertical runs, since a socket block needs a
## run beside it and a strip is only four to seven columns wide.
class_name SectionRoad
extends RefCounted

const END := preload("res://content/valley/end_rules.gd")


## A road from the slot's entry to its exit in unit steps. A strip of `THREE_RUN_WIDTH` columns
## or more gets three runs: from the entry to an edge of the board, all the way across to the
## other edge in the second-to-last column, and back to the exit's row in the last column. A
## narrower strip has room for two runs, and turns at an edge of the board. `variant` 0 or 1
## picks which edge, so a section can try both; `Z_VARIANT` is a single turn at the exit's column,
## for gates so low or so close that the snake leaves no room.
static func snake(slot: ValleyPlan.Slot, variant: int) -> Array[Vector2i]:
	var rows := slot.rect.size.y
	var near := END.EDGE_ROW
	var far := rows - 1 - near
	var left := slot.entry.x
	var right := slot.exit.x
	var road: Array[Vector2i] = [slot.entry]
	if variant == END.Z_VARIANT:
		_walk(road, Vector2i(right, slot.entry.y))
	elif right - left + 1 >= END.THREE_RUN_WIDTH:
		var top := variant == 1
		var first := near if top else far
		var last := far if top else near
		var middle := right - 1
		_walk(road, Vector2i(left, first))
		_walk(road, Vector2i(middle, first))
		_walk(road, Vector2i(middle, last))
		_walk(road, Vector2i(right, last))
	else:
		var turn := far if variant == 1 else near
		_walk(road, Vector2i(left, turn))
		_walk(road, Vector2i(right, turn))
	_walk(road, slot.exit)
	return road


static func _walk(road: Array[Vector2i], target: Vector2i) -> void:
	var at := road[road.size() - 1]
	while at != target:
		if at.x != target.x:
			at.x += signi(target.x - at.x)
		else:
			at.y += signi(target.y - at.y)
		road.append(at)
