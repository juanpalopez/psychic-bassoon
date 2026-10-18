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
The first river for the valley terrain (#322) was a random walk down the board, thrown away
whenever it touched a socket or crossed the road anywhere but straight. On the 32x20 board,
with 24 to 30 socket blocks lining the road, it fitted only 29% of maps after 80 tries.

## Evidence
`test_terrain.gd`: `[0.29032258064516] expected to be >= than [0.9]: share of maps with a river`.
With the crossing chosen first and the cheapest down-flowing course searched through it
(`TerrainGen._flow`), 293 of 300 seeds get a river, in under 2 ms per map.

## What we learnt
The constraint that fails is local (a straight, socket-free crossing), so picking it first
and searching the rest leaves far more maps a river than drawing everything at once.

## Rule next time
When a generated feature must pass through a scarce spot, enumerate the spots, draw one from
the stream and search a path through it, instead of rejecting whole random draws.
