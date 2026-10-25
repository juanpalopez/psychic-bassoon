## Where an arrow for something off screen goes: on the screen's edge, pointing at it. Pure
## geometry, so the indicators only draw what it says.
class_name EdgeArrows
extends RefCounted


## One arrow: its tip's place on the canvas and the way it points (radians, 0 is right).
class Spot:
	extends RefCounted
	var position := Vector2.ZERO
	var angle: float = 0.0


## The arrow for a target drawn at `point` (as `Camera3D.unproject_position` gives it), or null
## when it is on screen. The arrow sits where the line from the middle of the canvas to the
## target meets `room`, the part of the canvas the HUD leaves free. A target behind the camera is
## drawn mirrored, so `behind` turns the line round.
static func spot(point: Vector2, behind: bool, canvas: Vector2, room: Rect2) -> Spot:
	if not behind and Rect2(Vector2.ZERO, canvas).has_point(point):
		return null
	var middle := canvas / 2.0
	var way := point - middle
	if behind:
		way = -way
	if way.length_squared() < 1e-9:
		way = Vector2.DOWN
	var reach := INF
	if absf(way.x) > 1e-9:
		var edge_x := room.end.x if way.x > 0.0 else room.position.x
		reach = minf(reach, (edge_x - middle.x) / way.x)
	if absf(way.y) > 1e-9:
		var edge_y := room.end.y if way.y > 0.0 else room.position.y
		reach = minf(reach, (edge_y - middle.y) / way.y)
	var result := Spot.new()
	result.position = middle + way * reach
	result.angle = way.angle()
	return result
