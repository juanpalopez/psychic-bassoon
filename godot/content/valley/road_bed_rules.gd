## How coarsely the forked layout valley draws its road beds (#481): the second lane adds about
## 1,000 triangles to the terrain and road beds (cap 40,000), so its beds are thinned further than
## the game board's (`diorama_looks.gd`: 0.75 and 6 degrees). The drawn line stays within
## `test_diorama_fork.gd`'s measured deviation of the finer one.
extends RefCounted

## Points on a straight stretch of a forked map's bed are at most this far apart (cells).
const FORK_ROAD_STEP := 1.25
## A forked map's bed bends by no more than this many degrees a point.
const FORK_ROAD_BEND_DEGREES := 6.0
