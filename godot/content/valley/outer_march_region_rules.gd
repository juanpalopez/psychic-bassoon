## Numbers for the Outer March on its 2D region (#408): low, flat ground around the composed road
## (#434), four or five sockets and forest at the region's outer edges.
extends RefCounted

const SOCKET_MIN := 4
const SOCKET_MAX := 5
## Ground this far from the road is a low terrace; forest grows from `FOREST_GAP` (not under
## `FOREST_ROAD_GAP` of the road).
const TERRACE_GAP := 3
const FOREST_GAP := 3
## A draw that fails the section's checks is drawn again, this often at most.
const DRAWS := 8
