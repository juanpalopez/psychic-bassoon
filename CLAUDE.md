# Papercraft Kingdom Defense

A papercraft stop-motion tower defense for phones and tablets, native on iOS first and on macOS, Windows and Linux next (Android only if wanted later; the web build is dropped, owner 2026-10-18, `docs/lessons/2026-10-18-native-only.md`). **Godot 4 + GDScript**. The look is "Hand-Folded Fantasy", a papercraft diorama of a fantasy valley (`docs/art/STYLE.md`, owner 2026-10-18). The design is the GDD in `docs/GDD.md` (adopted by the owner on 2026-10-11); the old Scrapline medieval design and the 2D prototype are no longer the rules target. The Three.js game that shipped Phases 0 to 2 is retired (last build: the tag `web-three-final`); the TypeScript simulation that held the formulas is removed from the tree (Phase 4, step 8) and stays readable in that tag (`git show web-three-final:src/sim/...`). The game is renamed Papercraft Kingdom Defense; the repo stays `psychic-bassoon`, and the code was renamed on 2026-10-13 (#163). **On 2026-10-19 the owner renamed the game Kingdom of the Fold** (`docs/lessons/2026-10-19-kingdom-of-the-fold.md`): the homepage uses the name first (#370), and the in-game title, build file names, the GDD and this file follow in later PRs; until then the code keeps Papercraft Kingdom Defense.

- Plan and roadmap: `docs/PLAN.md` (phases 0–8, each closed by a gate; the engine decision is in it)
- Design, lore and naming: `docs/GDD.md` (the owner's design document) and `docs/PLAN.md` → Design (the summary, the mapping from the ported sim, and the gaps in the GDD). Tower and foe ids are stable keys only where a fixture uses them; the ported core (PRNG, maps, routes) has fixtures, the tower and foe ids do not, and they already use the GDD's. Display names and lore strings live only in `godot/content`.
- Original prototype (a starting point for numbers, not the rules target): `prototype/scrapline.html`

> Paths named in this file that do not exist yet are created in the phase that needs them: `godot/`, `fixtures/` and the Godot CI (Phase 3), `godot/sim/` (Phase 4), `godot/render/` and `godot/ui/` (Phase 5), `godot/assets/` (the Scrap Goblin, ticket #157, and Phase 6) and `docs/art/` (Phase 6).

## Commands

Godot (from Phase 3; versions pinned in `.godot-version`):

```bash
godot --path godot                                   # open or run the project
godot --headless --path godot --import                # once per fresh checkout, so class_name scripts resolve
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit   # GUT tests
(cd godot && gdformat . && gdlint .)                 # gdtoolkit: format and lint (config in godot/)
scripts/run-gut-parallel.sh                          # the whole GUT suite, one Godot process per test script; half the cores up to 4 (on CI one per core up to 8; -j or GUT_JOBS overrides); reruns a crashed run once and reports it; prints the slowest scripts
godot --path godot -- --stress=80 --fps             # from #319: the phone-check crowd and the fps overlay
godot --path godot -- --layout-valley --seed=7      # #513: play the 40 by 24 layout valley for that seed (debug flag; the default board is unchanged)
scripts/ios-run.sh                                   # export the Xcode project, build, install and launch on a connected iPhone (macOS with Xcode)
mkdir -p build/linux && godot --headless --path godot --export-release "Linux" ../build/linux/papercraft-kingdom-defense.x86_64   # desktop export, as CI runs it
```

- Desktop presets: `Linux`, `Windows` (to `build/windows/papercraft-kingdom-defense.exe`) and `macOS` (to `build/macos/papercraft-kingdom-defense.zip`, ad-hoc signed, not notarized); each needs the pinned version's export templates. `build/` is in `.gitignore`: exports and the Xcode project live there; `scripts/ios-run.sh` keeps Xcode's derived data in `~/Library/Developer/Xcode/DerivedData/PapercraftKD-ios` (`PKD_DERIVED`), because codesign rejects an app built inside an iCloud-synced folder (#354). The owner's step-by-step guide is `docs/IPHONE.md`.
- `scripts/ios-run.sh` finds the first connected physical iPhone (or `PKD_DEVICE`, its UDID), exports `build/ios/PapercraftKD.xcodeproj` with the `iOS` preset (Xcode project only), builds it with `xcodebuild` and automatic signing, waits while the phone is locked, then installs and launches it with `devicectl`. It uses `/Applications/Xcode.app` when `DEVELOPER_DIR` is unset, because `xcode-select` may point at the Command Line Tools. The Apple team id comes from `PKD_TEAM_ID` or `~/.config/pkd/team_id`; the script writes it into the preset only for the export and always restores the file, so the committed preset keeps `application/app_store_team_id` blank (a GUT test checks it). Never commit a team id.
- With a free Apple ID an install expires after 7 days: run the script again. The first launch on a phone needs the developer trusted in Settings → General → VPN & Device Management (and Developer Mode on in Settings → Privacy & Security). TestFlight needs the paid Apple Developer Program.

Repo checks and tooling (TypeScript and Node):

```bash
pnpm install
pnpm test         # Vitest (repo scripts)
pnpm check:assets # godot/assets against assets/CREDITS.md
pnpm check:fixtures # the frozen fixtures against fixtures/SHA256SUMS
pnpm lint         # Prettier check + ESLint + tsc --noEmit
pnpm format       # Prettier --write (run before committing)
```

## Working rules

- **Work one phase at a time.** Implement only the current phase from `docs/PLAN.md`, then stop and report whether its gate passes. Don't start the next phase or add features from later phases. **Exception (owner, 2026-10-11):** Phase 5 starts now as a greybox, in parallel with the rest of Phase 4. The greybox only reads sim snapshots and sends commands, so it cannot change parity; it never edits `godot/sim` or `fixtures/`. Art, lore and everything else from Phases 6 to 8 still wait, except what the owner opened early: Track B (ticket #157, the Scrap Goblin through the asset pipeline), the Phase 7 content the owner asked for (the tickets under epic #270), and the Hand-Folded Fantasy epic (#316, owner 2026-10-18), which runs the Phase 6 art and the Phase 7 map work (#320 to #323) now. Sim API the greybox needs (a read-only snapshot, previous foe positions, event draining) is added by Phase 4 sim tickets with tests and deep review, never inside a greybox PR; `godot/render` and `godot/ui` use only `Game.create`, `Game.submit`, `Game.tick`, read-only accessors and drained events, and never `rng`, `route_rng`, `pending` or field assignments on the state (a CI check enforces it from greybox step A1, ticket #156; it scans `godot/render`, `godot/ui` and `godot/main.gd`; plain reads of state fields are allowed until read-only accessors exist).
- **The design is the GDD; numbers start from the prototype.** Port before inventing applies only to the ported core (PRNG, road generator, routes), which stays equal to its fixtures (made by the retired TypeScript sim); those fixtures are frozen and never regenerated, and `fixtures/SHA256SUMS` enforces it in CI, and the game state, commands and tick are covered by GUT tests. Foes, towers, combat and economy are designed from `docs/GDD.md` and tested in GDScript; where the GDD gives no number, start from the prototype's (`web-three-final:src/content`) and tune with headless runs. From the combat port on, GDScript replay goldens (written by the sim itself, with float bits) are the regression check.
- **Keep `main` releasable.** Run the checks for the code you touched before every commit: `pnpm lint && pnpm test` for the repo's TypeScript and Node scripts, and `gdformat`, `gdlint`, GUT and the Linux desktop export for Godot.

## Architecture

```
godot/
  sim/       pure GDScript game logic: grid, mapgen, routes, waves, towers, foes, economy
  content/   data only: tower/foe defs, wave tables, lore strings
  render/    scenes and scripts: terrain, foes (MultiMesh), towers, camera, effects
  ui/        HUD scenes (Control nodes) and the Theme
  tests/     GUT tests and the fixtures for the ported core
fixtures/    frozen JSON from the retired TypeScript sim for the ported core (prng, maps, routes); GDScript replay goldens live in `godot/tests/goldens/`
```

- `godot/sim` must never touch the scene tree or engine singletons: no `Node`, no `get_tree`, no `Engine`, `Time` or `OS` calls, no `randf`/`randi`/`randomize`. A lint script enforces it; don't disable it.
- The sim runs on a fixed 30 Hz tick and owns all game state. Render and UI only read state snapshots and events.
- Player actions reach the sim only as commands (`build`, `upgrade`, `sell`, `launchWave`, `chooseSpec`, `activateAbility`, `moveHero`), never by mutating state directly. Every run on the game board starts with the Knight; mechanic boards have none unless a test places it (`Heroes.place`; owner, 2026-10-23, `docs/lessons/2026-10-23-knight-on-the-game-board.md`).
- All randomness goes through the seeded PRNG in `godot/sim/rng.gd` (mulberry32 on 32-bit integers). The same seed plus the same commands (plus, from Phase 8, the run's frozen meta-loadout: the tech-tree state at the start of the run) must replay identically; the ported core must give values equal to the TypeScript fixtures. Sockets, elevation and other new map layers draw from their own derived streams (`deriveRng`), never the map stream, so the frozen fixtures keep matching.
- All balance numbers (cost, damage, range, rate, hp, speed, rewards, wave scaling) live in `godot/content`. Logic files contain no magic numbers.
- **The game board is built from six fixed sections** (owner, 2026-10-20, #381, `docs/lessons/2026-10-20-sectioned-valley.md`): `MapGen.generate_valley` cuts the 32 by 20 board into six strips of columns in a fixed order (Outer March, Broken Ridge, Bluewater Crossing, Sunken Meadow, Ancient Fold, Heartkeep Approach), the road crossing all six; the seed moves the strip boundaries and the gate rows and shapes each section inside its strip. Each section is a `ValleySection` in `godot/sim/map/valley/sections/` with its own rules in `godot/content/valley/`, its own random stream (`ValleyPlan.section_rng(seed, id, attempt)`), and `ValleyChecks` (road, sockets, bends, high ground, feeder, hero graph); `ValleyStitcher` draws only a failing section again and merges the six into a `GameMap` (with a `walkable` layer and `hero_bridges`). The layout valley (`MapGen.generate_layout_valley`, 40 by 24, played with `--layout-valley` until #458) has two lanes: the road forks at the Sunken Meadow's entry and the lanes meet again at the Crossing's exit (`FORK_LANES`, owner, 2026-10-24, #481, `docs/lessons/2026-10-25-fork-two-lanes.md`), so there are two crossings that foes (each picks a lane) and the hero both use, and no hero-only bridge. `Game.create` plays the strip valley on the default board; any other board (the mechanic tests name theirs, the frozen fixtures) keeps the route-first generator below.
- A map is a grid (32 columns by 20 rows, owner 2026-10-18, #320; it was 16 by 11 until then and 22 by 16 before that, and the legacy 9 by 13 only backs the frozen fixtures) with a main route from the spawn point to the Heartstone and a second spawn source that joins it (no detour; owner 2026-10-12 and 2026-10-16), sockets for towers (2x2 cells each; 21 to 30 on 32 by 20 (the sectioned valley; its narrow strips can hold fewer), 12 to 15 on 16 by 11), and three elevation levels. A terrain layer (terraces, regions, a river with bridges held by guards) comes from its own derived stream (#322, #323). The sim walks curved routes: a route-geometry layer rounds the grid path's corners and is the truth for movement, distance, range and hits, while the ported grid path stays pinned by the fixtures (#321). The road generator and routes are ported (a main road, and a detour only when asked: the game turns it off); sockets and elevation are new map layers on top of it. Foes pick a route; towers target across routes. **The layout valley (six regions in a 3 by 2 layout with a road composed from segment templates, `MapGen.generate_layout_valley`), which replaces the strip valley in #458, is 40 by 24 (#480, `docs/lessons/2026-10-24-fork-wide-road-bigger-map.md`; `BoardSpace` takes its size from the map in use, #484), its road forks before the river into two crossings that foes and the hero both use, and the road band is wide once #469 and #446 are settled (owner, 2026-10-24, `docs/lessons/2026-10-24-fork-wide-road-bigger-map.md`); until #458 lands the game board stays 32 by 20.** The sim keeps the grid, the routes (the grid path and its curve) and the sockets as plain data; Godot nodes only draw them.
- Game speed (1×/2×/3×) means more sim ticks per frame, never a bigger tick.
- For value parity with TypeScript use only `+ - * /`, `sqrt`, `floor`, `min`, `max`, `abs`. Traps: `/` on two integers is integer division in GDScript (divide by a float); keep PRNG values in [0, 2^32) and mask after every `*`, `+` and `^` (replacing `Math.imul` and `>>>`); `Math.round` becomes `int(floor(x + 0.5))`; avoid trig and `round`. Fixtures and goldens keep large integers and floats as hex bits and are compared with exact `==`.

### Domain-driven design

- `godot/sim` is the domain. Split it into bounded contexts by game concept (for example map, waves, combat, economy), one folder each, with a small public entry class. Contexts talk through commands, events and snapshots, not by reaching into each other's internals.
- Use the ubiquitous language from the lore table in names, types and tests (Scrap Goblin, Spool Guard, Prism Spire, Heartstone health, wave, Buttons, Golden Staples). No synonyms for the same concept. Display names and lore strings live in `godot/content` and the Naming table; a rename changes those, not the logic.
- Model state as plain data and pure functions. Value objects are immutable; the sim state is the single aggregate root that only commands change.
- Domain code never depends on infrastructure. `render`, `ui`, storage and the platform (iOS, desktop) are adapters that read snapshots and send commands.

## Rendering and performance

- Target: 60 fps with 80 foes on a mid-range phone (measured on the owner's iPhone 15 Pro in a native build). Budget: under 120 draw calls, at most 200k triangles in view, DPR capped at 2; provisional for the 32 by 20 map and the diorama until #97 measures it on the iPhone (owner, 2026-10-18, `docs/lessons/2026-10-18-diorama-budget.md`). Renderers: Forward+ on desktop, Mobile on iOS and Android (`rendering_method.mobile`); both must read as the same style (`docs/art/STYLE.md`, Renderers).
- One `MultiMeshInstance3D` per foe type. Don't create a node per foe.
- Camera: perspective, 20° FOV, pitched 62° zoomed out and 56° zoomed in (the pinch only zooms, around the fingers; settled in #313, and a GUT test reads this line), landscape framing (the board is drawn turned so the road runs left to right; the sim is untouched, one script converts sim cells to world positions), no follow camera. On the 32 by 20 map the camera pans across the map (owner, 2026-10-18): a run starts near the spawn (the spawn a quarter of the way across the screen, at the least zoom where a socket in the middle of the screen is 44 pt, never further out than zoom 0.4), the zoom-out limit shows the whole map as an overview, cells reach about 100 px wide at the closest zoom, and pan is clamped to the map plus a scenery margin (the middle of the screen stays within 2 cells of the map); the world carries on past the map, so the view never shows an edge (#328).
- Models come from glTF/GLB, in the style of `docs/art/STYLE.md` (squarish not voxel, painterly not flat, paper not plastic, readable at gameplay distance). Sources, in order of preference: the owner's Blender models (`assets-src/blender/`, `assets-src/papercraft/` and the look-dev in `assets-src/diorama_lookdev/`, some made with Claude) and CC0 packs as placeholders. AI mesh generators such as Meshy are not used (owner decision, 2026-10-13: the models were not good enough); a Blender model scripted with Claude counts as the owner's own. Keep a simple fallback mesh for any unit whose file is missing.
- Foes and towers are animated: foes walk, attack (a guard of the Guard Tent), get hit and die; towers idle and fire; guards idle, strike, fall and rise. The sim reports a foe being held (`FOE_ENGAGED`) and a guard falling or rising, not each blow, so the attack and strike clips loop while a foe is engaged until the foe dies, the guard falls or the foe is released; a per-blow event is added only if that looks wrong. `MultiMeshInstance3D` cannot skin, so foes with many instances play baked vertex animation in a shader, with the clip index and start time per instance in instance custom data. Render keeps a dying instance alive until its death clip ends, driven by the death event. Bosses are skinned glTF (`Skeleton3D` plus `AnimationPlayer`); towers animate separate parts in an `AnimationPlayer` with no skeleton. Triangle budgets (whole model per level): foe 800 to 1,200 with its own baked 512 px map, tower 1,500 to 3,000 on a shared atlas, boss 3,000 to 5,000 with a 1,024 px map, under frame caps of foes 80k, towers 45k, terrain and road beds 40k, scenery 32k and one boss 5k in total (see the plan; the tower cap assumes 20 towers, to be measured; `test_diorama.gd` asserts the terrain and scenery caps). One foe, the Scrap Goblin, goes through the whole pipeline first (the owner's Blender model, rig, clips and baked vertex animation; gate: 80 animated Scrap Goblins at 60 fps on the owner's phone) before any other foe does. Count draw calls and triangles with animation on, towers included.
- Terrain is a diorama built from the sim map at load time (owner, 2026-10-18; `docs/lessons/2026-10-18-hand-folded-fantasy.md`, superseding the cutting mat and tape road of 2026-10-17): painterly faceted terraces from the terrain layer's heights, corrugated cliff walls with a soil lip, a road bed along the curved routes, bridges over the river, and seeded scatter (forest, rocks, dirt, grass) as one `MultiMesh` per prop type, built in chunks and carrying on past the map into haze with no table edge (#324 to #326; the camera's views reach about 34 cells past the map on a tall phone at 40 by 24, so scenery carries on at least 37, `TerrainField.MARGIN`; #480, #488). No desk, cutting mat or tape. The ground is a `Diorama` (`godot/render/diorama/`) under `Board`: the terrain field, then builders in slots (terraces, water, road beds, scatter) that #325 and #326 plug into; one terrace is `TerrainField.TERRACE_STEP` (0.75 m), and every view stands things on `Board.surface_height`. Look colours live as `source_color` uniforms in `godot/render/paper/` and the `main.tscn` Environment, and the colours the terrain bakes into vertex colours come from one palette file, `godot/render/paper/terrain_palette.gd` (the STYLE.md palette; no colour literal elsewhere in the builders); the sim's routes stay the truth for movement, range and hits, and the cell decides tap picking. Terrain code reads the map snapshot only.
- Reuse meshes and materials, free nodes you remove, and avoid allocating objects every frame.

## UI

- The HUD is built from Godot `Control` nodes with one Theme resource that mirrors the Claude Design tokens. The Theme is written by `godot/tools/build_hud_theme.gd` (the tokens live at its top); change the tokens there and rerun it rather than editing `ui/hud_theme.tres` by hand. Never hard-code colours in scenes or scripts.
- The game is landscape only (owner decision); the exports lock the orientation (#319). Every action is reachable by the thumbs holding the phone, with tap targets of at least 44 pt. The overview zoom of the 32 by 20 map is for reading the map: a tap on a socket or tower there zooms in to it first (the camera flies in until the socket is at least 44 pt, centred, and then selects it; a drag or pinch during the flight cancels it), and building, upgrading and selling happen only at a zoom where a 2x2 socket is at least 44 pt (zooming out past that closes the build menu or tower panel; #328). Building happens from the build bar (owner, 2026-10-20, #377, `docs/lessons/2026-10-20-build-bar.md`): while a free socket is selected the bottom HUD row becomes one 88 px row of tower tokens and Close, Auto and Start wave step aside, nothing floats over the world, and a socket the bar or the top row would hide is eased to the middle at the same zoom. Heroes are moved by tapping the hero, then a walkable spot (#335); off-screen foes and the hero show at the screen edge and on a minimap (#329).
- Respect reduced motion: from #319, an in-game Reduce motion setting, saved between runs, read through one platform adapter (a small native plugin may later read the iOS setting), turns off screen shake and reduces particle effects (the web shell's `prefers-reduced-motion` read went with the web build).
- Audio still starts only after the first tap, a rule from the web build (browsers block audio before a gesture); the native builds do not need it, and a later change may drop it.

## Testing

- Every sim module gets GUT tests: map generation (road valid, routes valid, sockets valid, reproducible from its seed), wave composition, damage and armor, economy, and a full-run replay from a seed. The ported core is compared with `fixtures/`; from the combat port on, replays are compared with goldens written by the GDScript sim, and a golden changes only by a reviewed balance change, or by a reviewed sim change that a decision record names (the 32 by 20 map in #320 and the curved routes in #321, `docs/lessons/2026-10-18-valley-map.md`; deep tier).
- Fix the seed in tests; never depend on timing. A test about a mechanic names its board (`TowerFireKit.landscape`, `Game.create(seed, cols, rows)`); only a test about the game board uses the default.
- A headless test never reads MultiMesh instance transforms back (the dummy renderer returns the identity); it checks the function or array that computed them.
- **TDD where possible.** For `godot/sim` and `godot/content`, write the failing test first, make it pass, then refactor. A bug fix starts with a test that reproduces it. Render and UI code don't need test-first, but logic extracted from them (camera clamping, grid picking, formatting) does.
- Test the domain through its public commands and snapshots, not internals, so refactors don't break tests.
- The Vitest suite covers the repo's scripts (checks and tooling); `pnpm check:fixtures` guards the frozen fixtures.

## Code style

- GDScript with static typing everywhere (`var x: int`, typed arrays, typed returns). Prefer plain data and small functions over deep class hierarchies.
- **Code style: the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), enforced by tools, not by review.** `gdformat` formats and `gdlint` checks (gdtoolkit, pinned version; run from `godot/`, where `.gdlintrc` lives). CI fails on unformatted or unlinted code. Don't hand-format and don't disable a rule to get around it.
  - Naming: `snake_case` for files, functions and variables; `PascalCase` for classes and nodes; `CONSTANT_CASE` for constants and enum members.
  - Comments explain why, not what. Use `##` doc comments on public APIs.
- TypeScript code (the repo's scripts) keeps the Google TypeScript Style Guide with Prettier and ESLint.
- Small focused commits in the Conventional Commits format: `type(scope): summary`, for example `feat(sim): add seeded PRNG` or `fix(render): dispose removed meshes`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Mark breaking changes with `!` and a `BREAKING CHANGE:` footer.
  - Scopes (optional): `sim`, `render`, `ui`, `content`, `assets`, `docs`, `ci`, `build`, `deps`.
  - Summary is imperative, lowercase, no trailing period, at most 72 characters. The one exception is Dependabot's `Bump …` wording.
  - Release notes are generated from these messages, so write them for a reader of the changelog.
- Pull requests: the title follows the same format (PRs are squash-merged, so the title becomes the commit). Fill in the PR template and reference the ticket (`Closes #N`). The `PR checks` workflow rejects non-conforming titles and commits.
- **Keep PRs small (owner, 2026-10-18, #349):** a PR changes at most 300 lines of production code (added plus deleted; tests, docs, goldens, fixtures, assets, lockfiles, `.import`/`.uid` files and the generated `ui/hud_theme.tres` do not count) and should stay under 200. The `PR size` check (`scripts/check-pr-size.mjs`, run from the base branch so a PR cannot change it) fails above 300 and warns above 200; only the owner's `size-exception` label lets a larger PR through. **Agents never add or remove labels** unless the owner says so in the conversation, and then the PR gets a comment quoting that instruction (they act with the owner's token, so the label is trust-based). The rule applies to every task started after #350 merges; only #344, #345 and #346 finish as they are (owner, 2026-10-18, labelled on his instruction). Plan the split before writing code: a change that needs more than 300 production lines is split into a stack of PRs with `gh stack` (see Stacked PRs below), each under the limit, with its own tests and a working build, and the stack is reviewed per PR, in parallel (see Reviews); or the ticket is split. A move counts as a delete plus an add, so a large move is its own PR with the label. After a lower stacked PR is squash-merged, rebase the next one (`git rebase --onto origin/main <old base tip>`) before its size is judged.

### Reviews

Every PR gets an adversarial review before it merges, scaled to its risk so reviews stay affordable. Reviewers are Claude subagents, never the author's own context.

- **Agent and rulebook:** the project agent `adversarial-reviewer` (`.claude/agents/adversarial-reviewer.md`) reads `docs/REVIEW-CHECKLIST.md`, which holds the tiers, checks, limits and report format. Keep the checklist in step with this file.
- **Tiers** (owner, 2026-10-19: PRs are small now, so most reviews use a cheaper model; choose by what the PR touches, not by how it feels):
  - **Skip:** Dependabot bumps with green CI, wording-only docs. Check CI and the title, then merge.
  - **Light** (`haiku`, pass `model: haiku`): small, low-risk changes with no logic that can break the sim: docs with rules or numbers, `godot/content` data and numbers, tests only, copy and Theme tweaks, repo scripts, renames. At most about 100 changed production lines.
  - **Standard** (`sonnet`, the agent's default): most PRs, including `godot/sim` logic (map generation, combat, economy, waves; they still need tests first), render, UI, workflows that do not touch secrets, permissions or release, and rule changes in this file.
  - **Deep** (`opus`, pass `model: opus`): only determinism-critical sim code (the PRNG, the tick and command loop, the replay test, seed and snapshot handling) and anything that touches secrets, permissions, tokens, deploy or release trust (tag guards, release or deploy workflows). Rare: a sim PR that does not touch those is Standard.
  - **Escalate, do not guess:** a reviewer that cannot judge a change at its tier replies `ESCALATE: <reason>` and the caller reruns it one tier up. When unsure which tier, take the lower one, and escalate only if the review says so or the first review found a blocker in sim, security or release code.
- **When:** once the PR is ready and `ci` has run, not on every push. Run `gh pr checks <N>` first; reviewers do not repeat what green CI proved (lint, types, tests, the Linux export and its checked headless run, title format; the run catches logged script, resource and shader errors but renders nothing, so visual changes still need screenshots).
- **Input:** give the reviewer the PR number, base branch, head commit, ticket number, tier and, for a re-review, the earlier findings. Don't paste whole docs.
- **Stacks (owner, 2026-10-21):** one reviewer per PR, all started at once, each at the tier of its own PR, sharing a stack directory (`stack.md` from the caller, `report-<N>.md` and `notes-<N>.md` from each reviewer) so they see each other's findings; `/review-stack <PR numbers>` prepares and launches it. Every review merges the head onto the current base and runs the touched area's tests, because CI may have run on an old base. The rules are in `docs/REVIEW-CHECKLIST.md`.
- **Output limits:** at most 5 findings (blockers and majors first) plus at most 5 one-line minors, and a verdict. The report starts with `Reviewed commit: <sha>`.
- **Re-review:** after fixes, send only the earlier findings and the diff since the reviewed commit.
- **Post** the report on the PR as a comment headed `Adversarial review (Claude)`.
- **Resolve:** fix every `blocker` and `major`, or reply on the PR with the reason for declining. Never dismiss a finding without a reason. A PR with unresolved blockers does not merge.
- **Not a substitute for CI.** `ci` and `PR checks` must still pass. Move any finding a tool could catch (an ESLint rule, `actionlint`, a script) into CI, so the reviewer does not pay for it again.
- Other reviewers (a human, or Copilot when quota allows) are welcome extras, never the only review.

### Who implements (owner, 2026-10-23)

- **Opus designs and mentors:** architecture proposals, RFCs, design memos, the plan and brief for each ticket, decisions the owner must take, and deep reviews. It implements only when the owner asks.
- **Haiku or Sonnet implements:** Haiku (`model: haiku`) for well-defined tickets (a clear "Done when", one area, no open design choice), Sonnet (`model: sonnet`) for the rest; Deep-tier areas (the PRNG, the tick and command loop, the replay test, seed and snapshot handling, release trust) go to Sonnet at least. Either may propose a simple architectural change in its PR; a change that needs a real design choice stops and goes back to Opus and the owner.
- The caller picks the model when it launches the agent and says which in the PR (`docs/lessons/2026-10-23-model-roles.md`).

### Stacked PRs

- Use `gh stack` for work that builds on an unmerged change: `gh stack add <branch>` for the next layer, `gh stack submit` to push and link the PRs. One ticket per PR.
- Open each PR with `gh pr create` using a conforming title (`gh stack submit --auto` generates titles that fail `PR checks`), then run `gh stack submit` to link them.
- Merge from the bottom of the stack up, and run `gh stack sync` afterwards.
- Assets: models only as GLB (meshopt-compressed where it helps) in `godot/assets/`, with fonts, SVG HUD icons and audio beside them; sources go in `assets-src/` (Git LFS). Record every asset in `assets/CREDITS.md` with its source and licence. Allowed sources: CC0 packs (the row says CC0), the owner's original work (the row says `Owned by the owner (all rights reserved)`; the owner keeps the rights; a Blender model scripted with Claude and HUD icons drawn with Claude count as the owner's own), and, for fonts only (`.ttf`, `.otf`, `.woff`, `.woff2` under `fonts/`), SIL OFL 1.1 faces (the row says `SIL OFL 1.1`, licence text in `assets/licenses/`; owner decision, 2026-10-15). CI checks that each row says one of these. Do not use copyrighted characters, third-party images, brands or real people's likeness as a reference. Anything else needs the owner's say-so.
- Before drawing final reference sheets, shortlist CC0 packs and list the gaps in `docs/art/GAPS.md`. Sheets for pack-sourced units follow what the packs can supply; gaps are kitbashed from pack parts or built from primitives. Check each pack's licence file; if it is not clearly CC0, don't use it. The owner's foe models are built to the unit's triangle budget in Blender, baked to one 512 px map per foe with colours matched to the shared palette, and checked for a distinct zoomed-out silhouette before they replace a placeholder.

## CI/CD and releases

- Pull requests run only what the change can reach (`scripts/select-tests.mjs`, #359): docs-only changes skip the Godot job, and GUT runs the test scripts whose references reach a changed file. A change to content (except `godot/content/valley/`, traced by references like code), the PRNG, the tick and command loop (`sim/game`), goldens, fixtures, workflows or project settings, or to a file no test reaches, runs the whole suite. Pushes to `main` and tags always run everything.
- CI runs on every pull request and push to `main`: workflow lint, `pnpm lint`, `pnpm test`, the asset check, the frozen-fixture check, and the Godot job: pinned Godot and export templates (cached), `gdformat --check`, `gdlint`, the sim purity lint, GUT (including the fixtures), the headless game time budget, and the Linux desktop export, which must produce the binary and its `.pck` and run 300 frames headless with a clean log (`scripts/run-godot-checked.sh`: it fails on a non-zero exit, a timeout, or any `ERROR:`, `SCRIPT ERROR:` or `SHADER ERROR:` line; the dummy renderer draws nothing, so it catches scripts, missing resources and shader compile errors that log, not how anything looks) (the import step uses the same check); releases also upload the builds as the `godot-desktop` artifact (7 days). A red CI blocks merging.
- GUT runs in 4 matrix shards (`gut (shard 0..3)`, each a runner of its own; a PR's subset is split the same way): `scripts/run-gut-parallel.sh --shard i/4` deals the scripts out greedily by the seconds in `scripts/gut-times.json` (refresh it with `scripts/run-gut-parallel.sh --write-times` after the suite changes a lot; a missing or stale file only costs speed). Lint, purity, the bot game and the exports run once in `godot-checks`, and the job named `godot` is only the aggregate that the ruleset requires (it fails if a shard or `godot-checks` failed or was cancelled); the shared Godot setup is `.github/actions/setup-godot`.
- CD: after `ci` passes on a push to `main`, Pages serves `site/`: the Kingdom of the Fold homepage (`site/index.html` with `site/home.css`, self-hosted OFL fonts and the images listed in `site/CREDITS.md`; #370), which links to the releases list (not `/releases/latest`, which skips pre-releases) and gives the install steps for Windows, macOS and Linux, including how to get past SmartScreen and Gatekeeper, since the builds are not signed or notarized (#356). Phone builds are local (`scripts/ios-run.sh`) until TestFlight. Neither the web build nor the Three.js game is served.
- Release PR: `release-please.yml` keeps a `chore: release X` PR up to date from the Conventional Commits (version in `.release-please-manifest.json`, notes in `CHANGELOG.md`, `-alpha.N` until 1.0). Merging it tags main (the `tag` job, only for release-please's own PR) with a GitHub App token (`RELEASE_APP_ID` variable, `RELEASE_APP_PRIVATE_KEY` secret; the app must be on the `v*` ruleset bypass list, set up by the owner), which starts the release workflow. If a push run did not tag, run the workflow by hand from `main` with the release commit SHA (`workflow_dispatch`).
- Releases: pushing a version tag (`vMAJOR.MINOR.PATCH`, semantic versioning; a `-pre` suffix such as `v0.1.0-alpha.1` is published as a pre-release) runs the release workflow. It re-runs the checks with the Linux, Windows and macOS exports (the `all-desktop` input of `ci.yml`) and creates a GitHub Release with generated notes from the Conventional Commits and the three builds attached as zips. A cloud session could not create tags on 2026-10-19 (`git push` of the tag disconnected, and the tag API returned 403), so the owner pushes the tag from his clone (`git tag -a vX.Y.Z <sha> && git push origin vX.Y.Z`) on a green `main`; never create the release by hand on GitHub, or the workflow cannot attach the builds (`docs/lessons/2026-10-19-release-tag-from-owner-clone.md`).
- Keep workflows in `.github/workflows/`. Pin action versions and never commit secrets.

## Tickets

Work is tracked in the GitHub Project "Project Slag" (codename for Papercraft Kingdom Defense, formerly Scrapline): <https://github.com/users/juanpalopez/projects/4> (owner `juanpalopez`, project number 4). The board is the source of truth for progress. Every ticket follows this format:

- **Title:** `[Phase N] Imperative summary`, for example `[Phase 1] Seeded PRNG (mulberry32) with tests`. Epics read `[Phase N] Epic: name`.
- **Labels:** exactly one `phase-N`, one area label (`sim`, `render`, `ui`, `content`, `infra`, `docs`), plus `epic` for epics.
- **Body:** a short description, the plan section it comes from, and a "Done when" list that includes the tests. A gate ticket says which phase gate it closes.
- Add every ticket to the project board. Only create tickets for the current phase and the one after it; later phases stay as roadmap in `docs/PLAN.md`.
- Reference the ticket in commits and PRs (`Closes #N`).

### Tracking progress

Keep the board and the tickets current as you work, not after the fact.

- **Status flow:** `Todo` → `In Progress` when you start a ticket → `Done` when its PR merges. Only move a ticket to `Done` when its "Done when" list is met. Closing it by merging a PR with `Closes #N` is the normal path.
- **Comment on the ticket** when work starts (branch name) and when a PR opens (PR link plus what you verified and how). Note anything you could not verify.
- **One ticket per PR.** If part of a ticket can only be checked after merge (a deploy, a release tag), leave it open and say what remains in a comment. Use `Refs #N` instead of `Closes #N` in that case.
- **Blockers:** comment on the ticket and tell the user (missing file, repo setting, a decision). Don't work around them silently.
- **Gate tickets** close a phase gate: close one only when the matching gate checklist in `docs/PLAN.md` is fully met, and report it before starting the next phase.
- **Scope changes:** if work reveals a missing ticket, create it in the standard format and add it to the board rather than widening the current one.

Moving a ticket's status with the CLI (Status field options: Todo, In Progress, Done):

```bash
gh project item-list 4 --owner juanpalopez --format json      # find the item id by issue number
gh project field-list 4 --owner juanpalopez --format json     # Status field id and option ids
gh project item-edit --id <ITEM_ID> --project-id PVT_kwHOAE0fRc4Blqiu \
  --field-id <STATUS_FIELD_ID> --single-select-option-id <OPTION_ID>
```

### Closing a task

Record what was decided or learnt, so later runs improve (`docs/lessons/README.md` has the templates, the index and how an entry is promoted to a checklist line, a script, a CI check, a skill, a command, an agent, a hook, a mode, an MCP server or a plugin).

1. Ask: did the owner decide anything, did a tool, CI or review surprise us, or did a sweep pick a number? If not, the final message says "Lessons: none".
2. For each yes, copy a template to `docs/lessons/YYYY-MM-DD-<slug>.md` (at most 3 per task, 25 lines each), fill in the evidence with the exact error text, file:line or link, and set `promote:`. A repeat is promoted now or gets a ticket.
3. Add the rows to the index in `docs/lessons/README.md`, copy an owner decision into the file that governs it (CLAUDE.md, the GDD, PLAN), and commit the entries in the task's PR.
4. In the PR body add a "Lessons and decisions" section listing each path with its rule line, comment the same list on the ticket, and end the final message with "Lessons:" and the paths.
5. Balance sweeps are run by a Haiku agent with a Sonnet agent helping to read the results; design memos and deep reviews use Opus.

## Naming

Use the GDD's names in code-facing content and the UI (display names only; ids are lowerCamelCase keys). The foe and tower ids are already the GDD's; the Guard Tent's id arrives with it in Phase 7:

| Prototype or ported id | Papercraft Kingdom Defense |
| --- | --- |
| scout / walker / tank / boss (`scamp`, `raider`, `ironclad`, `warlord`) | Scrap Goblin / Corrugated Orc / Corrugated Orc / Cardboard Golem (ids `scrapGoblin`, `corrugatedOrc`, `cardboardGolem`) |
| (new) | Razor Moth (flying), Ink Shaman (support) |
| `ballista`, `catapult` | The Spool Guard (`spoolGuard`), The Thimble Mortar (`thimbleMortar`) |
| `frostSpire`, `stormSpire` | The Prism Spire (`prismSpire`), with specs Cryo-Origami Spire and Blot Singularity |
| (new) | The Guard Tent (`guardTent`) |
| gold / lives (`gold`, `lives`) | Buttons / Heartstone health (`buttons`, `heartstone_health`, `START_BUTTONS`, `START_HEARTSTONE_HEALTH`); Golden Staples between runs |
| Heartstone, kingdom | the Heartstone, the objective at the end of the road (it returns in the 2026-10-12 GDD; no "kingdom" in code, UI or tests) |
