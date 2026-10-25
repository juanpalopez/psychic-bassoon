---
type: lesson
date: 2026-10-25
area: sim
links: [#517, #490, #515]
promote: none
promoted-to:
---
# A rule checked per section misses the segment only the stitch makes

## What happened
14 of 100 layout valleys had a socket cell on a `Tile.ROAD` cell near the top right (seed 1: block (35, 5)). Not Heartkeep's placer, and not the marking order: the block was the Ancient Fold's, `off_band` held against its own feeder curve (gap 0.50, band half width 0.45), but the stitcher joins the feeder to the main road with a segment no section owns, and that segment passes 0.35 from the block, so `_mark_band` made the cells road.

## Evidence
- Seed 1: `feeder_curve.rect_gap(35, 5, 2)` 0.50; the stitched `route_curves[1]` 0.35. A first fix that tested every section's own curves in `ValleyChecks` still failed on seeds 1, 5, 9, 10, 20, 21, 22, 29, ...
- After checking the stitched map's `Tile.ROAD` cells in `ValleyStitcher.build`: 0 of 300 and 0 of 50 seeds, 0 stitch failures, same socket range (24 to 30 median 27, 31 max).

## What we learnt
A property of the stitched map (cells marked as road) is checked on the stitched map; a per-section proxy for it can pass while the join breaks it.

## Rule next time
Test an invariant of the final map on the final map, over 300 seeds, before deciding which layer owns the cause.
