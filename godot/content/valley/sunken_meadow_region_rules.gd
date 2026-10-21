## Numbers for the Sunken Meadow region (#410, epic #404): a large open walkable area the spline
## road wanders through, with a few boulder clusters.
extends RefCounted

## Socket blocks the region keeps (least, most).
const SOCKETS_LEAST := 4
const SOCKETS_MOST := 5
## Boulder clusters (least, most) and the longest side of one (cells), each tried this often.
## A cluster keeps one empty cell from the road, the blocks, the river, other clusters and the
## region's edge, so it never cuts the walkable ground in two.
const BOULDER_CLUSTERS := Vector2i(2, 4)
const BOULDER_SIDE := 2
const BOULDER_TRIES := 40
## Sets of sockets drawn from the section's stream before the best is kept.
const TRIES := 30
