## Numbers for section F, Heartkeep Approach (#384): the last bends of the road, dense sockets and
## ground that rises gently around the Heartstone while the road stays on the valley floor.
extends RefCounted

## The plan is five to six blocks, but a four-column strip holds a single column of them beside a
## road that cannot double back, and two or three is all it holds when the gates sit in the middle rows.
## The packer still fills up to `SOCKET_MAX`, so wider strips come out dense.
const SOCKET_MIN := 2
const SOCKET_MAX := 6
## Ground at least `TERRACE_GAP` cells from the road is terrace 1; within `RISE_REACH` cells of
## the Heartstone, ground at least `RISE_GAP` cells from the road is terrace 2.
const TERRACE_GAP := 3
const RISE_GAP := 4
const RISE_REACH := 8
const FOREST_GAP := 3
