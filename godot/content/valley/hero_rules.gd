## Numbers for the hero walkable graph (#385).
extends RefCounted

## The most steps (4-neighbour cells) the hero may need from the meadow's middle to the middle of
## a strip: (section id, steps). Measured over seeds 1..300 with the real sections: worst Broken
## Ridge (1) 28, Bluewater Crossing (2) 22, Heartkeep (5) 14; caps keep 4, 4 and 6 steps of margin.
const CAPS: Array[Vector2i] = [Vector2i(1, 32), Vector2i(2, 26), Vector2i(5, 20)]
## A walled-off walkable pocket larger than this that touches a socket block's ring is a problem.
const ISLAND_MAX_CELLS := 3
## Cells around a socket block that count as its neighbours.
const SOCKET_RING := 1
## How far (cells) a straight walk keeps from a closed cell: the Knight's body (0.2) with room to
## spare, so a line never clips a corner. Used by `HeroGraph.walk`.
const WALK_CLEARANCE := 0.25
