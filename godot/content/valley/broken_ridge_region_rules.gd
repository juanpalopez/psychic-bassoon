## Numbers for the Broken Ridge region (#410, epic #404): the raised plateau beside the spline
## road. The terraces and the cliff rules are the strip ridge's (`broken_ridge_rules.gd`).
extends RefCounted

## Socket blocks kept (least, most), one of them on the plateau; the layout often leaves room for
## only two.
const SOCKETS_LEAST := 2
const SOCKETS_MOST := 4
## The low blocks placed before the plateau (least, most), so the plateau never takes their room.
const LOW_BLOCKS := Vector2i(1, 3)
## The ridge top's terrace (the range bonus level).
const RIDGE_LEVEL := 2
## Cells (Chebyshev) around the high block that rise onto the plateau, as many terraces above
## the road as they are cells from it, so road, step and top form a ramp.
const PLATEAU_RING := 2
## Placements of the low blocks tried (each with every site for the high block).
const LOW_TRIES := 6
