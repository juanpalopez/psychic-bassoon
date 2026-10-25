## How the board maps onto the minimap and back. The minimap shows the sim's board as it is
## (columns across, rows down, row 0 at the top, as the screen has them).
class_name MinimapMap
extends RefCounted


## The minimap's size: the board's shape scaled to fill `box` as far as it can.
static func fit(cols: int, rows: int, box: Vector2) -> Vector2:
	var scale := minf(box.x / float(cols), box.y / float(rows))
	return Vector2(float(cols), float(rows)) * scale


## Where a sim position (cells) is drawn on a minimap of `size` pixels.
static func to_pixel(sim: Vector2, cols: int, rows: int, size: Vector2) -> Vector2:
	return sim / Vector2(float(cols), float(rows)) * size


## The world point (x and z on the ground) under a pixel of the minimap, held to the board.
## It agrees with `BoardSpace.point_to_world`.
static func to_world(pixel: Vector2, cols: int, rows: int, size: Vector2) -> Vector2:
	var board := Vector2(float(cols), float(rows))
	var sim := (pixel / size).clamp(Vector2.ZERO, Vector2.ONE) * board
	return sim - board / 2.0
