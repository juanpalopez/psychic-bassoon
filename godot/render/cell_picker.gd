## Turns a tap on the screen into a board cell: a ray from the camera through
## the tapped pixel. Without tile heights it is cut with the ground plane. With
## them (`surface_height` takes a cell and gives the top of its tile) the ray
## is walked down from above the tallest tile until it first dips below the top
## of the tile it is over, so a tap on a raised socket picks the socket and not
## the cell behind it.
class_name CellPicker
extends RefCounted

## Above the tallest tile the board can have (a level 2 socket is 2.0 high).
const TOP := 2.1
## How far the ray moves per step while it is walked down, in world units.
const STEP := 0.02


## The cell under `screen_position`, or `BoardSpace.NO_CELL` when the ray
## misses the ground or lands off the board.
static func cell_at(
	camera: Camera3D, screen_position: Vector2, surface_height: Callable = Callable()
) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = BoardSpace.ground_hit(origin, direction)
	if hit == null:
		return BoardSpace.NO_CELL
	if not surface_height.is_valid():
		return BoardSpace.world_to_cell(hit as Vector3)
	# walk from the height of the tallest tile down to the ground
	var from_ground := ((hit as Vector3) - origin).length()
	var from_top := from_ground - TOP / absf(direction.y)
	var distance := maxf(from_top, 0.0)
	while distance < from_ground:
		var point := origin + direction * distance
		var cell := BoardSpace.world_to_cell(point)
		if cell != BoardSpace.NO_CELL and point.y <= float(surface_height.call(cell)):
			return cell
		distance += STEP
	return BoardSpace.world_to_cell(hit as Vector3)
