---
type: decision
date: 2026-10-25
status: accepted
decided-by: owner
links: [#446, #530, #404]
---
# Switch the layout valley's road band on at 2.0 cells, not 2.4, for the generation cost

## Context
#446 aimed at a 2.4 cell band. The probe (seeds 1..300 and 3001..3300) found the same quality at
2.0 and 2.4: no stitch failure, 24 to 30 sockets, lane B at least 4 blocks, terrain under its cap.
The cost differs: 2.0 draws the layout 3.5 to 3.8 times (570 to 700 ms a valley); 2.4 draws 4.6
to 5.0 times (2.2 to 2.5 s, one seed 25 s under load).

## Decision
`ROAD.ROAD_WIDTH_CELLS` is 2.0. The stitcher sets `reach_band` to the band's width on the maps
that use the band (the layout valley); the strip valley, route-first maps and old boards keep
`road_width` 0.9 and `reach_band` 0.0 (seeds 1..120 hashed against main: identical).

## Alternatives considered
- 2.4: 4 times the draws and 20 times the time under load, no gain measured.
- 1.5: cheaper (3.2 draws, about 420 ms), but not the wide band the owner asked for.

## Consequences
- The 0.90 to 1.10 time-under-fire gate is still #460's job (0.46 to 0.49 on the probe at 2.0).
- `LAYOUT.MAX_ATTEMPTS` stays 60: the worst draw count was 20, a third of the limit.
- No golden moves: the layout valley is not the game board until #458.
