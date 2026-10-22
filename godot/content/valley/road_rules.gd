## Numbers for the spline roads of the valley (#404, `docs/lessons/2026-10-21-spline-valley.md`).
extends RefCounted

## A road spline is sampled this many times per cell of chord between two waypoints, plus one,
## so consecutive samples are never more than half a cell apart and the rasterised cells have no
## gaps.
const SAMPLES_PER_CELL := 4
## A road cell's centre is never further than this many cells from the spline point it stands
## for (the rasterised cells stay on the curve).
const MAX_CELL_DEVIATION := 1.0

## The road as a band several foes walk side by side (#430). The layout valley's road is this
## wide, in cells; 0 keeps the one-cell road (and the old boards keep `OLD_WIDTH_CELLS`). The
## owner's target is 2.4, but the strict reach rule (a level 1 tower covers
## `SOCKET_MIN_ROAD_COVERAGE` road cells from every block) leaves no valley that stitches above
## about 1.1 cells (tables in the PR), so the band is off until the owner picks a way out.
const ROAD_WIDTH_CELLS := 0.0
const OLD_WIDTH_CELLS := 0.9
## A socket block's edge keeps at least this many cells from the band's edge: it may stand
## against the band but never on it (1.0 left a third of the blocks, #430).
const ROAD_CLEARANCE_CELLS := 0.0
