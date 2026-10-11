## Turns a tap on the screen into a board cell: a ray from the camera through
## the tapped pixel, cut with the ground plane, then `BoardSpace.world_to_cell`.
class_name CellPicker
extends RefCounted


## The cell under `screen_position`, or `BoardSpace.NO_CELL` when the ray
## misses the ground or lands off the board.
static func cell_at(camera: Camera3D, screen_position: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = BoardSpace.ground_hit(origin, direction)
	if hit == null:
		return BoardSpace.NO_CELL
	return BoardSpace.world_to_cell(hit as Vector3)
