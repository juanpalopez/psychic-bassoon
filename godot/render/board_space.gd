## Where the sim's cells go in the 3D world.
##
## The board is landscape as the sim has it: a cell's column runs across the
## screen (world x rises with the column) and its row runs away from the camera
## (world z rises with the row, so row 0 is the far edge). The road starts at
## the left edge and ends at the right. This is the one place that knows (render
## code never converts on its own). A cell is one unit wide and the board is
## centred on the origin, on the ground plane y = 0.
class_name BoardSpace
extends RefCounted

const RULES := preload("res://content/map_rules.gd")

## What `world_to_cell` and the cell picker return for a point off the board.
const NO_CELL := Vector2i(-1, -1)


## The centre of a cell, on the ground.
static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3(
		float(col) - float(RULES.GRID_COLS - 1) / 2.0,
		0.0,
		float(row) - float(RULES.GRID_ROWS - 1) / 2.0
	)


## The middle of a square block of `footprint` cells whose top-left cell is
## `anchor`, on the ground (a block of one cell is just that cell).
static func footprint_centre(anchor: Vector2i, footprint: int) -> Vector3:
	var at := cell_to_world(anchor.x, anchor.y)
	var half := float(footprint - 1) / 2.0
	return Vector3(at.x + half, 0.0, at.z + half)


## The board's footprint in cells: x is across the screen (the columns), y is
## its depth (the rows).
static func size() -> Vector2:
	return Vector2(float(RULES.GRID_COLS), float(RULES.GRID_ROWS))


## The four outer corners of the board, on the ground.
static func corners() -> Array[Vector3]:
	var half := size() / 2.0
	return [
		Vector3(-half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, -half.y),
		Vector3(half.x, 0.0, half.y),
		Vector3(-half.x, 0.0, half.y),
	]


## Where a sim position goes in the world. Sim positions are in cells, with x
## across (a cell's centre is column + 0.5) and y down (row + 0.5); a road that
## starts by going right has its spawn point a little left of column 0
## (negative x). At a cell centre this agrees with `cell_to_world`.
static func point_to_world(sim_x: float, sim_y: float) -> Vector3:
	return Vector3(sim_x - float(RULES.GRID_COLS) / 2.0, 0.0, sim_y - float(RULES.GRID_ROWS) / 2.0)


## The cell under a point on the ground, or `NO_CELL` when it is off the board.
## The inverse of `cell_to_world` (any point inside a cell gives that cell).
static func world_to_cell(point: Vector3) -> Vector2i:
	var col := int(floor(point.x + float(RULES.GRID_COLS) / 2.0))
	var row := int(floor(point.z + float(RULES.GRID_ROWS) / 2.0))
	if row < 0 or row >= RULES.GRID_ROWS or col < 0 or col >= RULES.GRID_COLS:
		return NO_CELL
	return Vector2i(col, row)


## Where a ray meets the ground plane (y = 0), or null when it points up or
## along the ground, or the ground is behind it.
static func ground_hit(origin: Vector3, direction: Vector3) -> Variant:
	if direction.y >= -1e-9:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0:
		return null
	return origin + direction * distance
