## Numbers for the Broken Ridge region (#410, epic #404): the raised plateau beside the spline
## road. The terraces and the cliff rules are the strip ridge's (`broken_ridge_rules.gd`).
extends RefCounted

## Socket blocks the region keeps (least, most); exactly one of them stands on the plateau. The
## ticket asks for 3 to 4, but the layout often leaves a strip of dry ground only wide enough
## for the plateau and one or two blocks beside the road, so the least is 2.
const SOCKETS_LEAST := 2
const SOCKETS_MOST := 4
## The low blocks placed before the plateau (least, most), so the plateau never takes their room.
const LOW_BLOCKS := Vector2i(1, 3)
## The ridge top's terrace (the range bonus level).
const RIDGE_LEVEL := 2
## Cells (Chebyshev) around the high block that rise onto the plateau. A plateau cell stands as
## many terraces above the road as it is cells from it (up to the ridge level), so the road, a
## step and the ridge top always form a ramp; the cells past the rim are the valley floor.
const PLATEAU_RING := 2
## Placements of the low blocks tried (each with every site for the high block).
const LOW_TRIES := 6
