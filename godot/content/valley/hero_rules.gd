## Numbers for the hero walkable graph (#385): how far the hero may have to walk and which
## walled-off pockets the valley may hold.
extends RefCounted

## The most steps (4-neighbour cells) the hero may need from the meadow's middle to the middle of
## a strip: (section id, steps) for Broken Ridge (1), Bluewater Crossing (2), Heartkeep (5).
const CAPS: Array[Vector2i] = [Vector2i(1, 32), Vector2i(2, 24), Vector2i(5, 32)]
## A walled-off walkable pocket larger than this that touches a socket block's ring is a problem.
const ISLAND_MAX_CELLS := 3
## The ring of cells around a socket block that counts as its neighbours.
const SOCKET_RING := 1
