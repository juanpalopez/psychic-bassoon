## Where the sim's cells go in the 3D world.
##
## The sim is untouched: it counts a cell's column across and its row down,
## spawn at row 0. The board is drawn turned so the road runs left to right,
## which suits a landscape phone: the sim row becomes world x and the sim
## column becomes world z. This is the one place that knows (render code never
## converts on its own). A cell is one unit wide and the board is centred on
## the origin, on the ground plane y = 0.
class_name BoardSpace
extends RefCounted

const RULES := preload("res://content/map_rules.gd")


## The centre of a cell, on the ground.
static func cell_to_world(col: int, row: int) -> Vector3:
	return Vector3(
		float(row) - float(RULES.GRID_ROWS - 1) / 2.0,
		0.0,
		float(col) - float(RULES.GRID_COLS - 1) / 2.0
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
