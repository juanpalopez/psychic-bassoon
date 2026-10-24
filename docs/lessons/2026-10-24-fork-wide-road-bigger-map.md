---
type: decision
date: 2026-10-24
status: accepted
decided-by: owner, on seeing the layout valley in the app
links: [#404, #441, #446, #458, #460, #461, #469]
---
# Fork the road over the river, widen it and grow the layout valley to 40 by 24

## Context
On 2026-10-23 the owner ran the layout valley (`feat/board-layout-valley`). The maps look better, but most seeds look alike (only the sockets move), and the hero-only crossing reads as a second crossing nobody can use. The road was 71 cells, at 0.53 of the strip valley's time under fire.

## Decision
- **Two crossings, both open to foes and the hero.** The road forks before the river and joins again after it, so each crossing is a strategic point. This supersedes "one road crossing plus the hero-only crossing" (2026-10-23).
- **A wider road**, so the valley does not read as a strip, and foes and the hero move a little more freely: the road band of #441 is turned on, with the bed drawn to match.
- **The layout valley grows to about 40 by 24** to give the fork, the wider road and the hook and u_turn pieces room. The strip valley stays 32 by 20 until #458 switches the board.
- The road's target is still time under fire (RFC section 7). Road length is fine if it meets that target.

## Alternatives considered
- One road crossing plus a hero-only footbridge, drawn: rejected; the owner wants two fronts.
- Growing only to about 36 by 22, or only if 3A fails: rejected for 40 by 24, which also leaves room for the layout library.

## Consequences
- Foes pick a route at the fork (the sim already lets foes pick a route); towers and guards must be able to cover both crossings, and the time-under-fire gate is measured per route.
- The hero graph and the Crossing region's checks change from one road bridge and one hero bridge to two road bridges.
- A wider band needs the #469 rule (road cells under the curve) and #446 (range to the band's edge) settled first.
- The camera's zoom and pan limits, the scenery and terrain caps and the iPhone budget (#97) are measured again for 40 by 24; CLAUDE.md's map line and RFC `2026-10-23-longer-valley-road.md` section 9 record it.
