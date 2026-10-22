# Procedural map generation: what other games do, and what we should build next

Status: research memo, 2026-10-22, for epic #404 (Refs #404). No code changed.
Scope: pick the next generator for the Kingdom of the Fold valley (32 by 20 cells, one west-to-east enemy road, six fixed-order regions, a river with a bridge, 24 to 30 sockets, a hero that needs connected ground, deterministic from a seed, about 0.15 s per map on a phone).

How to read the evidence. Every claim carries a URL. "Not verified" marks what I could not confirm: several PDFs (Smith and Whitehead, the PCG book, an Aalto thesis, Galin et al.) were unreadable in this environment, so for those I rely on search-result summaries and say so. The GDC Vault talks are login-gated. Guesses are marked "guess".

The decision records this memo reacts to (`2026-10-20-sectioned-valley`, `2026-10-21-spline-valley`, `2026-10-22-road-segment-library`) live in `docs/lessons/` on the in-flight branches of epic #404.

## 1. Executive summary

1. The owner's segment-library plan is the right backbone. Nearly every shipped game that must look designed uses hand-authored chunks with ports and lets the seed pick, rotate and order them (Diablo 2 and 3 tiles, Spelunky rooms, Dead Cells rooms, Bad North tiles).
2. The part practitioners protect most is not the template, it is the guarantee layer around it: a path or graph built first (Spelunky's solution path, Dead Cells' concept graph), then validated by flood fill, then rejected and redrawn if bad (Diablo 1). We already have the checks; keep them and make them cheap.
3. Make the road a graph of ports first (region order is fixed, so this is a short chain), and only then let terrain, river and sockets react to it. Today the order is partly the reverse and sections draw their own road.
4. Add a small number of large set pieces (bridge, ridge wrap, Heartkeep approach, Fold ruins) as fixed-shape templates, Diablo 1 "set pieces" and Spelunky-style special rooms. Variety comes from composition plus mirror, not from many templates.
5. Use a generate-and-score loop for sockets (a greedy scored placement with a few seeded restarts), not a rule per section. It is search-based PCG at the smallest useful size.
6. Treat WFC as optional and only for the decorative terrain layer with the road pinned, because WFC is a local solver that needs a path constraint to keep roads connected and gets samey on big maps.
7. Judge every change with an expressive-range report (histograms of road metrics over 3,000 seeds), not by looking at three PNGs.
8. Expect 8 to 14 library templates for this one map shape, not dozens; see section 5 for the evidence and the uncertainty.

## 2. Evidence by approach

### 2.1 Diablo family

