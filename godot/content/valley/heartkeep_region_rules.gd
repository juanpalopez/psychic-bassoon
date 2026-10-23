## Numbers for the Heartkeep Approach on its 2D region (#408): around the composed road (#434), a
## gentle rise around the Heartstone block and five or six sockets.
extends RefCounted

const SOCKET_MIN := 5
const SOCKET_MAX := 6
## The ground this far from the road is terrace 1; within `RISE_REACH` cells of the Heartstone
## ground at least `RISE_GAP` from the road is terrace 2. Forest grows from `FOREST_GAP`.
const TERRACE_GAP := 3
const RISE_GAP := 4
const RISE_REACH := 7
const FOREST_GAP := 4
const DRAWS := 40
