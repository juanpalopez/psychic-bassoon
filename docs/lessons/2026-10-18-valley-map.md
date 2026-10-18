---
type: decision
date: 2026-10-18
status: accepted
decided-by: owner
links: [#316, #320, #321, #323, #275, #328, #335]
---
# Play on a 32x20 valley with curved routes, guarded bridges and a movable hero

## Context
With the diorama look the owner wants the playable map to feel larger, with roads that curve and patches of forest, rocks and dirt, and accepts that "rules can be adjusted". The 16x11 board (owner, 2026-10-14, #255) fits on one phone screen; a 24x16 mock was shown.

## Decision
- The board is 32x20 cells (#320); the camera pans across it and the whole map is an overview zoom, not the play view (#328).
- The sim walks the curve: a route-geometry layer rounds the grid path's corners and is the truth for movement, range and hits (#321). The ported grid path and the frozen fixtures stay as they are; the replay goldens are re-recorded as reviewed changes in #320 (the bigger map) and #321 (the curve).
- Bridges over the river are held by guards posted on them (#323); this replaces the drawbridge idea dropped on 2026-10-12.
- Heroes move anywhere walkable on the map, a little like an RTS (#275, #335).

## Alternatives considered
- 24x16 (the mock) or 20x14: the owner picked the bigger valley. Render-only curves: foes look off the road at bends.
- A drawbridge, a gate or a destructible bridge.

## Consequences
- The phone budgets (draw calls, triangles, tower count) are re-set for the bigger map and re-measured on the iPhone (#97).
- Wave pacing changes with longer roads (balance pass #237 after #320, #321); off-screen foes and the hero need indicators and a minimap (#329).