Diablo 1 builds each level in two passes, a rough "predungeon" floor plan and then tile assignment. Randomness covers room sizes, positions, wall styles and decoration. Prefab content comes in three kinds: set pieces (pre-authored chunks pasted verbatim, mostly quests, one per level), minisets (about 3 by 3 patches placed by pattern match, used for stairs and for repairing bad joins) and theme rooms. Validity is by generate-and-test: a "lockout" check that the dungeon is walkable restarts generation on failure, and each level type retries below a floor-tile threshold (the Catacombs restart under 700 floor tiles, Caves under 600; Caves rivers retry until length and bridge rules are met). The author notes the fix-up code was buggy and needed late patches ([Boris the Brave, Dungeon generation in Diablo 1](https://boristhebrave.com/2019/07/14/dungeon-generation-in-diablo-1)).
Lessons for us: retry-until-valid is normal and shipped, but it hid bugs; small "repair" pieces (minisets) fix local seams cheaply; river-with-bridge attempts are retried as a unit.

Diablo 2 uses DS1 (preset or random-room layouts) and DT1 (tile graphics) files, with `lvlprest.txt` listing the DS1 files and whether a level is a fixed preset (Levelid linked to Levels.txt) or generated ([d2mods lvlprest article](https://www.d2mods.info/forum/kb/viewarticle?a=367)). The exact selection algorithm is not documented in what I could read; a reimplementation project says the generator turns a seed into rooms, collision grid, roads and population ([libd2](https://github.com/jaenster/libd2), claim from search summary only). Not verified: how Lut Gholein or Kurast mix preset and random pieces.

Diablo 3 and 4: Blizzard describes tile sets combined with props and lighting, plus "tile-set transition scenes" that connect two tile sets in one dungeon ([search summary of Blizzard Q&A](https://www.nme.com/news/diablo-4-will-include-five-distinct-regions-and-hundreds-of-dungeons-3193980); not read in full). A developer's write-up of a Diablo 3 BlizzCon 2016 talk (Ed Hines) says the generation is tile-based and that large pre-designed tiles with offset entrances hide the grid ([devlog](https://axandros.itch.io/diablo-like-level-generator/devlog/152703/a-rough-initial-attempt-at-level-generation); secondhand). Not verified: tile sizes, the placement algorithm.
Lesson: large tiles with offset entrances are the standard way to hide seams. Our ports should not all sit on region edge midpoints.

### 2.2 Template and chunk games

Spelunky: a 4 by 4 grid of 16 rooms. A random walk (roll 1 to 5: left, left, right, right, down) builds the solution path first, with room types defined by their guaranteed exits (type 1 left/right, type 2 left/right/bottom, type 3 left/right/top); off-path rooms get no connectivity guarantee ([tinysubversions, Spelunky generator](https://tinysubversions.com/spelunkyGen/)). Authored: room templates and special rooms. Random: path and template choice. Guarantee: by construction along the path.
Lesson: the guarantee is cheap because the path rules are tiny and the templates carry the exit contract. Our ports play the role of exit types.

Dead Cells: a hand-designed world graph; each biome has a concept graph of nodes (entrance, exit, special rooms, then combat and exploration), constraints on length, labyrinthine-ness and entrance-to-exit distance; for each node the generator picks a random matching hand-built room from the biome pool, retrying until constraints fit ([Benard, Dead Cells level design](https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-)). The article gives no room count and does not discuss seams (checked).

Unexplored (Dormans): a 5 by 5 node grid, one of 24 major cycle types, about 50 grammar modules and about 5,000 rewrite rules, then a doubled and 5x expanded tile map shaped with cellular automata ([Boris the Brave, Unexplored](https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/)). Mission-then-space is the same idea in the academic form ([Dormans and Bakkes 2011](https://research-portal.uu.nl/en/publications/generating-missions-and-spaces-for-adaptable-play-experiences/); abstract only). Lesson: a grammar scales variety but costs thousands of rules and a dedicated tool; too heavy for one map shape. Keep the idea "graph first, space second".

Dungeon Crawl Stone Soup: vaults are hand-written map fragments in `.des` files; for most vaults, rooms and corridors are built around the vault, while branch entrances and minivaults are placed after the rest ([mirror of the level-maker guide, old revision](https://nest.pijul.org/fiddlerwoaroof/crawl/changes/R6XS2HO5QX2FJUGL5UQQRNETKCMYWTUFPHPPS5SYWK3OQA4UDUQQC)). Current guide sections on map generation and validation were not retrieved. Lesson: place the important authored piece first and build around it; that is the bridge in our valley.

Hades, Into the Breach: not researched (no sources fetched); no claims made.

Caves of Qud: the towns are a static authored backbone inside a procedural world ([Game Developer interview](https://www.gamedeveloper.com/design/tapping-into-the-potential-of-procedural-generation-in-caves-of-qud)). Its WFC ruin generation is documented in GDC talks I could not read ([GDC Vault](https://gdcvault.com/play/1025913/Math-for-Game-Developers-Tile)).

### 2.3 Constraint and grammar approaches

WFC: each cell holds a set of possible tiles, adjacency rules narrow it. Bad North uses over 300 hand-built tiles, restarts from a saved state when constraints fail, and has a navigability check so houses only appear where enemies can reach; it fails often on tall thin islands. Townscaper tolerates failures silently ([Game Developer, How Townscaper works](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)). Tips from Boris the Brave: WFC is local, so large maps look repetitive and disconnected; a path constraint (a global constraint forcing annotated tiles into one component) fixes connectivity but adds T-junctions on roads and rivers unless weighted down; fixed tiles pin endpoints; region-wise tilesets avoid samey maps ([WFC tips and tricks](https://www.boristhebrave.com/2020/02/08/wave-function-collapse-tips-and-tricks/)).
Cost for us: a propagation solver in GDScript with deterministic ordering is doable (guess: 250 to 400 lines) but contradiction handling and the path constraint are the hard parts; it needs a tile set with hundreds of tiles for the Bad North look, which we do not have the art budget for.

Polygon maps (Red Blob): Delaunay triangulation (Delaunator), smooth elevation, biomes from distance to coast and water ([mapgen2](https://www.redblobgames.com/maps/mapgen2/); I could not confirm rivers or runtime from the page). It suits irregular region shapes. Cost: a triangulation implementation is large; guess: skip, use jittered Voronoi-free cell regions instead.

Rivers: Dwarf Fortress traces rivers from eroded mountains to ocean or lakes ([search summary](https://en.wikipedia.org/wiki/Dwarf_Fortress); anecdotal). Diablo 1 caves retry rivers until length and bridge constraints hold (above). For us the river is a short spline with a controlled crossing point; a downhill trace is unnecessary.

Roads over terrain: Parish and Müller grow roads with an L-system over population and elevation maps ([SIGGRAPH history](https://history.siggraph.org/?p=116923)); Galin et al. model roads outside cities, including bridges and junctions ([paper, not readable here](https://www.cs.purdue.edu/homes/bbenes/papers/Galin11CGF.pdf); I could not confirm a least-cost formulation). Least-cost paths over a cost map are a standard idea (guess based on general knowledge; not sourced). Not a fit for us: our roads must be designed corridors, not terrain-optimal.

### 2.4 Procedural tower defense

I found no primary source on Infinitode 2 or Mindustry sector generation (searches returned nothing usable), and Bloons and Creeper World were not researched. Kingdom Rush-style hand-authored paths: not sourced beyond the paper below.
Academic work found only through search snippets (not read in full): a Kingdom Rush Frontiers paper that represents the path geometrically and searches for similar paths, evaluated by a Turing test ([Du and Li](https://www.semanticscholar.org/paper/Automatic-level-Generation-for-Tower-Defense-Games-Du-Li/78cb32c8d699c9f477c126c453117f2a13cfdde5)); an Aalto thesis that scores candidate paths by shape against a target difficulty and reports generating a level in under a second ([Aalto](https://aaltodoc.aalto.fi/items/d4db6e73-5499-4d12-a42d-daa58b252683)); a genetic-algorithm tower defense generator that restarts when no path exists ([Brezocnik et al.](https://www.researchgate.net/profile/Lucija-Brezocnik/publication/351488584_Procedural_Content_Generation_of_Custom_Tower_Defense_Game_Using_Genetic_Algorithms/links/610bed15169a1a0103df84ec/Procedural_Content_Generation_of_Custom_Tower_Defense_Game_Using_Genetic_Algorithms.pdf)); a thesis that dropped WFC plus Bezier curves as too time-consuming ([diva-portal](https://www.diva-portal.org/smash/get/diva2:1442180/FULLTEXT01.pdf)); and a jigsaw-tile paper ([ResearchGate](https://www.researchgate.net/publication/367548519_A_Novel_Procedural_Content_Generation_Algorithm_for_Tower_Defense_Games)). Takeaway: shape-scoring a path against a target is the closest published precedent to what we need; a Turing-test style review (does a sample read as designed) is the accepted evaluation.

### 2.5 Evaluation practice

Shaker, Togelius and Nelson split methods into constructive, generate-and-test and search-based; search-based is generate-and-test with a graded score and candidates made by modifying earlier ones ([book site](https://pcgbook.com/); definitions from search-result summaries, chapter PDF not readable). Smith and Whitehead's expressive range analysis plots a generator's output over metrics (the paper used linearity and leniency for platformer levels) to expose bias and gaps ([paper](https://www.pcgworkshop.com/archive/smith2010analyzing.pdf); summary from search). Mixed-initiative tools (Tanagra, Sentient Sketchbook) were not researched. Studios in the sources above validate by flood fill and walkability (Diablo 1 lockout, Bad North navigability), minimum-size thresholds, and retries. I found no source on large-scale automated playtesting for chunk generators; not verified.

## 3. Comparison table

| Approach | Games / sources | Authored vs random | Playability guarantee | Visual quality control | Determinism and runtime | Size for us | Fit |
|---|---|---|---|---|---|---|---|
| Hand-authored segments with ports (owner plan) | Diablo 2/3, Spelunky, Dead Cells | Shape authored; order, mirror, scale random | By port contract plus checks | High: each piece reviewed once | Trivial; ints and floats, ms | 250 to 400 lines plus data | 5: matches our need for designed corridors |
| Path/graph first, then fill (Spelunky, Dead Cells) | Spelunky, Dead Cells | Graph rules authored; choices random | By construction | Medium; depends on pieces | Trivial | 100 to 200 lines (our region chain already is the graph) | 5: we adopt it as the frame |
| Set pieces (Diablo 1 / DCSS vaults) | Diablo 1, DCSS | Whole landmark fixed; surroundings random | Place first, build around | Very high at landmarks | Trivial | 100 to 200 lines | 4: bridge, ridge, Heartkeep, ruins |
| Generate-and-test with checks | Diablo 1, Bad North | Anything | Reject on fail | None by itself | Cost = tries x cost per try | Exists | 4: keep, but cap tries and cache |
| Search-based scoring (sockets, path shape) | Aalto TD thesis, PCG book | Score authored | By constraint plus score | Tunable via score | Bounded iterations; deterministic with seeded RNG | 150 to 250 lines | 4 for sockets, 3 for the road |
| WFC on a coarse grid | Bad North, Townscaper, Qud | Tiles authored; layout random | Needs path constraint; can contradict | High if tiles are good | Heavy for GDScript; restarts | 300 to 500 lines plus 100+ tiles (guess) | 2: later, decoration only |
| Graph grammars / cycles | Unexplored | Rules authored (thousands) | By construction | Medium | Moderate | Large; needs tool | 1: overkill for one map shape |
| Polygon (Voronoi) regions | Red Blob mapgen2 | Parameters | Weak for roads | Organic look | Delaunay is big | Large | 2: irregular regions only if jitter is not enough |
| L-system / least-cost roads | Parish and Müller, Galin | Rules and cost maps | Weak | Realistic, not designed | Heavy | Large | 1: wrong goal |
| Free-form spline through random waypoints (today) | Our spline valley | Nothing authored | Only retry | Low: snakes, staircases, twists | Cheap but many retries | Exists | 2: cause of the pain |

## 4. The top three, built in our architecture

Common frame: the six regions in fixed road order give a chain of five gates; each gate is a port with a position and heading on a region border. Everything is data in `godot/content/valley/` and pure functions in `godot/sim/map/valley/`, one derived random stream per concern, only `+ - * / sqrt floor min max abs`.

### 4.1 Port-based segment library with a composer (owner plan, tightened)

Files: `godot/content/valley/segments.gd` (data: per template, control points in a local frame, entry and exit port, half-width, clearance, tag, mirror allowed, min and max scale); `godot/sim/map/valley/segment_fitter.gd` (rotate, mirror, scale to a gate pair); `segment_composer.gd` (picks per region role from a weighted list, chain checks); `ValleyLayout._spine` and the sections' own waypoint code are removed.
Stages replaced: road (fully), region borders (gates become the ports, so jitter moves gates, not free waypoints), validation (checks run per template in a unit test and per composition at runtime).
Data format: a template is a Dictionary of `Vector2` control points normalised to a unit frame, plus integers for width and clearance; the road is the Hermite spline already in `road_spline.gd`, so rasterisation and `Route` stay.
Risks: repetitive feel with a small library (see section 5); scaling a template to fit a gate pair distorts curvature (mitigate by bounded scale and a curvature test); ports that are too regular look like Lego (offset entrances, as Diablo 3 does).
One-PR prototype (under 300 lines): the three Outer March / Meadow templates (sweep, S-bend, wide C) plus fitter and composer for the first two regions only, behind a debug dump, no change to goldens. Test: every template fits every legal gate pair in a grid of gate positions, or is declared invalid for it.
Metrics: share of diagonal road, min lane gap (must stay at or above `LANE_GAP`), max straight leg, retry count per map, generation time on seeds 1 to 3000, number of distinct road shapes (hash of the rasterised polyline) over 1,000 seeds.

### 4.2 Set pieces for the landmarks, placed first

A set piece is a fixed-shape template with a fixed footprint, its own socket layout and its own terrain heights: the bridge crossing (straight, level, perpendicular approaches), the Ridge wrap with its high-ground sockets, the Fold ruins plus feeder merge, the Heartkeep approach. They are placed before the connecting roads, and the connecting roads are the segments of 4.1 that run from one set piece's exit port to the next one's entry port. This is Diablo 1 set pieces and DCSS "build around the vault".
Files: `godot/content/valley/set_pieces.gd` (data), `godot/sim/map/valley/set_piece_placer.gd` (anchor, mirror, clearance check against the river and the board edge).
Stages replaced: the sections' ground and socket code for those landmarks (`section_ground.gd`, `section_sockets.gd` become data-driven); bridge placement stops depending on luck.
Risks: the four landmarks look the same every run (mitigate with two variants each plus mirror and a few cosmetic prop slots); the owner's lore says regions are a vocabulary, not compartments (the plan says six hard-coded compartments are not wanted: a set piece covers a part of a region, not all of it).
Prototype (under 300 lines): the bridge set piece only, with the river spline forced to pass through its footprint; check the river crossing angle and flat approaches over 3,000 seeds.
Metrics: bridge approach straightness (max heading change over the last 4 cells before the span), river-road crossing angle, rejection rate caused by the river placement, share of seeds producing a winding river (river length over straight distance, target above 1.25: guess).

### 4.3 Scored socket placement (search-based, small)

Replace per-section socket rules with one pass: enumerate candidate 2x2 sockets (legal cells off the road, off the river, with a clear 1-cell margin), score each by the road length it covers within tower range, by height advantage, by spacing from other sockets and by a bonus at bends, then choose greedily with a seeded tie-break and 3 to 5 seeded restarts, keep the best total score, subject to 24 to 30 sockets and per-region minimums (Ridge scarce, high ground only).
Files: `godot/sim/map/valley/socket_scorer.gd`, scoring weights in `godot/content/valley/layout_rules.gd`.
Stages replaced: socket placement and the "stand-in blocks" count rule; coverage becomes a measured score, not a side effect.
Risks: greedy placement clusters (add a spacing penalty); the scores drift into a fixed look (use the expressive range plot to see it); weights are tuning work.
Prototype (under 300 lines): scorer working on the current valley's roads, compared with today's sockets for the same seeds.
Metrics: socket coverage (share of road cells within range 4 of at least 2 sockets), minimum coverage on the worst 1% of road, socket count distribution, hero reachability (existing `HeroGraph` caps), time per map.

### Not recommended now: WFC for terrain

If the owner wants more varied terrain, a coarse WFC pass over terrace height classes with the road pinned is the most plausible use (Boris the Brave: pinned fixed tiles, regions with different tile sets). Defer until the road and sockets are settled; a cheaper step is authored height fields plus low-frequency noise, as the owner already decided.

## 5. Honest assessment of the segment-library plan

Supported by the evidence: hand-authored chunks with an exit contract are the dominant shipping method (Spelunky, Dead Cells, Diablo 3, Bad North). Each piece can be tested alone, which is exactly the owner's point about the bridge twist. The Aalto and Kingdom Rush papers (snippets only) point the same way for tower defense: variation is on a designed path shape, not free curves.

Known pitfalls, with evidence level:
- Repetition. Boris the Brave warns that local solvers and tiles get samey on large maps and recommends region-specific tile sets ([WFC tips](https://www.boristhebrave.com/2020/02/08/wave-function-collapse-tips-and-tricks/)). Diablo 3's answer, per a secondhand write-up, is big tiles and offset entrances. Our map has one road, so repetition shows across runs, not within one.
- Combinatorial explosion. Unexplored needed about 5,000 rules for a whole dungeon game; we need a chain of five links, so a few templates per link is enough. How many templates are enough: Bad North's 300+ tiles and Townscaper's estimated 500 apply to tile-grid solvers, not to road pieces. I found no published figure for road-segment libraries. My guess: 2 or 3 per region role (8 to 14 total) with mirroring gives 100+ distinct roads; test it by counting distinct hashed shapes over 1,000 seeds and stop adding when the count saturates.
- Seams. Practitioners hide them with large pieces, offset entrances and repair pieces (Diablo 1 minisets). Concretely: matched port headings and widths (already in the decision), a short shared "blend" stretch between segments with a curvature limit, and a socket-free margin at joins.
- Bad North and Diablo 1 both needed restart logic and late fix-ups, so plan for a rejection budget and measure it.

Complementary additions (ranked): the scored sockets (4.3), set pieces for landmarks (4.2), expressive-range reporting (section 7), authored height fields plus noise for terrain, and, much later, WFC for decoration. Better than per-section waypoints in all cases: build the road before sockets and terrain, and make the river a plan-level spline that the bridge set piece anchors.

## 6. Staged implementation plan

Each step is under 300 production lines, has a test, and leaves main releasable.

| Step | Work | Testable result |
|---|---|---|
| 0 | Expressive-range report script: seeds 1..3000, outputs histograms of the metrics below to a text file (no new rules yet) | Baseline numbers for today's generator, committed as a doc |
| 1 | `segments.gd` data plus fitter for 3 templates, unit tests on ports and curvature | Every template fits its legal gates; curvature below the limit |
| 2 | Composer for Outer March and Meadow with rejection budget | Distinct-shape count, diagonal share and straight-leg metrics beat baseline |
| 3 | Bridge set piece and river anchoring | Straight level approaches on 100% of seeds |
| 4 | Ridge wrap and Ancient Fold / feeder merge templates | Feeder merge valid, hero caps hold |
| 5 | Heartkeep approach template | Lane gap and length checks pass |
| 6 | Sections follow `slot.spine`; delete section waypoint code | Goldens re-recorded under a decision record (deep tier) |
| 7 | Scored sockets | Coverage metrics at or above baseline, count 24 to 30 |
| 8 | Terrain: authored height fields plus low-frequency noise | Terrace variance metric and a visual review |
| Defer | WFC decoration, polygon regions | Only if the owner finds terrain flat after 8 |

Decision points for the owner: (a) after step 0, accept the baseline and set targets for the metrics; (b) after step 2, judge the road shapes in PNGs against the reference map; (c) before step 6, approve the golden re-record; (d) after step 7, choose the socket scoring weights.

## 7. Metrics and tooling

Report per generator (3,000 seeds, histogram per metric, in the spirit of expressive range analysis): share of diagonal road, min lane gap, max straight leg, curvature maximum, road length, number of sockets, socket coverage, hero path length to each region, retry count, rejection reasons, distinct road shapes, generation time (mean and 99th percentile; target mean 0.15 s on phone class CPU, to be measured on the iPhone, not on the desktop). Review 12 random PNGs per change as a Turing-style test: can the owner tell which road is the "designed" one.

## 8. What we should stop doing

- Free-form waypoints through the middle of a region as the road source; they caused the twist and the snakes.
- Sections that draw their own road; the road should be one composed object.
- Judging a generator from a handful of seeds; use distributions.
- Letting retry-until-valid hide a high rejection rate; record the rate and fail a test when it passes a budget (Diablo 1 shows that hidden restarts accumulate bugs).
- One rule set per section for sockets; score them globally.
- Region borders as the source of truth for road shape; gates and ports are, borders are a consequence.
- Adding new algorithms (WFC, grammars, Voronoi) before the baseline metrics exist.

## 9. Not verified

Diablo 2/3/4 internals beyond what is cited; Hades; Into the Breach; Infinitode 2; Mindustry; Bloons; Creeper World; Warcraft III and StarCraft generators; Tanagra and Sentient Sketchbook; the full text of Smith and Whitehead, the PCG book, the Aalto thesis, Kingdom Rush paper and Galin et al.; the Caves of Qud WFC talk; GDScript timings for any of the above; all file-size estimates and the 8 to 14 template count are guesses.

## 10. References

- https://boristhebrave.com/2019/07/14/dungeon-generation-in-diablo-1
- https://www.d2mods.info/forum/kb/viewarticle?a=367
- https://github.com/jaenster/libd2
- https://www.nme.com/news/diablo-4-will-include-five-distinct-regions-and-hundreds-of-dungeons-3193980
- https://axandros.itch.io/diablo-like-level-generator/devlog/152703/a-rough-initial-attempt-at-level-generation
- https://tinysubversions.com/spelunkyGen/
- https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-
- https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/
- https://research-portal.uu.nl/en/publications/generating-missions-and-spaces-for-adaptable-play-experiences/
- https://nest.pijul.org/fiddlerwoaroof/crawl/changes/R6XS2HO5QX2FJUGL5UQQRNETKCMYWTUFPHPPS5SYWK3OQA4UDUQQC
- https://www.gamedeveloper.com/design/tapping-into-the-potential-of-procedural-generation-in-caves-of-qud
- https://gdcvault.com/play/1025913/Math-for-Game-Developers-Tile
- https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making
- https://www.boristhebrave.com/2020/02/08/wave-function-collapse-tips-and-tricks/
- https://www.redblobgames.com/maps/mapgen2/
- https://history.siggraph.org/?p=116923
- https://www.cs.purdue.edu/homes/bbenes/papers/Galin11CGF.pdf
- https://www.semanticscholar.org/paper/Automatic-level-Generation-for-Tower-Defense-Games-Du-Li/78cb32c8d699c9f477c126c453117f2a13cfdde5
- https://aaltodoc.aalto.fi/items/d4db6e73-5499-4d12-a42d-daa58b252683
- https://www.diva-portal.org/smash/get/diva2:1442180/FULLTEXT01.pdf
- https://www.researchgate.net/publication/367548519_A_Novel_Procedural_Content_Generation_Algorithm_for_Tower_Defense_Games
- https://pcgbook.com/
- https://www.pcgworkshop.com/archive/smith2010analyzing.pdf
