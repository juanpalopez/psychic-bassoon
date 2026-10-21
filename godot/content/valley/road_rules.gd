## Numbers for the spline roads of the valley (#404, `docs/lessons/2026-10-21-spline-valley.md`).
extends RefCounted

## A road spline is sampled this many times per cell of chord between two waypoints, plus one,
## so consecutive samples are never more than half a cell apart and the rasterised cells have no
## gaps.
const SAMPLES_PER_CELL := 4
## A road cell's centre is never further than this many cells from the spline point it stands
## for (the rasterised cells stay on the curve).
const MAX_CELL_DEVIATION := 1.0
