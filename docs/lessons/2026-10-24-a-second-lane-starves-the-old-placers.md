---
type: lesson
date: 2026-10-24
area: sim
links: [#481, #512]
promote: none
promoted-to:
---
# A second lane starves every rule that assumed one road

## What happened
Turning the fork on stitched route B at once, but layout generation went from 68 ms to 788 ms (slowest 5.3 s). Two rules written for one road starved: the Crossing demanded a hero-only bridge on a row 4 or more rows from the road's bridge (now from two bridges, almost no row is left: 306 failures in 40 seeds), and the Meadow's socket sites had to reach the main road only (3 blocks, want 4 to 5: 84 failures). Letting a block reach either lane fixed the time (98 ms) but moved the blocks off the main road (its time under fire fell from 33.2 s to 28.3 s); taking the main road's sites first kept it at 32.6 s.

## Evidence
- `scratchpad/why_slow.gd` tally over seeds 1..40: "the river has no hero bridge" 306, "3 socket blocks, want 4 to 5" 84.
- `tools/measure_road_time.gd` (per lane), seeds 1..300: lane 0 median 33.2 s before, 28.3 s with sites open to both lanes, 32.6 s with the main road's sites first; lane 1 28.1 s.

## What we learnt
A check that was true of "the road" has to be read again for each lane when a second one appears, and the first run of the stitched map shows which ones with a tally of the problems that made sections draw again, not just the pass rate.

## Rule next time
When a PR adds a road, tally the section problems over 40 seeds and measure time under fire per lane before and after, in the same PR.
