## Numbers for the valley laid out as 2D regions (#407, epic #404,
## `docs/lessons/2026-10-21-spline-valley.md`): where the six rectangles go on the 32 by 20
## board, how far the seed moves their borders, where the road crosses between them, and the
## river that winds from the top edge to the bottom edge.
extends RefCounted

## The board this layout is made for.
const COLS := 32
const ROWS := 20
## The regions in road order carry the ids 0 to 5; this is the `ValleyPlan.Id` each one plays
## (its kind), for the checks and the hero graph.
const ROLES: Array[int] = [0, 3, 2, 1, 4, 5]
## Base borders: the two vertical cuts (left|middle, middle|right) and the three horizontal
## ones (left column, middle column, right column). The seed moves each by up to `JITTER`.
const LEFT_X := 11
const RIGHT_X := 23
const LEFT_Y := 10
const MIDDLE_Y := 8
const RIGHT_Y := 9
const JITTER := 1
## The spawn is on the west edge, on one of these rows (inclusive); the road ends on the east
## edge on one of the end rows.
const SPAWN_ROWS := Vector2i(1, 3)
const END_ROWS := Vector2i(15, 17)
## Gates stay this many cells from the corners of the border they cross.
const GATE_INSET := 2
## The road crosses from the crossing to the ridge this far (min, max) left of the right border
## of the middle column, on the river's far bank.
const RIDGE_GATE_REACH := Vector2i(2, 4)
## The road runs straight in from a gate for LEAD cells before it starts to sway.
const LEAD := 3
## A region's spine has this many waypoints between its entry and exit, swaying to alternate
## sides of the chord by SWAY_MIN plus up to SWAY_SPAN cells, never nearer than SPINE_MARGIN
## cells to the region's edge.
const SPINE_MIDS := 2
const SWAY_MIN := 2
const SWAY_SPAN := 2
const SPINE_MARGIN := 2
## The river: its source is one of TOP_X (min, span) on the top row, its mouth one of
## BOTTOM_X on the bottom row, with RIVER_MIDS waypoints that wander by up to RIVER_WOBBLE
## cells off the straight line. It is RIVER_WIDTH cells wide (to the right of its centre line).
const TOP_X := Vector2i(11, 3)
const BOTTOM_X := Vector2i(14, 3)
const RIVER_MIDS := 2
const RIVER_WOBBLE := 2
const RIVER_WIDTH := 2
## A layout that fails its own checks is drawn again, at most this often.
const MAX_ATTEMPTS := 40
