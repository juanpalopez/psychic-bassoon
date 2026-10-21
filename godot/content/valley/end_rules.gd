## Numbers the two end sections share (#384): road shape and ground levels.
extends RefCounted

## The snake road turns on this row at the top edge of the board, and this many rows in from the
## bottom edge.
const EDGE_ROW := 1
## A strip at least this many columns wide gets a road of three runs, narrower ones two.
const THREE_RUN_WIDTH := 5
## Distance given to a cell when there is no road to measure from.
const NO_ROAD_GAP := 1000000
## Chebyshev distance from the road at which dirt lies.
const DIRT_GAP := 1
## Terraces: the valley floor, a low terrace and the rise around the Heartstone.
const FLOOR_LEVEL := 0
const LOW_LEVEL := 1
const RISE_LEVEL := 2
## The road shapes a section tries (which edge the snake leaves toward), in an order the
## stream picks.
const VARIANTS := 3
const Z_VARIANT := 2
