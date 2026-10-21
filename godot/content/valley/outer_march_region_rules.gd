## Numbers for the Outer March on its 2D region (#408): a long S-bend from the west gate over low,
## flat ground, four or five sockets and forest at the region's outer edges.
extends RefCounted

const SOCKET_MIN := 4
const SOCKET_MAX := 5
## The road runs straight in this many cells from the gate, then climbs to a crest this many rows
## from the top (plus up to `CREST_JITTER`), swings to an apex this far from the region's right
## edge (and from the river), and comes back along a lower stretch `LOW_ROWS` above the bottom.
const LEAD := 3.5
const CREST_ROW := 1.5
const CREST_JITTER := 1
const APEX_MARGIN := 2.5
const APEX_RIVER_GAP := 3.0
const LOW_ROWS := 4.0
## How far along the way from the crest to the apex the first waypoint sits, and how far along
## the lower stretch (from the exit column) the turn back starts.
const CREST_AT := 0.55
const TURN_AT := 0.4
## The road comes down to the exit gate along its column from this many rows above the edge.
const EXIT_LEAD := 2.0
## Ground this far from the road is a low terrace; forest grows from `FOREST_GAP` (not under
## `FOREST_ROAD_GAP` of the road).
const TERRACE_GAP := 3
const FOREST_GAP := 3
## A draw that fails the section's checks is drawn again, this often at most.
const DRAWS := 8
