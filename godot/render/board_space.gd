## Where the sim's cells go in the 3D world.
##
## The sim is untouched: it counts a cell's column across and its row down,
## spawn at row 0. The board is drawn turned a quarter so the road runs left to
## right, which suits a landscape phone: the sim row becomes world x, and the
## sim column runs away from the camera (world z falls as the column rises).
## It is a rotation, not a mirror, exactly like the Three.js build (tag
## `web-three-final`, `space.ts`: world z = cols - sim x), so a seed looks the
## same in both. This is the one place that knows (render code never converts
## on its own). A cell is one unit wide and the board is centred on
## the origin, on the ground plane y = 0.
class_name BoardSpace
extends RefCounted

const RULES := preload("res://content/map_rules.gd")

## What `world_to_cell` and the cell picker return for a point off the board.
const NO_CELL := Vector2i(-1, -1)


## The centre of a cell, on the ground.
static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3(
		float(row) - float(RULES.GRID_ROWS - 1) / 2.0,
		0.0,
		float(RULES.GRID_COLS - 1) / 2.0 - float(col)
	)


## The board's footprint in cells: x is across the screen (the sim's rows),
## y is its depth (the sim's columns).
static func size() -> Vector2:
	return Vector2(float(RULES.GRID_ROWS), float(RULES.GRID_COLS))


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
## across (a cell's centre is column + 0.5) and y down (row + 0.5); the spawn
## point sits a little above the top row (negative y). At a cell centre this
## agrees with `cell_to_world`.
static func point_to_world(sim_x: float, sim_y: float) -> Vector3:
	return Vector3(sim_y - float(RULES.GRID_ROWS) / 2.0, 0.0, float(RULES.GRID_COLS) / 2.0 - sim_x)


## The cell under a point on the ground, or `NO_CELL` when it is off the board.
## The inverse of `cell_to_world` (any point inside a cell gives that cell).
static func world_to_cell(point: Vector3) -> Vector2i:
	var row := int(floor(point.x + float(RULES.GRID_ROWS) / 2.0))
	var col := int(floor(float(RULES.GRID_COLS) / 2.0 - point.z))
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
