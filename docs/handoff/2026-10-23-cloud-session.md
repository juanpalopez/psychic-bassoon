# Handoff: cloud session of 2026-10-22 and 23

Notes for picking this work up in a local session. GitHub (tickets, PRs, comments) is the source of truth; this is a map to it.

## Start here

1. `git pull` on `main`, then `godot --headless --path godot --import` once.
2. Check that release `v0.1.0-alpha.8` exists with its three builds (release PR #456 tags it through CI's `tag` job). If the push run did not tag, follow CLAUDE.md, "CI/CD and releases".
3. Pick the next item from "Open work" below; the owner decisions listed under it come first where they block.

## Released

- `v0.1.0-alpha.6` and `v0.1.0-alpha.7` are published with the Linux, Windows and macOS builds.
- `v0.1.0-alpha.8` comes from release PR #456, merged at the end of this session.

## Owner decisions this session (recorded in the files named)

- **Hero RFC** (`docs/rfcs/2026-10-22-strategic-hero-movement-and-bridges.md`): accepted with amendments. The prototype is a fixed seed of the generated valley, not a hand-made map (`docs/lessons/2026-10-22-hero-movement-fixed-seed.md`).
- **The Knight** is on the game board in every run. Mechanic test boards add it only when needed. It moves anywhere walkable. A new move order releases the foe it holds, but a foe that keeps attacking it chases it while it is in reach (`docs/lessons/2026-10-23-knight-on-the-game-board.md`, CLAUDE.md).
- **Models** (CLAUDE.md, "Who implements"): Opus designs, mentors, proposes architecture and runs deep reviews. Haiku implements well-defined tickets; Sonnet implements the rest and every Deep-tier area (`docs/lessons/2026-10-23-model-roles.md`).
- **The map** (`docs/rfcs/2026-10-23-longer-valley-road.md`, #470):
  - The layout valley keeps one road crossing plus the hero-only crossing. The river crosses the whole valley.
  - The road's target is **time under fire**, not cells. The layout valley's median must land within 90–110 % of the strip valley's, and no seed below 75 %, over seeds 1..300. Cells (100–150) are a guide.
  - The plan is a layout library: 3A first (today's layout, one U-turn per region), then more spawn and Heartstone layouts. 3B (five-run serpentine) is the fallback.
- **Wide road (#441):** the plumbing is merged with the band off. Option B (range measured to the band's edge) is ticket #446.

## Merged this session

- Road and map:
  - #436 and #438: the segment library and fitter.
  - #439 and #442: the composer.
  - #441: the wide-road plumbing, with the band off.
  - #457: the composed road in every region.
  - #463: the feeder on the top edge.
  - #465: `Route.for_map` and `MapGen.generate_layout_valley`.
  - #466 and #468: the layout-valley bridges and scatter. #461 stays open.
  - #471: the hook and u_turn templates, not in `ALLOWED` yet.
- Hero:
  - #445: the RFC amendments.
  - #454: `HeroGraph.from_map` and `path`.
  - #455: the Knight on the board and `moveHero`.
  - #459: shared `Fighter` and `Melee`.
  - #467: the Knight holds and fights foes. Its goldens were re-recorded.
- Docs and rules:
  - #437: the deep research.
  - #464: model roles.
  - #470: the longer-road RFC with the time-under-fire gate.

## Open work and where to resume

- **#460, the longer road (3A step 2).**
  - The branch `feat/road-regate` holds an unmeasured WIP (a917ede): the gates move, `GATE_INSET` drops to 2, and `ALLOWED` adds the hook for the March, Meadow and Crossing.
  - It also holds the measuring script `godot/tools/measure_road_time.gd` (786759e). Run it in the background: `godot --headless --path godot -s res://tools/measure_road_time.gd -- --n=300`. A 40-seed run took over 120 s, so check the redraw counts first.
  - The estimate is about 94 route cells and 50 s under fire, short of the 57.5 s floor, because the Ridge can't hold a hook.
  - Before opening PR 2, decide where the rest comes from (RFC section 8, question 5).
  - The measured baseline is in RFC section 7.
- **#458, the layout valley on the game board** (branch `feat/board-layout-valley`): waits on #460 meeting its gate, and on #469.
- **#469, road cells under the curve:** waits on the owner's choice (below).
- **#446, wide-road option B** (range to the band's edge): not started.
- **Heroes (epic #275, the RFC's steps):** #451 (fighting) closes with #467. Next:
  - #452: the Knight's skills, Rally Cry and Blade Whirl.
  - #453: the prototype seed with two crossings and strategic positions (content; it can run in parallel).
  - The move UI (#335: tap the hero, then a spot).
  - The minimap and edge markers (#329).

## Decisions waiting for the owner

- **#469 (road cells under the curve):** marking every cell the 0.9 bed overlaps makes almost no layout stitch under the "3 centre-line cells in reach" socket rule (2 of 89 draws). The work is on the branch `wip/469-road-band`, not for merge (it has `BAND_SLACK` experiment constants). Options:
  1. Count curve length in reach instead of cells.
  2. Raise `SOCKET_COVERAGE_REACH` to about 2.7.
  3. Fix it on the render side instead: clip the bed or snap the cells.
  4. Reject roads with many diagonals.
- **Knight balance (#467):** the Knight at its home spot adds about 4 median waves to the bot's runs, and losses fall from 8 to 5 of 12. Tune `godot/content/heroes.gd` or keep it.
- **The 3A re-gating:**
  - May `GATE_INSET` be 2?
  - May the spawn rows be (1, 2)?
  - May the cuts move (`LEFT_Y` 11, `MIDDLE_Y` 8)?
  - Where does the Ridge's missing length come from: a Heartkeep hook, a wider middle column, or the river further west?
- **Slow foes' speeds:** the Orc walks about 123 s and the Golem about 167 s on a 70-cell road, past the brute cap of about 100 s that the research suggests (RFC section 7).

## Gotchas learnt here

- Run one GUT script with `-gconfig=`, or GUT runs the whole suite.
- `pkill -f <pattern>` inside a command containing the pattern kills its own shell.
- The cloud environment blocks force-push. Bring a PR branch up to date by merging main in.
- `gh` isn't authenticated in the cloud container, so tickets can't be added to the project board from there. Add these by hand: #446, #449–#453, #458, #460–#462, #469.
- A review must finish before merge; a background merge job from another session merged #439 mid-review.
- Squash-merging a PR whose commits say `Closes #N` closes the ticket. Give an explicit `Refs #N` merge message when the ticket must stay open (#461, #460).
