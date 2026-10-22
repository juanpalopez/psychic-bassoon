## Numbers for the spline roads of the valley (#404, `docs/lessons/2026-10-21-spline-valley.md`).
extends RefCounted

## A road spline is sampled this many times per cell of chord between two waypoints, plus one,
## so consecutive samples are never more than half a cell apart and the rasterised cells have no
## gaps.
const SAMPLES_PER_CELL := 4
## A road cell's centre is never further than this many cells from the spline point it stands
## for (the rasterised cells stay on the curve).
const MAX_CELL_DEVIATION := 1.0

## The road as a band several foes walk side by side (#430). The layout valley's road bed is
## this wide, in cells; the old boards keep `OLD_WIDTH_CELLS`. A foe is about 0.4 cells across,
## so the band takes five foes abreast (see `FoeSpread`).
const ROAD_WIDTH_CELLS := 2.4
const OLD_WIDTH_CELLS := 0.9
## A socket block's edge keeps at least this many cells from the band's edge. 1.0 (the ticket's
## number) leaves a third of the sockets and 0.25 fails to stitch on 10 of 60 seeds; with 0.0 a
## block may stand against the band but never on it, and every seed stitches (#430). Tower
## ranges (2.3 cells at level 1) cap it anyway: a block's centre is 2.2 cells from the curve here.
const ROAD_CLEARANCE_CELLS := 0.0
## With a band, a block's centre is within this many cells of its nearest allowed distance from
## the curve, and the road cells counted for coverage reach this much further: the lattice of
## block anchors and the cells up to a cell off the curve cannot meet a tighter rule.
const ROAD_TOUCH_SLACK := 1.0
