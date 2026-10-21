## Numbers for section B, Broken Ridge (#387): the raised plateau beside the road.
extends RefCounted

## Socket blocks the section keeps (least, most), at most `HIGH_SOCKETS` of them on the ridge.
const SOCKETS_LEAST := 3
const SOCKETS_MOST := 4
const HIGH_SOCKETS := 1
## Terraces: the valley floor (the road), the step down to it, and the ridge top.
const FLOOR_LEVEL := 0
const STEP_LEVEL := 1
const RIDGE_LEVEL := 2
## Cells (Chebyshev) from the ridge block that stay ridge top, and where the foot of the ridge
## ends; a foot cell far from the road drops to the floor, which makes a cliff.
const TOP_RING := 1
const FOOT_RING := 2
## A cell this close (Chebyshev) to the road is never a cliff and never ridge top.
const ROAD_CLEARANCE := 1
## The road's two vertical runs are at least this many columns apart (a block fits between), and
## the second may stop this many columns short of the strip's right edge.
const COLUMN_GAP := 3
const EXIT_SLACK := 1
## Ridge sites tried before the section gives up and lets the stitcher draw it again.
const RIDGE_TRIES := 24
