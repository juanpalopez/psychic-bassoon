---
type: rfc
date: 2026-10-23
status: proposed
links: [#404, #458, #460, #469]
---
# RFC: a 100 to 150 cell road on the layout valley

## Status and decision sought

**Status:** Proposed. On 2026-10-23 the owner accepted the layout library (section 5) in two steps: 3A on today's layout, then more layouts. Still open: cells or time in range, and `GATE_INSET`; the step 1 measurement informs both.

The owner wants the layout valley's composed road to run 100 to 150 cells (2026-10-23), with one road crossing of the river plus the hero-only crossing. Today it runs 65 to 76 (median 71, seeds 1..300). Two measured attempts showed that tuning can't close the gap (section 2). This memo explains why, proposes two road shapes that can, and asks the owner to pick one.

## 1. What we keep

- The six regions in road order: Outer March, Sunken Meadow, Bluewater Crossing, Broken Ridge, Ancient Fold, Heartkeep Approach. Each is a 2D area (`docs/lessons/2026-10-21-spline-valley.md`), not a strip 4 to 7 columns wide with a snake of lanes 2 to 3 cells apart.
- Broad bends: the owner's reference has bend radii of 3 to 5 cells. The lane rule stays at 5 (`LAYOUT.LANE_GAP`): two stretches 12 or more cells apart along the road stay at least 5 apart.
- The segment library, fitter and composer (`docs/lessons/2026-10-22-road-segment-library.md`); the river from top to bottom; one road crossing and the hero-only crossing; the feeder from the top edge; the 32 by 20 board.

## 2. Why the road is short (measured 2026-10-23, #460)

- Every template only moves forward, so a region's road is as long as the gates are apart (rows plus columns), plus one cell. The region medians are March 11, Meadow 11, Crossing 16, Ridge 11, Fold 9 and Heartkeep 13.
- The overall path is fixed: down the left, across, up the middle, across, down the right. Every gate sits about 4 cells sideways from the last, so a road from gate to gate can't turn back on itself.
- **Option 2 tried and failed:** a lane gap of 4 plus switchback templates. A U-turn needs a box of about 7 by 7, and the gate boxes are 3 to 8 by 4 to 7. Over seeds 1..300 a switchback fitted 3 times, the median stayed 71, the longest road was 86, and no seed reached 100.
- Area bound: with lanes 5 apart, a 9 by 9 region holds about 20 cells of road. Six such regions give about 120, but only if each region's gates sit where a U-turn fits.
- **Conclusion:** redrawing more often can't help. The overall shape and the gate positions must change.

## 3. Two shapes that reach 100 to 150

### 3A. The same six areas, with a U-turn in each (re-gated)

The regions stay roughly where they are, in a 3 by 2 grid: March top left, Meadow bottom left, Crossing bottom middle, Ridge top middle, Fold top right, Heartkeep bottom right. The change is that each region's gates are moved to the ends of one border, so its road makes one broad U (radius 3) inside it instead of a quarter bend:

```
>#######.  .#######.  .######.
.......#.  .#.....#.  .#....#.
.######.   .#.....#.  .#....#.
.#......   .#.....#.  .#....##HH
 (March: in west, out bottom-left)   (one U per region)
```

- **Templates:** a "hook" (a U, then a quarter turn) and a "U" (in and out on the same border). Both are tested alone like the others, and the composer is unchanged.
- **Expected length:** 18 to 24 cells per region, about 110 to 130 in total. The Crossing keeps its straight bridge and makes its U on the far bank.
- **Risks:**
  - The gates move to the corners, against `GATE_INSET` 3; it would drop to 1 or 2.
  - The Fold also holds the feeder, so its U must leave the top-right corner free.
  - Region sizes vary with the seed, so the weakest seeds may land at 95 to 100. The first PR must measure this before anything else is built.
- **Keeps** the reference's look: 2D areas with broad S-bends. Of the two shapes, it changes the least.

### 3B. Five long runs across the board (a serpentine)

The road becomes five runs from top to bottom, joined by U-turns of radius 3 at the top and bottom edges. The runs sit about 6 columns apart (x around 3, 9, 15, 21 and 27, moved by the seed), and the river runs between the second and third runs, so only one join crosses it.

```
>##.  .###.  .###.  .###.  .
. #.  .# #.  .# #.  .# #.  .
. #.  .# #.  .# #.  .# #.  .
. ####.# ####.# ####.# ###HH
       ~~ (river crossed once, at a top join)
```

- **Expected length:** five runs of about 15, plus four U-turns of about 9, plus the leads: about 115 to 135 on every seed.
- **Regions** become taller areas that each own about one run and its U-turn. They are wider than the old strips (6 columns, with the lanes 6 apart and no snakes), but they read as columns, not as the reference's 3 by 2 areas.
- **Cost:** `ValleyLayout._draw`, the region rectangles and gates, and the region roles are rewritten. Each region's sockets, ground and ruins are checked again.
- **Most certain** to reach 100 to 150. Furthest from the reference's look.

## 4. Decision sought, and the alternatives

| | Reaches 100 to 150 | Look | Cost |
|---|---|---|---|
| **3A: re-gated U per region** | likely; measure first | keeps the 3 by 2 areas | medium |
| **3B: five-run serpentine** | yes, about 115 to 135 | taller, column-like areas | large |
| Keep 70 cells, slow foes about 0.6 times | same time in range | keeps today's map | small: a balance change plus a sweep |
| A bigger board (for example 40 by 24) | yes, with 3A | keeps the areas | large: camera, budgets, all tests |

**Recommendation: 3A, measured first.** The first PR adds the hook and U templates and the re-gating, and reports the length over seeds 1..300. If it reaches 100 on fewer than 95 % of seeds, stop and switch to 3B. The slower-foes row matters in its own right: what the game needs is time in tower range. If the owner cares about time in range rather than cells, that row is the cheapest.

## 5. A layout library: more starts and Heartstones (owner, 2026-10-23)

Today the spawn is always on the west edge (rows 1 to 3) and the Heartstone always on the east edge (rows 15 to 17). That fixes the road's overall shape, which is why seeds 1, 42 and 2026 look nearly the same (4 template sequences over 300 seeds). The research recommends placing the important pieces first and building the road around them (`docs/research/procedural-map-generation.md`, section 4.2).

- **A layout** is data in `godot/content/valley/`: the spawn edge and its rows, the Heartstone's place, the six region rectangles (or the cuts that make them, with their jitter), the gate borders between them, the river's source and mouth, and the feeder's edge. The seed picks a layout, then mirrors it (and rotates it where the board allows), then varies the details as today.
- **Candidates:**
  - today's west-to-east layout;
  - a spawn on the top edge with the Heartstone near the centre;
  - corner to opposite corner;
  - the Heartstone inside a bend of the river (the river runs across the board, as the owner decided, so every layout keeps one road crossing).
- **Each layout must pass the same checks:** a road of 100 to 150 cells, the lane rule, one road crossing plus the hero crossing, sockets in range (21 to 30), the hero graph caps, generation time, and stitch success over seeds 1..300.
- **Variety:** a handful of layouts, each mirrored, gives 8 to 12 overall shapes before the seed varies the details. The variety report counts distinct shapes, and layouts stop being added when the count stops growing.
- **Costs:** region positions become data, not code. The camera's opening view has to frame wherever the spawn is (CLAUDE.md, Camera: "a run starts near the spawn"). The prototype seed of the hero RFC (#453) has to name its layout.

**Two steps:**
1. Today's layout with 3A (section 6), until the road is 100 to 150 cells.
2. Two or three more layouts, one PR each, measured the same way.

## 6. PR plan for 3A (each under 300 production lines, Sonnet implementing)

1. The hook and U templates in `segments.gd`, with their tests (alone, every symmetry and scale, lanes at least 5 apart).
2. Re-gating in `ValleyLayout._draw` and `layout_rules.gd` (gate positions, `GATE_INSET`), the `ALLOWED` options, and `ROUTES.LENGTH` raised to (100, 150). Measured over seeds 1..300: length, variety, generation time (0.15 s mean budget) and stitch success. This PR has the stop condition above.
3. The region sections checked again on the new roads (sockets, ruins, the feeder and the ridge plateau), and the decision record.
4. Then the board switch (#458), with #469 (road cells) and #461's stack in.

## 7. Open questions

1. ~~3A, 3B, or slower foes?~~ The layout library, starting with 3A on today's layout (owner, 2026-10-23); 3B is the fallback if 3A misses its measurement.
2. If 3A: may `GATE_INSET` drop to 1 or 2, so gates can sit near a region's corners?
3. Are cells the target, or is time in tower range (the slower-foes row)?
