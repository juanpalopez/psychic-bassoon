---
type: lesson
date: 2026-10-18
area: sim
links: [#322]
promote: none
promoted-to:
---
# Place a map feature through a chosen anchor with a search, not by rejection sampling

## What happened
The first river for the valley terrain (#322) was a random walk, thrown away whenever it hit a
socket or crossed the road badly: with 24 to 30 socket blocks lining the road it fitted 29%.

## Evidence
`test_terrain.gd`: `[0.29032258064516] expected to be >= than [0.9]: share of maps with a river`.
A crossing drawn first plus a course search through it: 293 of 300 seeds. With the #340 review's
rules (bridges met head on, no road-turn insides) it fell to 84%; one search treating every
possible bridge as a straight five-cell step (`TerrainGen._relax_span`) gives 276 of 300.

## What we learnt
The failing constraint is local (a clear, straight crossing); search through it, don't sample.

## Rule next time
When a generated feature must pass through scarce spots, search a path through them instead of rejecting whole random draws.
