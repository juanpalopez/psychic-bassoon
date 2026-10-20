## Numbers for section A, Outer March (#384): a gentle S-curve from the spawn gate, four to five
## low sockets and a forest edge.
extends RefCounted

## Sockets the section keeps, as (least, most) blocks.
const SOCKET_MIN := 4
const SOCKET_MAX := 5
## Ground at least `TERRACE_GAP` cells from the road is a low terrace (height 1) and, there,
## forest grows at the strip's edges.
const TERRACE_GAP := 3
const FOREST_GAP := 3
