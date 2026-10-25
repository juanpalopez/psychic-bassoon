---
type: lesson
date: 2026-10-25
area: sim
links: [#481, #516]
promote: none
promoted-to:
---
# Reaching the second lane costs the first one blocks until the strip gets one more

## What happened
Asking for 2 blocks on the lower lane's own stretch and a block at each bridge, inside the same 4 to 5 blocks per strip, moved the main road's time under fire from 32.6 s to 30.6 s (median, seeds 1..300) while the lower lane went from 28.1 s to 30.2 s: the blocks are the same, the lanes only trade them. Putting blocks between the lanes first changed nothing (identical medians). One more block in the Crossing (5 to 6) gave 32.0 s and 31.0 s.

## Evidence
- `godot/tools/measure_road_time.gd` lane 0 / lane 1 medians: before 32.6 / 28.1; checks at 4 to 5 blocks 30.6 / 30.2; Crossing 5 to 6 blocks 32.0 / 31.0; Meadow and Crossing both +1 gave 32.1 / 31.9 but 25 to 31 blocks.
- Own-stretch blocks before the checks: lower lane 0 for 19 of 300 seeds, bridges reached by a block: lower 27 of 300, upper 216 of 300.

## What we learnt
A reach rule per lane is a share of a fixed budget; measure both lanes before and after, and treat the block count as the lever.

## Rule next time
When a rule makes blocks serve a new road, report each road's time under fire and the block range together.
