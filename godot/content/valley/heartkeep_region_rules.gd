## Numbers for the Heartkeep Approach on its 2D region (#408): the last bends of the road, a
## gentle rise around the Heartstone block and five or six sockets.
extends RefCounted

const SOCKET_MIN := 5
const SOCKET_MAX := 6
## The road runs straight down from the gate this many cells, sweeps to the far side (this far
## from the region's edge) about `SWEEP_AT` of the way to the exit row, and turns east for the
## last stretch, which starts this many cells from the east edge.
const LEAD := 3.5
const SIDE_MARGIN := 2.5
const SWEEP_AT := 0.5
const FINAL_LEAD := 4.5
## The ground this far from the road is terrace 1; within `RISE_REACH` cells of the Heartstone
## ground at least `RISE_GAP` from the road is terrace 2. Forest grows from `FOREST_GAP`.
const TERRACE_GAP := 3
const RISE_GAP := 4
const RISE_REACH := 7
const FOREST_GAP := 4
const DRAWS := 40
