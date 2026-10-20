## What one valley section returns (#381): its strip's road, sockets, terrain and walkable
## ground, all in whole-board cell coordinates. The stitcher merges the six into one `GameMap`.
## The per-cell layers cover the section's strip only, stored row by row.
class_name SectionResult
extends RefCounted

## Why a socket is where it is, so the validators can ask for the right ones.
enum Tag { LOW, HIGH, BEND, MERGE, BANK }

var id: int = 0
var rect := Rect2i()
## The main road through the strip, from the slot's entry to its exit.
var road: Array[Vector2i] = []
## The second road's cells before the main road (the feeder), ending next to the cell where it
## joins; only the section that holds the merge fills it.
var feeder: Array[Vector2i] = []
## The anchors (top-left cells) of the 2x2 socket blocks, each with its elevation level (0 to 2)
## and `Tag`, in parallel arrays.
var sockets: Array[Vector2i] = []
var socket_levels: Array[int] = []
var socket_tags: Array[int] = []
## One terrace (0 to `TERRAIN_LEVELS - 1`) and one `GameMap.Region` per cell of the strip, and
## whether a hero can stand there (1) or not (0: water, cliff, rock).
var heights := PackedByteArray()
var regions := PackedByteArray()
var walkable := PackedByteArray()
## The river's cells in this strip, top to bottom, the road's bridges over it and the cells of
## the bridges only a hero can use.
var river: Array[Vector2i] = []
var bridges: Array[GameMap.Bridge] = []
var hero_bridges: Array[Vector2i] = []


## An empty result for a slot: terrace 0, meadow, walkable everywhere.
static func create(slot: ValleyPlan.Slot) -> SectionResult:
	var result := SectionResult.new()
	result.id = slot.id
	result.rect = slot.rect
	var count := slot.rect.size.x * slot.rect.size.y
	result.heights.resize(count)
	result.regions.resize(count)
	result.regions.fill(GameMap.Region.MEADOW)
	result.walkable.resize(count)
	result.walkable.fill(1)
	return result


## True when the cell is inside the section's strip.
func has_cell(cell: Vector2i) -> bool:
	return rect.has_point(cell)


func height_at(cell: Vector2i) -> int:
	return heights[_index(cell)]


func set_height(cell: Vector2i, level: int) -> void:
	heights[_index(cell)] = level


func region_at(cell: Vector2i) -> int:
	return regions[_index(cell)]


func set_region(cell: Vector2i, region: int) -> void:
	regions[_index(cell)] = region


func is_walkable(cell: Vector2i) -> bool:
	return walkable[_index(cell)] == 1


func set_walkable(cell: Vector2i, value: bool) -> void:
	walkable[_index(cell)] = 1 if value else 0


## Adds a socket block anchored at `anchor`.
func add_socket(anchor: Vector2i, level: int, tag: int) -> void:
	sockets.append(anchor)
	socket_levels.append(level)
	socket_tags.append(tag)


func _index(cell: Vector2i) -> int:
	assert(has_cell(cell), "cell %s is outside the section" % cell)
	return (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)
