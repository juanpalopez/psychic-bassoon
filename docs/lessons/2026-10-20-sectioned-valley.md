---
type: decision
date: 2026-10-20
status: accepted
decided-by: owner on Claude's proposal
links: [#320, #321, #322, #323, #335, #381]
---
# Generate the valley from six fixed sections, each with its own recipe and random stream

## Context
The 32x20 valley (2026-10-18) is built route-first: `map_gen` walks a random path, `socket_placer` fills sockets, `terrain_gen` carves heights and a river around the road. The result is valid but has no designed places. The owner's reference image (Kingdom of the Fold, valley defence) shows six named regions, each with a job: a chokepoint bridge, high ground, an open meadow, a feeder merge, a final approach.

## Decision
- A new entry `MapGen.generate_valley` builds the map from six sections in a fixed order, the same for every seed: A Outer March, B Broken Ridge, C Bluewater Crossing, D Sunken Meadow, E Ancient Fold, F Heartkeep Approach. The main road crosses all six. The seed varies the shape inside each section, never the order.
- Three layers in `godot/sim/map/valley/`: `ValleyPlan` (rects, gates, river corridor from the seed), one `Section` generator per region (returns a `SectionResult`: road cells, heights, tagged sockets, walkable mask, props), and a `Stitcher` that merges the results and runs the validators.
- Each section draws from its own derived stream, `deriveRng(seed, "valley/<section>/<attempt>")`. A failed validator rerolls one section, never the whole map.
- Recipes and numbers (rect fractions, socket count ranges, required tags, minimum walkable area) live in `godot/content/valley_sections.gd`; the generators hold no magic numbers.
- Validators are plain functions, tested in GUT: route continuous gate to gate; every bend and merge covered by a socket; high-ground sockets at most 20% of all sockets, each with a low-ground alternative nearby; the hero walkable graph (meadow area, at least two river crossings, travel time caps); the feeder joins before F with no detour.
- C holds two crossings: the road bridge (the enemy chokepoint, guarded, #323) and a walkable bridge for the hero only. D is one large open walkable area. E carries the later-wave feeder merge.
- `map_gen`, `terrain_gen` and `socket_placer` stay as helpers the sections call. The ported core and its frozen fixtures do not change; the valley path gets new GDScript goldens as a reviewed sim change (deep tier).

## Alternatives considered
- Keep route-first generation and tune it: it cannot guarantee a meadow, a second crossing or a merge place, only hope for them.
- Shuffle the section order per seed: loses the readable valley and the lore order (the road ends at the Heartkeep); needs far more validation.
- Hand-draw one fixed map: no replay variety, and the sim already has seeded generation.

## Consequences
- Every region has tested rules, so balance and art can target named places. Rerolls stay local, so a fix in C never moves A.
- More generator code and a new set of goldens; the valley seeds in the CI game and the win test change by a reviewed decision (this record).
- Hero control (#335) and the minimap (#329) can rely on the walkable graph.
- Follow-up: the epic and its tickets (#381 to #389). CLAUDE.md's map paragraph changes in the last PR of the stack, not before.
