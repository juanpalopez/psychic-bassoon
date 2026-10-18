---
type: decision
date: 2026-10-18
status: accepted
decided-by: owner
links: [#324, #346, #97]
---
# Budget the frame at 200k triangles, with 40k for the terrain and 32k for the scenery

## Context
The diorama (#324) draws 28k to 31k terrace triangles and about 2k of water and road bed, against
a "terrain and effects 20k" cap set for the flat board. The caps for foes (80k), towers (45k) and
the boss (5k) already took 130k of the old 150k frame (review of #346).

## Decision
A provisional frame budget of 200k triangles until #97 measures on the owner's iPhone in a native
build: terrain and road beds 40k, scenery 32k, foes 80k, towers 45k, boss 5k; draw calls stay under
120. It is in CLAUDE.md (Rendering and performance), `docs/PLAN.md` (Phone performance budget),
and `godot/tests/render/test_diorama.gd` (`TERRAIN_TRIANGLES`, `SCENERY_TRIANGLES`).

## Alternatives considered
- Keep 20k for the terrain: the terraces would need far coarser outlines and cliffs.
- Keep 150k for the frame and cut the units' caps: the units' models are already budgeted.

## Consequences
- #97 measures fps and the real counts on the iPhone and confirms or changes these numbers.
- The terrain is chunked so culling keeps the in-view count well under the caps up close.
