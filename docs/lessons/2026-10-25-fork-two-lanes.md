---
type: decision
date: 2026-10-25
status: accepted
decided-by: owner
links: [#481, #493, #495, #500, #510, #515, #518, #521]
---
# The layout valley forks into two lanes that foes and the hero both cross

## Context
`2026-10-24-fork-wide-road-bigger-map.md` asked for two crossings. The first shape, a jog inside the Crossing (B north of A), could not fit: the west bank is 2 to 7 cells and the jog needs 7 to 8 (stop report on #495). A far fork across regions is left to a layout-library entry.

## Decision
- **D1:** shape (c), two lanes. Both leave the Sunken Meadow's entry gate; B runs below A, crosses on its own bridge and meets A at the Crossing's exit. Owner chose it in the session after the #495 stop; it replaced "B north of A". Fit 300/300, mean 1.27 draws (#510). The unused `JOG` template (#494) stays in the library.
- **D2:** layout numbers (cuts, river, gates) move only as measured; none moved.
- **D3:** each foe picks a lane 50/50, one `route_rng` draw per foe, only on a map with a fork (#493).
- **D4:** the bridges are 4 to 5 rows apart (`FORK_ROW_GAP`; at least `HERO_BRIDGE_MIN_ROW_GAP` 4, checked in #521).
- **D5:** the gate is no regression per lane, not the 0.90 to 1.10 band. Median time under fire over seeds 1..300 (strip valley 63.9 s): main road 32.0 s (ratio 0.50), lower lane 31.0 s (0.49); #515 had 32.6 s and 28.1 s. The band is #460's job.
- **D6:** no sockets on the island between the lanes; the hero-only bridge is gone (#521).

## Consequences
- `FORK_LANES := true`; the strip valley and the default board are unchanged until #458. `HERO_CAPS` are 37, 25 and 39. Guards post on the branch of their bridge (#500).
- Sockets are 24 to 30 (31 on two seeds of 3001..3300); CLAUDE.md still says 21 to 30, an open owner question.
- Render draws both crossings (`test_diorama_fork.gd`). The fork pushed seeds 17 and 22 over the 40k terrain cap; the forked bed is thinned instead (RFC section 11), the cap stays.
