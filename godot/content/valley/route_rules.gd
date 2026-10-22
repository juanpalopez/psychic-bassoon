## Numbers for fitting road segments to the valley's gates and composing a route (#433, epic
## #404, `docs/lessons/2026-10-22-road-segment-library.md`).
extends RefCounted

const SEGMENTS := preload("res://content/valley/segments.gd")

## The four axis directions a template can be turned to (a mirror is tried for each).
const AXES: Array[Vector2] = [
	Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)
]
## A fitted port must point within this cosine of the gate's heading (about 18 degrees).
const HEADING_COS := 0.95
## The most straight lead (cells) the fitter adds before or after a template to reach the gates.
const LEAD_MAX := 4.0
## A lead or a residual shorter than this is dropped (cells).
const EPSILON := 0.01
## A straight template (a bridge) may be off the gate's row by at most this much.
const FLAT_TOLERANCE := 0.01
## Waypoints (but the gates) stay this far in from the region's edge (cells).
const MARGIN := 0.5
## The cosine of the turn between two consecutive one cell steps of the road stays above this.
const CURVE_COS := 0.82

## The segment sequences a region may use, by region (`ValleyLayout.Region`): the Outer March,
## the Sunken Meadow, the Bluewater Crossing (a bridge, then a bend away from the river), the
## Broken Ridge, the Ancient Fold and the Heartkeep Approach. The seed picks one.
const ALLOWED: Array = [
	[[SEGMENTS.SWEEP], [SEGMENTS.S_BEND]],
	[[SEGMENTS.S_BEND], [SEGMENTS.SWEEP]],
	[[SEGMENTS.BRIDGE, SEGMENTS.SWEEP]],
	[[SEGMENTS.RIDGE_WRAP]],
	[[SEGMENTS.LANDMARK]],
	[[SEGMENTS.SWEEP], [SEGMENTS.LANDMARK]],
]
## The bias in [0, 1] that picks a scale between the least and the most that fits: 0 the tightest
## bend with the longest leads, 1 the broadest. The seed draws one of `BIAS_STEPS` values; the
## crossing, which its own section draws again from the same data, always uses `CROSSING_BIAS`.
const BIAS_STEPS := 4
const BIAS_FLOOR := 0.7
const CROSSING_BIAS := 1.0
## A route is drawn again at most this often (each time with the next draws of the stream).
const ATTEMPTS := 8
## The road, end to end, is between these many cells (least, most).
const LENGTH := Vector2i(60, 170)
## No template is used more than this many times in a row along the route.
const MAX_REPEAT := 2
