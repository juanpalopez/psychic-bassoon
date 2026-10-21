---
type: decision
date: 2026-10-21
status: accepted
decided-by: owner on Claude's proposal
links: [#381, #321, #404]
---
# Lay the six sections out as 2D regions and walk a smooth spline road through them

## Context
The sectioned valley (2026-10-20, #381) cuts the board into six full-height column strips 4 to 7 columns wide. Every section has to put its road across a narrow strip with room for socket blocks, so the roads came out as tight snakes: lanes 2 to 3 cells apart joined by 90 degree steps, rounded only by a corner curve of at most one cell (`CURVE_LEG`). The owner's reference ("Valley Defence Map", 2026-10-21) has regions that are areas, not strips, long smooth S-bends with a bend radius of 3 to 5 cells, a river that winds from top to bottom, a bridge crossing, the feeder entering from the top right corner, and sockets spread around the road.

## Decision
- **Regions, not strips.** `ValleyPlan` places the six sections as rectangles of a 2D layout (A top left, B top middle, C the river crossing in the middle, D bottom left, E top right, F bottom right, as in the reference; the road still visits them in the lore order A to F). The seed moves the borders and the gate points. A section owns its rectangle, not a full-height column.
- **The road is a spline.** Each section gives waypoints; the road is a Catmull-Rom spline through them (only `+ - * /`). The route foes walk (`Route`, the truth for movement, range and hits) is built from the spline's points; the road cells (tiles, sockets, walkable, checks) are the spline rasterised to unit steps, so `ValleyChecks` and the stitcher keep their rules.
- **Lane gap.** `ValleyChecks` rejects a section whose road has two stretches closer than a minimum gap (content), so a snake of lanes is a failed section, not a style.
- **The river is a spline too**, crossing the road on the bridge and keeping its own course.
- The frozen fixtures, the ported route-first generator and the old boards do not change; only the sectioned valley's routes do (goldens re-recorded under this record, deep tier).

## Alternatives considered
- Only a larger corner radius in `Route.build_curved`: the road would still be lanes 2 to 3 cells apart; it softens the corners, not the layout.
- Keep strips and widen them: the board is 32 columns, six strips cannot be much wider, and a strip layout cannot give the reference's 2D regions.
- Hand-drawn road templates: no seed variety.

## Consequences
- `ValleyPlan` and the six sections are reworked (the checks, stitcher, hero graph and `SectionResult` stay). This supersedes the strip layout of `2026-10-20-sectioned-valley.md`; its other decisions stand.
- Foe paths and the valley goldens change again; road bed, sockets and hero walkable follow the spline's cells.
- Epic #404 and tickets #405 to #412.
