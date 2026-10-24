---
type: decision
date: 2026-10-25
status: accepted
decided-by: owner on Claude's proposal
links: [#446, #498, #441]
---
# Measure a ground foe's distance to the road band's edge through one combat seam, off until the band is switched on

## Context
The owner chose option B for the wide road (2026-10-22, #441): a tower measures its range to the
band's edge, so a band about 2.4 cells wide keeps every socket block in useful reach. Sim foes
walk the centre line (the spread across the band is render only), so in the sim this is: a ground
foe on the centre line is in reach up to half the band further. `GameMap.road_width` is 0.9 on
every older board, so deriving the margin from it would move every golden.

## Decision
`GameMap.reach_band` is its own field (0.0, set by the stitcher only when the band is switched
on, a later PR of #446). `TowerFire.ground_reach_of`, `reach_to` and `foes_within_reach` add
`reach_band / 2` to the reach of a ground foe, after the elevation bonus, and compare squared
distances as before (no sqrt, so 0.0 changes no bit). A flying foe has no road and keeps the plain
reach. The tower target and beam lock, frostbite, skewer (and its bolt's end), flash freeze,
precision snipe, the Mess Tent aura and Fortified Feast, and the squadron patrol use it. Splash
and blast radii, pulls and soaks stay areas around a point and do not use it.

## Alternatives considered
- Derive the margin from `road_width / 2`: adds 0.45 to every tower on every old board and
  shifts every replay and spec golden.
- Scale the band by the elevation bonus: makes a high tower reach the far edge 15 percent further
  than a flat one reaches it, which the owner's rule does not say.

## Consequences
- With the band off, replay, spec and socket goldens and the frozen fixtures are byte-equal.
- Still open for the later PRs of #446: the hero's reach, the scripted bot, range display,
  socket placement and the switch-on with its golden re-record (#458).
