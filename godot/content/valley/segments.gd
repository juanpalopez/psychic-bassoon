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
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(2.75, 0.47),
			Vector2(4.03, 1.75),
			Vector2(4.5, 3.5),
			Vector2(4.5, 4.5),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"bend",
		"min_turn_radius": 3.0,
		"scale": Vector2(0.6, 1.25),
	},
	# A small counter-bend, then the main bend: a broad S that ends a quarter turn on.
	S_BEND:
	{
		"points":
		[
			Vector2(0.0, 0.0),
			Vector2(1.5, -0.1),
			Vector2(3.0, -0.7),
			Vector2(4.5, -0.5),
			Vector2(5.6, 0.6),
			Vector2(6.0, 2.2),
			Vector2(6.0, 4.0),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"weave",
		"min_turn_radius": 2.2,
		"scale": Vector2(0.6, 1.25),
	},
	# Straight and flat from end to end, square to the river: at least four cells of approach on
	# each side of a span; the fitter stretches it to the river.
	BRIDGE:
	{
		"points": [Vector2(0.0, 0.0), Vector2(4.0, 0.0), Vector2(8.0, 0.0), Vector2(12.0, 0.0)],
		"entry_heading": RIGHT,
		"exit_heading": RIGHT,
		"tag": &"crossing",
		"min_turn_radius": 0.0,
		"scale": Vector2(0.25, 2.5),
	},
	# A broad bend (radius 4 or more) round high ground.
	RIDGE_WRAP:
	{
		"points":
		[
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(2.72, 0.34),
			Vector2(4.18, 1.32),
			Vector2(5.16, 2.78),
			Vector2(5.5, 4.5),
			Vector2(5.5, 5.5),
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
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(2.5, 0.4),
			Vector2(3.6, 1.5),
			Vector2(4.0, 3.0),
			Vector2(4.0, 4.5),
			Vector2(4.0, 6.0),
		],
		"entry_heading": RIGHT,
		"exit_heading": DOWN,
		"tag": &"landmark",
		"min_turn_radius": 2.8,
		"scale": Vector2(0.6, 1.25),
	},
}
