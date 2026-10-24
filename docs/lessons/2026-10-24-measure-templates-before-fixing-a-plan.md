---
type: lesson
date: 2026-10-24
area: sim
links: [#481, #495]
promote: none
promoted-to:
---
# Fit the real templates to the real gates before fixing a plan, and let the fit decide the shape

## What happened
The first design memo for the fork (#481) put a sideways jog inside the Crossing, on a room analysis done with a prototype template. The first attempt at #495 built it with the real `SegmentFitter` and no layout numbers made it fit seeds 1..300 (the west bank is 2 to 7 cells, a jog needs 7 to 8). The second memo moved the fork to two lanes through the Meadow and the Crossing, which fit 300 of 300 seeds with no cut or river moved.

## Evidence
- `#495` stop report: "the fork does not fit seeds 1..300 inside the Crossing on any layout numbers measured".
- This PR: `scratchpad` probe over seeds 1..300, 300/300 layouts, mean 1.27 draws, worst 4 (a layout with no fork: 1.12, worst 3).
- The lanes' first gap rule (`LANE_APART` 4, `LANE_JOIN` 6) rejected 4054 compose attempts on seeds 1..20: two diagonal arcs `g` rows apart are only about `g / sqrt(2)` cells apart.

## What we learnt
A plan that rests on "there is room" has to be checked with the real templates, the real gates and the real checks, in a probe over many seeds, before tickets are cut. Gap and join numbers that look right on paper (a gap of `g`) were wrong by a factor of 1.4 on diagonals.

## Rule next time
Before splitting a layout idea into PRs, write the probe that draws it over seeds 1..300 with the real fitter and checks, and let its fit rate pick the shape and the numbers.
