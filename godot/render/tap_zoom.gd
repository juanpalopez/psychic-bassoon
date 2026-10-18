## The 44 pt rule for the board: how big a socket is drawn, in points.
##
## A tap target must be at least `MIN_POINTS` across (Apple's minimum, CLAUDE.md, UI). On the
## 32x20 map the overview draws sockets smaller than that on a phone, so a tap there zooms in
## first, and building, upgrading and selling happen only where a socket is drawn that big.
## Plain maths so it can be tested: the camera rig measures a socket in canvas pixels with
## `narrowest_width`, and `points_per_pixel` turns canvas pixels into points.
class_name TapZoom
extends RefCounted

## The least tap target, in points.
const MIN_POINTS := 44.0


## How many points one canvas pixel is: the canvas is stretched to the window (`canvas_height`
## canvas pixels over `window_height` window pixels), and the screen has `screen_scale` window
## pixels per point (3 on an iPhone, 2 on a retina Mac, 1 on most desktops). A hidden window
## reports zeros: then a pixel counts as a point.
static func points_per_pixel(
	canvas_height: float, window_height: float, screen_scale: float
) -> float:
	if canvas_height <= 0.0 or window_height <= 0.0 or screen_scale <= 0.0:
		return 1.0
	return window_height / (canvas_height * screen_scale)


## The narrowest width of a convex shape drawn on screen (its corners in order): the least,
## over its sides, of how far the shape reaches away from that side. A finger fits on the
## shape only when this is at least the finger's size, whichever way the shape is turned.
static func narrowest_width(corners: PackedVector2Array) -> float:
	var narrowest := INF
	var count := corners.size()
	for i in count:
		var side := corners[(i + 1) % count] - corners[i]
		if side.length_squared() < 1e-12:
			continue
		var normal := Vector2(-side.y, side.x).normalized()
		var reach := 0.0
		for corner in corners:
			reach = maxf(reach, absf((corner - corners[i]).dot(normal)))
		narrowest = minf(narrowest, reach)
	return 0.0 if narrowest == INF else narrowest


## The four corners of a square `side` cells wide, flat at the height of `centre`, in order.
static func square_corners(centre: Vector3, side: float) -> Array[Vector3]:
	var half := side / 2.0
	return [
		centre + Vector3(-half, 0.0, -half),
		centre + Vector3(half, 0.0, -half),
		centre + Vector3(half, 0.0, half),
		centre + Vector3(-half, 0.0, half),
	]
