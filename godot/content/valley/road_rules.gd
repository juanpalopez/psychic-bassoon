## Numbers for the spline roads of the valley (#404, `docs/lessons/2026-10-21-spline-valley.md`).
extends RefCounted

## A road spline is sampled this many times per cell of chord between two waypoints, plus one,
## so consecutive samples are never more than half a cell apart and the rasterised cells have no
## gaps.
const SAMPLES_PER_CELL := 4
## A road cell's centre is never further than this many cells from the spline point it stands
## for (the rasterised cells stay on the curve).
const MAX_CELL_DEVIATION := 1.0

## The old boards' road width, in cells: the width the road bed is drawn at
## (`DioramaLooks.ROAD_WIDTH` holds the same number, a test checks) and `GameMap.road_width`'s
## default.
const OLD_WIDTH_CELLS := 0.9
## The road as a band several foes walk side by side (#430). The layout valley's road is this
## wide, in cells, and every cell the band touches is road (#469), so the drawn bed stays on road
## cells; 0 keeps the one-cell road. The owner's target is 2.4 (#446).
const ROAD_WIDTH_CELLS := OLD_WIDTH_CELLS
## A socket block's edge keeps at least this many cells from the band's edge: it may stand
## against the band but never on it (1.0 left a third of the blocks, #430).
const ROAD_CLEARANCE_CELLS := 0.0
## How far from a block's centre the centre-line cells count towards its coverage on a band
## (owner, 2026-10-24, #469). The one-cell roads keep `SOCKET_COVERAGE_REACH`: the band's cells
## lie further from the blocks, so the same three cells need a little more reach.
const BAND_COVERAGE_REACH := 2.7
