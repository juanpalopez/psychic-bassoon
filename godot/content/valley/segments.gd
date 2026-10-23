## The valley's road segment library (#432, epic #404,
## `docs/lessons/2026-10-22-road-segment-library.md`): hand-authored road pieces in a local frame.
## The entry is at (0, 0) heading +x; +y is to the right of the heading (a right turn on screen,
## where y points down). Units are cells. `points` are the control points of a `RoadSpline`.
## Every template's first and last control points lie along its port headings, so a straight
## lead joins it without a kink. A template is tested alone (`test_road_segments.gd`).
extends RefCounted

const SWEEP := &"sweep"
const S_BEND := &"s_bend"
const BRIDGE := &"bridge"
const RIDGE_WRAP := &"ridge_wrap"
const LANDMARK := &"landmark"
const HOOK := &"hook"
const U_TURN := &"u_turn"

const RIGHT := Vector2(1.0, 0.0)
const DOWN := Vector2(0.0, 1.0)
const LEFT := Vector2(-1.0, 0.0)

## The road is about this wide (#430); the clearance is the half width it needs free beside the
## road, the band's half plus a margin.
const WIDTH := 2.4
const CLEARANCE := 2.0

## Per template: `points`, `entry_heading`, `exit_heading`, `tag` (what it is for),
## `min_turn_radius` (the tightest bend, cells) and `scale` (the least and most the fitter may
## stretch it).
const DATA := {
	# A quarter bend that grows broader where the region has room (to radius about 4).
	SWEEP:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.0, 0.0),
			Vector2(2.14, 0.23),
			Vector2(3.1, 0.87),
			Vector2(3.74, 1.83),
			Vector2(3.97, 2.97),
			Vector2(3.97, 3.97),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"bend",
		"min_turn_radius": 2.7,
		"scale": Vector2(0.75, 1.8),
	},
	# A broad S: a long diagonal with a gentle inflection, ending a quarter turn on. It keeps
	# running one way in both axes, so no cell is visited twice wherever it is placed.
	S_BEND:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.2, 0),
			Vector2(2.8, 0.45),
			Vector2(4.2, 1.4),
			Vector2(5.4, 2.2),
			Vector2(6.5, 3.2),
			Vector2(6.97, 4.7),
			Vector2(6.97, 5.7),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"weave",
		"min_turn_radius": 2.8,
		"scale": Vector2(0.75, 1.25),
	},
	# Straight and flat from end to end, square to the river: 2 cells of approach, a span of at
	# least 2 cells (centres 1 apart, x 2 to 3) and 1 cell past it, where the next bend's own
	# straight stub carries on (the valley's crossing leaves no more room). It is stretched, never
	# shrunk, so a longer approach or span only adds to the straight.
	BRIDGE:
	{
		"points": [Vector2(0.0, 0.0), Vector2(2.0, 0.0), Vector2(3.0, 0.0), Vector2(4.0, 0.0)],
		"entry_heading": RIGHT,
		"exit_heading": RIGHT,
		"tag": &"crossing",
		"min_turn_radius": 0.0,
		"scale": Vector2(1.0, 3.0),
	},
	# A broad bend (radius 4 or more) round high ground.
	RIDGE_WRAP:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.0, 0.0),
			Vector2(2.71, 0.34),
			Vector2(4.16, 1.31),
			Vector2(5.13, 2.76),
			Vector2(5.47, 4.47),
			Vector2(5.47, 5.47),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"wrap",
		"min_turn_radius": 4.0,
		"scale": Vector2(0.7, 1.8),
	},
	# A gentle curve, then a straight stretch along the exit beside a ruin or the Heartstone.
	LANDMARK:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.0, 0.0),
			Vector2(2.14, 0.23),
			Vector2(3.1, 0.87),
			Vector2(3.74, 1.83),
			Vector2(3.97, 2.97),
			Vector2(3.97, 3.97),
			Vector2(3.97, 4.97),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"landmark",
		"min_turn_radius": 2.8,
		"scale": Vector2(0.7, 1.8),
	},
	# A U-turn and then a quarter turn back: the road runs on, turns right through half a circle
	# (lanes 5.6 apart, so the lane rule holds from scale 0.95) and a left quarter turn leaves it
	# heading right of where it came in: a net quarter turn like the sweep, but about 25 cells
	# long. The tip is straight for a cell, so a half circle never grazes a cell edge and visits
	# a cell twice.
	HOOK:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(4.3, 0),
			Vector2(4.9, 0.08),
			Vector2(5.45, 0.31),
			Vector2(5.93, 0.67),
			Vector2(6.29, 1.15),
			Vector2(6.52, 1.7),
			Vector2(6.6, 2.3),
			Vector2(6.6, 3.3),
			Vector2(6.52, 3.9),
			Vector2(6.29, 4.45),
			Vector2(5.93, 4.93),
			Vector2(5.45, 5.29),
			Vector2(4.9, 5.52),
			Vector2(4.3, 5.6),
			Vector2(3.3, 5.6),
			Vector2(2.7, 5.68),
			Vector2(2.15, 5.91),
			Vector2(1.67, 6.27),
			Vector2(1.31, 6.75),
			Vector2(1.08, 7.3),
			Vector2(1, 7.9),
			Vector2(1, 8.2),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"hook",
		"min_turn_radius": 2.3,
		"scale": Vector2(0.95, 1.6),
	},
	# A half circle: the road comes in along one line and leaves back along the next, 5.6 cells over
	# (both gates on one border of a region). Only its side is fixed by the scale, never a lead.
	U_TURN:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(4.3, 0),
			Vector2(4.9, 0.08),
			Vector2(5.45, 0.31),
			Vector2(5.93, 0.67),
			Vector2(6.29, 1.15),
			Vector2(6.52, 1.7),
			Vector2(6.6, 2.3),
			Vector2(6.6, 3.3),
			Vector2(6.52, 3.9),
			Vector2(6.29, 4.45),
			Vector2(5.93, 4.93),
			Vector2(5.45, 5.29),
			Vector2(4.9, 5.52),
			Vector2(4.3, 5.6),
			Vector2(2.15, 5.6),
			Vector2(0, 5.6),
		],
		"entry_heading": RIGHT,
		"exit_heading": LEFT,
		"tag": &"u_turn",
		"min_turn_radius": 2.3,
		"scale": Vector2(0.95, 1.6),
	},
}
