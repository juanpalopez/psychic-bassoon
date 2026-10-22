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

const RIGHT := Vector2(1.0, 0.0)
const DOWN := Vector2(0.0, 1.0)

## The road is about this wide (#430); the clearance is the half width it needs free beside the
## road, the band's half plus a margin.
const WIDTH := 2.4
const CLEARANCE := 2.0

## Per template: `points`, `entry_heading`, `exit_heading`, `tag` (what it is for),
## `min_turn_radius` (the tightest bend, cells) and `scale` (the least and most the fitter may
## stretch it).
const DATA := {
	# A broad quarter bend.
	SWEEP:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.0, 0.0),
			Vector2(2.73, 0.46),
			Vector2(4.01, 1.73),
			Vector2(4.47, 3.47),
			Vector2(4.47, 4.47),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"bend",
		"min_turn_radius": 3.0,
		"scale": Vector2(0.7, 1.25),
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
	# Straight and flat from end to end, square to the river: 4 cells of approach, a span of at
	# least 2 cells (from x 4 to 6) and 4 cells of approach. It is never shrunk, only stretched,
	# so the approaches are at least 4 cells at every scale.
	BRIDGE:
	{
		"points": [Vector2(0.0, 0.0), Vector2(4.0, 0.0), Vector2(6.0, 0.0), Vector2(10.0, 0.0)],
		"entry_heading": RIGHT,
		"exit_heading": RIGHT,
		"tag": &"crossing",
		"min_turn_radius": 0.0,
		"scale": Vector2(1.0, 2.0),
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
		"scale": Vector2(0.7, 1.25),
	},
	# A gentle curve, then a straight stretch along the exit beside a ruin or the Heartstone.
	LANDMARK:
	{
		"points":
		[
			Vector2(0, 0),
			Vector2(1.0, 0.0),
			Vector2(2.48, 0.4),
			Vector2(3.57, 1.48),
			Vector2(3.97, 2.97),
			Vector2(3.97, 4.47),
			Vector2(3.97, 5.97),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"landmark",
		"min_turn_radius": 2.8,
		"scale": Vector2(0.7, 1.25),
	},
}
