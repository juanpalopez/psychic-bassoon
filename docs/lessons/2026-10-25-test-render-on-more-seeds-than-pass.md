---
type: lesson
date: 2026-10-25
area: render
links: [#461, #523]
promote: none
promoted-to:
---
# Run a render test over 30 seeds before trusting the handful it lists

## What happened
The layout valley's diorama tests listed five to nine seeds and all passed on main. Widening the bed, bridge, terrace and scatter tests to seeds 1 to 30 (plus 124 and 152) found two things the short lists hid: the two cell road bed hung up to 0.48 cell over the water on about half the seeds, and a bridge plank test passed only when a plank fell at a cell's middle.

## Evidence
`no bed over the river, seed 10` failed with 15 vertices over a river cell (a bend of the river beside the road); `seed 16 bridge (17, 15)`: `[-0.012] expected to equal [0.01]`. Seeds 1, 2, 3, 5 and 11 passed both before and after the fix.

## What we learnt
A short list of seeds that were picked once, for a narrower road, is a sample of the maps the generator makes, not a proof. Geometry that depends on a neighbour (a river cell beside a wide bed, a plank under a cell's middle) shows up on a fraction of seeds.

## Rule next time
When a render builder changes width or layout, run its tests once over seeds 1 to 30 with a scratch copy of the test (not committed) and add the failing seeds to the committed list.
