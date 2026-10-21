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
const LEFT_X := 10
const RIGHT_X := 23
const LEFT_Y := 9
const MIDDLE_Y := 9
const RIGHT_Y := 9
const JITTER := 1
## The spawn is on the west edge, on one of these rows (inclusive); the road ends on the east
## edge on one of the end rows.
const SPAWN_ROWS := Vector2i(1, 3)
const END_ROWS := Vector2i(15, 17)
## Gates stay this many cells from the corners of the border they cross.
const GATE_INSET := 3
## The road crosses from the crossing to the ridge this far (min, max) left of the right border
## of the middle column, on the river's far bank.
const RIDGE_GATE_REACH := Vector2i(4, 5)
## The Ridge's road leaves for the Fold on one of these rows (inclusive), high on the plateau, so
## it runs a long way up beside room for socket blocks.
const RIDGE_EXIT_ROWS := Vector2i(2, 3)
## A region's road is one bend: a corner rounded by an arc of this radius, with waypoints at most
## SPINE_SPACING cells apart.
const BEND_RADIUS := 4
const SPINE_SPACING := 4.0
## The Crossing's road enters the river this many rows or more below the Ridge's border, so it
## has room to turn north on the far bank.
const CROSSING_DROP := 5
## The river: its source is one of TOP_X (min, span) on the top row, its mouth one of
## BOTTOM_X on the bottom row, with RIVER_MIDS waypoints that wander by up to RIVER_WOBBLE
## cells off the straight line. It is RIVER_WIDTH cells wide (to the right of its centre line).
const TOP_X := Vector2i(9, 3)
const BOTTOM_X := Vector2i(12, 3)
const RIVER_MIDS := 2
const RIVER_WOBBLE := 2
const RIVER_WIDTH := 2
## The river is drawn again, at most this often, until the Crossing has a row to enter on.
const RIVER_TRIES := 12
## A layout that fails its own checks is drawn again, at most this often.
const MAX_ATTEMPTS := 60
## A layout's sections are drawn again at most this often before the layout is thrown away.
const SECTION_ATTEMPTS := 6
## The stand-in sections keep this many socket blocks (least, most), enough to cover the bends
## of a curved road.
const STAND_IN_BLOCKS := Vector2i(1, 12)
## A socket block keeps this many empty cells (right, bottom) from its region's edges.
const BLOCK_MARGIN := Vector2i(1, 1)
## A turn is a bend to cover only between straight runs of this many steps (a diagonal stretch of
## a spline road is a staircase of one-step runs).
const BEND_RUN := 2
## The most steps the hero may need from the meadow to a kind of section (`ValleyPlan.Id`, steps).
## Provisional until the real sections exist: measured over seeds 1..3000 with the stand-in
## sections (worst Broken Ridge 31, Crossing 23, Heartkeep 35), plus 3 to 4 steps.
const HERO_CAPS: Array[Vector2i] = [Vector2i(1, 34), Vector2i(2, 27), Vector2i(5, 38)]

## The lane rule (#406): two stretches of the road at least `LANE_RUN` cells apart along it are
## at least `LANE_GAP` cells apart in a straight line, so a bend is a wide curve, never a snake of
## lanes or a hairpin.
const LANE_GAP := 5
const LANE_RUN := 12
