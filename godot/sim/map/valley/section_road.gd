## Road shape shared by the two end sections (#384): a snake of long vertical runs, because a
## strip is only four to seven columns wide and a socket block needs a road run beside it.
class_name SectionRoad
extends RefCounted

const VALLEY := preload("res://content/valley/valley_rules.gd")
## Columns between two runs, so a 2x2 socket block fits in the lane.
const LANE_WIDTH := 2


## A road from the slot's entry to its exit in unit steps. A strip of five columns or more gets
## three runs: up (or down) from the entry to the edge of the board, all the way across to the
## A four-column strip has room for two runs only, and turns at either edge of the board, as the
## stream picks.
static func snake(slot: ValleyPlan.Slot, rng: Rng) -> Array[Vector2i]:
	var rows := slot.rect.size.y
	var near := VALLEY.GATE_MARGIN - 2
	var far := rows - 1 - near
	var left := slot.entry.x
	var right := slot.exit.x
	var road: Array[Vector2i] = [slot.entry]
	if right - left > LANE_WIDTH + 1:
		var top := rng.next_int(2) == 1
		var first := near if top else far
		var last := far if top else near
		var middle := right - 1
		_walk(road, Vector2i(left, first))
		_walk(road, Vector2i(middle, first))
		_walk(road, Vector2i(middle, last))
		_walk(road, Vector2i(right, last))
	else:
		var turn := far if rng.next_int(2) == 1 else near
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
