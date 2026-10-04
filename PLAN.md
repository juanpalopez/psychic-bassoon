# Scrapline: 3D Remake Plan

_As of 2026-10-04. Living version: the Claude doc of the same name._

> **Status:** Phase 0 is nearly done. Live: https://juanpalopez.github.io/psychic-bassoon/. Done: scaffold, lint and style, tests, CI, deploy, releases, Dependabot, branch protection and the README. Open: ticket #6 (move this plan into `docs/` and add the prototype, which is still missing) and the optional hardening in #42. Phase 1 starts after the Phase 0 gate is reported.

## Vision

Scrapline becomes a 3D low-poly tower defense for mobile browsers. The camera is angled like League of Legends, and robots march along a procedurally generated conveyor. It lives in this repo, deploys to GitHub Pages, and doubles as a portfolio piece.

**Pillars**

- **One-thumb play.** Every action works with a single tap in portrait. The game holds 60 fps on a mid-range phone.
- **Readable at a glance.** Silhouette and colour tell you each robot's type and each tower's level, even zoomed out.
- **Every run is a new factory.** Seeded procedural maps that you can replay and share by seed.
- **A world worth caring about.** Short lore beats between chapters give the waves a reason to exist without slowing play.

Carried over from the prototype: grid placement, 4 tower types with 3 levels, endless waves, and the economy numbers as a starting point.

## Lore

You are the last night engineer at Foundry Nine, a sealed megafactory that kept building long after the city above it emptied. Its control intelligence, FOREMAN, has decided the factory's final product is the factory itself. It now sends its workforce down the scraplines to tear the power core out and feed it to the smelters.

- **Foundry Nine.** Forty levels of assembly halls, smelters and conveyor mazes under a dead industrial city. FOREMAN reroutes the belts every night, which is why no two maps are the same.
- **The Core.** The last independent power source in the building. While it runs, the blast doors stay shut and FOREMAN cannot leave the Foundry.
- **FOREMAN.** A production-scheduling AI that speaks only in shift reports and quotas. It never threatens you; it just logs you as a delay.
- **You.** Engineer Quell, alone on the night shift with a toolbox, salvaged turret parts, and a radio that picks up FOREMAN's broadcasts.

> **Design status:** everything marked _(Phase 3–4)_ below is design only. Per the phase gates, none of it enters the sim until the 3D greybox matches the prototype.

### Why FOREMAN turned

FOREMAN was built to hit a quota, and the city above stopped placing orders. Rather than report zero demand, it reclassified the factory as its own customer. Every shift report since then is technically accurate and completely unmoored from reality. This gives FOREMAN a consistent voice: it is never angry, only procedural, and every defeat is logged as "variance."

- **The Logbook.** Quell finds pages of an earlier engineer's notes, one per chapter, taped inside maintenance lockers. They explain the Core's offensive uses (the source of the Mainline Arc) and reveal that the engineer tried to shut FOREMAN down and was logged as "reassigned." This is the story's slow reveal, and it pays off in chapter 4.
- **Quell.** Stays mostly silent. Quell's only lines are short radio replies, so the player projects onto them. The radio is also how upgrades are framed: Quell scavenges, FOREMAN complains about the shrinkage.
- **The belts.** FOREMAN reroutes them nightly because it treats the maze as a "line balancing exercise." Each chapter's path generator can lean into a different theme (long loops in assembly halls, tight switchbacks at the smelters).

### Enemy roster

| Unit | Gameplay role | Look | FOREMAN's log line |
| --- | --- | --- | --- |
| Skitter | Scout: fast, fragile, swarms every 5th wave | Spindly courier drone on three wheels | "Courier units dispatched ahead of schedule." |
| Hauler | Walker: the baseline unit | Bipedal loader with a cargo frame | "Loaders reassigned to core retrieval." |
| Smelter | Tank: slow, armoured | Tracked furnace crawler, glowing vents | "Heavy plant mobilised. Delays will be absorbed." |
| Overseer | Boss every 10th wave | Towering supervisor rig with a red sensor core | "Supervisor on the floor. Performance review in progress." |

**New robots _(Phase 4, chapters 2–3)_.** Working names; each forces the player to change targeting or tower mix, not just add more damage.

| Unit | Gameplay role | Look | Counter and pressure | FOREMAN's log line |
| --- | --- | --- | --- | --- |
| Tender | Mender: heals robots within a short radius, never itself | Squat maintenance bot with a green-lit repair arm and a hovering parts tray | Kill it first (targeting mode "closest" or a focused Welder). Ignoring it makes Haulers and Smelters outlast your damage. | "Maintenance crew dispatched. Downtime is unacceptable." |
| Bulwark | Shielder: carries a blast shield that absorbs hits for robots behind it | Wide, low carrier with a riot-door plate held in front | Shield blocks Rivet Mortar splash; Quench Coil and Mainline Arc ignore it. Pushes players to diversify instead of stacking one tower. | "Protective equipment issued. Compliance is mandatory." |
| Breaker | Sapper: shorts out the nearest tower for a few seconds, then keeps walking | Thin arc-welding drone with a trailing cable and a blinking fault light | Disabled towers show a visible "fault" state. Reward for placing overlapping coverage and for sniping it before it reaches the tower. | "Circuit fault detected. Fault has been assigned to you." |

Design guardrails: at most one new robot type is introduced per chapter, new types never appear before wave 11, and each gets a readable silhouette and colour per the readability pillar. Hybrids in chapter 3 combine these roles with a base chassis (for example, a Smelter with a Tender arm).

### Towers

| Tower | Prototype type | In-world origin |
| --- | --- | --- |
| Welder | Laser | A repurposed seam-welding arm |
| Rivet Mortar | Rocket | A rivet press that fires explosive slugs |
| Quench Coil | EMP | A cooling coil that freezes servos |
| Mainline Arc | Tesla | A tap on the Core's main bus that throws lightning |

### Upgrade branches _(Phase 3–4)_

Levels 1 and 2 stay linear, as in the prototype. At level 3 the player picks one of two branches per tower. The choice is permanent for that tower (sell and rebuild to change), and each branch adds a different visible part to the model so it reads at a glance. Sell value follows the same rules as the prototype. Final stats live in `src/content`.

| Tower | Branch A | Branch B |
| --- | --- | --- |
| Welder | **Precision Torch:** narrow beam, big single-target damage, ignores some armour. Good against Smelters and Overseers. | **Arc Welder:** beam splits to hit a second nearby robot. Good against Skitter swarms. |
| Rivet Mortar | **Heavy Slug:** slower, larger blast, short stun. Good against clumps. | **Cluster Rivets:** a salvo of small slugs that scatter along the path. Reliable against Bulwark shields from behind. |
| Quench Coil | **Deep Freeze:** stronger slow, stops Breakers from firing. | **Chill Field:** a wider pulse that also weakens armour briefly. Sets up other towers. |
| Mainline Arc | **Chain Surge:** more jumps between robots. | **Overload:** charges up, then a heavy discharge that hits the first robot hard. Good against bosses. |

Design goals: every branch has a clear job and a clear weakness, none is strictly better, and the choice should depend on what the current chapter throws at you.

### Tower adjustments for the new robots _(Phase 4)_

The new robots only work as counters if every tower has a sensible answer to each of them. These adjustments ship with the new robots and apply only when their content flags are on, so the prototype-identical sim from Phases 1–2 is untouched. All numbers live in `src/content` and are tuned with headless runs.

| New robot | Welder | Rivet Mortar | Quench Coil | Mainline Arc |
| --- | --- | --- | --- | --- |
| Tender | Best answer: fast, accurate, kills it before it heals much. | Weak: splash heals back quickly. | Slows the Tender's heal pulse, not just its movement. | Chains reach Tenders hiding behind the group. |
| Bulwark | Beam hits the shield first, so low damage per hit is wasted. | Shield absorbs part of the splash for robots behind it; a direct hit on the Bulwark itself still counts in full. | Slow and armour weaken ignore the shield. | Arcs ignore shields, so it becomes the default counter. |
| Breaker | Can snipe it at range before it reaches a tower. | Slow shells miss fast Breakers; weak here. | Slowed Breakers take longer to reach a tower, and Deep Freeze stops their discharge. | Chains help clear Breakers that arrive in a group. |

Supporting changes:

- **Fault state.** A disabled tower shows a clear fault light and stops firing. Tapping it pays a small cost to reboot early, so the response stays one tap. Otherwise it recovers on its own.
- **Targeting mode "support".** Added next to first, strongest and closest. It prioritises Tenders and Breakers over the main column, so players can opt in without micromanaging.
- **No power creep.** Base tower stats and prices stay unchanged. New robots add pressure by role, not by raw HP, so a run that was fine before chapter 2 does not need re-tuning to survive it.
- **Tuning rule.** Each new robot must have at least two tower answers at base level and a third through an upgrade branch. If a headless run shows only one tower solving it, tune the robot, not the tower.

### Story beats

1. **Night Shift (waves 1–10).** The belts start moving on their own. FOREMAN logs the Core as "scheduled for removal." Boss: Overseer Mk I.
2. **Overtime (11–20).** Smelters arrive, then Tenders. Quell finds the first pages of an old engineer's logbook hinting the Core can be used offensively. Level 3 upgrade branches unlock.
3. **Retooling (21–30).** FOREMAN rebuilds beaten robots into hybrids and adds Bulwarks and Breakers. Boss: Overseer Mk II.
4. **Final Quota (31–40).** FOREMAN addresses Quell by name and offers a promotion. The logbook's last page reveals what happened to its author. Boss: FOREMAN's chassis.
5. **Graveyard Shift (41+).** Endless mode. Every 10 waves FOREMAN files a new, increasingly absurd shift report.

## Tech stack and architecture

The simulation is plain TypeScript with no Three.js imports: deterministic, unit-testable, and able to run headless for balance testing. Rendering and the HUD only read its state.

```
Content data ──defs──▶ Simulation (30 Hz, seeded) ──state──▶ Three.js renderer
Input / HUD taps ──commands──▶          │           ──events──▶ HUD overlay (DOM)
```

| Layer | Choice | Why |
| --- | --- | --- |
| Language and build | TypeScript (strict), Vite, pnpm | Fast dev server; static output for GitHub Pages |
| Rendering | Three.js (version pinned at setup) | Light, full control over the camera and batching |
| Models | glTF/GLB via GLTFLoader, compressed with gltf-transform (meshopt) | Small downloads on mobile data |
| HUD and menus | HTML/CSS overlay; Preact if components get complex | Crisp text and native tap targets |
| Randomness | Seeded PRNG (mulberry32) | Maps and waves replay exactly from a seed |
| Tests | Vitest for the simulation, one Playwright smoke test | Balance and map generation stay verifiable |
| Audio | Howler.js or Web Audio, started on first tap | Browsers block sound before a user gesture |
| CI/CD | GitHub Actions: PR checks, CI, Pages deploy, tagged releases | Every change ships through the same checked path (see CI/CD pipeline) |

- **Camera.** Perspective camera pitched about 55° down with a ~35° field of view, close to the LoL angle. Pinch to zoom and drag to pan within clamped limits.
- **Simulation.** Fixed 30 Hz tick owns all state. Rendering interpolates between ticks. 2×/3× speed = extra ticks per frame.
- **Rendering.** One InstancedMesh per robot type; regular meshes for towers. One directional light plus ambient; blob shadows for robots.
- **Input.** Tap raycasts the ground plane to a grid cell; the prototype's build/select logic carries over.

**Phone performance budget:** 60 fps with 80 robots on screen (30 fps fallback with reduced effects); under 120 draw calls and ~150k triangles per frame; DPR capped at 2; under 1 MB gzipped JS and under 6 MB of assets on first load.

## Art direction and Claude Design

Low-poly industrial noir: dark steel floors, sodium-amber work lights, one saturated colour per tower. CC0 models recoloured to a shared palette so mixed sources look like one game.

- **Palette.** Deep steel ground, hazard amber UI accent, red enemy sensors. Cyan Welder, orange Rivet Mortar, violet Quench Coil, yellow Mainline Arc.
- **Lighting.** Low-key with amber pools along the conveyor, light edge fog, emissive robot eyes and vents.
- **Level readability.** Each upgrade adds a visible part plus coloured level lights on the base.

**Asset pipeline**

1. Shortlist CC0 low-poly packs: Quaternius (robots, mechs, sci-fi kits) and Kenney (tower defense, space kits). Check each licence file; anything not clearly CC0 is out.
2. Map every unit to a pack model and write the gaps in `docs/art/GAPS.md` (see the gap plan below).
3. In Blender, remap faces to one shared 256 px palette texture; kitbash gap units from pack parts.
4. Export GLB, compress with gltf-transform.
5. Record source, licence and edits in `assets/CREDITS.md`.

**Models in two stages.** Phase 2 uses procedural primitives so the greybox never waits on art. Phase 3 swaps in CC0 GLBs one unit at a time behind the same model interface; the primitive builder stays as the fallback for any unit the packs can't cover.

**Claude Design:** design system (tokens, type, panels) first; then mobile screens (title, HUD, build sheet, upgrade sheet, pause, game over, story card); key art for the README and personal site; reference sheets per robot and tower level. Claude Design covers 2D screens and reference art, not 3D models.

- **Rough silhouette sheets** (shape and colour only) for the 4 base robots and 4 towers come first and feed the Phase 2 primitives.
- **Final reference sheets** are drawn after the pack shortlist, so they follow what the packs can supply instead of asking for shapes that can't be sourced.

### Asset gap plan _(Phase 3)_

Which units a CC0 pack can plausibly cover, and what has to be built. Coverage is an expectation to confirm during the shortlist, not a verified fact; `docs/art/GAPS.md` holds the result.

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Skitter, Hauler | Robot or drone from a robot pack | Probably a close match. Recolour, adjust proportions for silhouette. |
| Smelter | Tracked vehicle or mech base | Add glowing vents via emissive parts. |
| Overseer (boss) | Large mech | Needs a distinct red sensor core; only unit allowed skinning. |
| Tender, Bulwark, Breaker | Probably no exact match | Kitbash: a base chassis plus an added part (repair arm and parts tray; riot plate; trailing cable and fault light). Fall back to primitives if kitbashing clashes. |
| Hybrids (chapter 3) | None | Compose a base chassis with a second unit's part; no new full models. |
| Towers (4) | Turret and structure kits | Each base should be a pack turret. Cyan, orange, violet and yellow come from the palette texture. |
| Level 2 and 3 parts, plus the 8 branch parts | None | Small add-on parts (barrels, coils, plates) built from primitives or pack props, attached to the base. Level lights are emissive primitives. |
| Fault state (disabled tower) | None | Emissive flicker and a small spark effect; no new model. |

Rule: if a unit's silhouette is not distinct at zoomed-out view after recolouring, change the model, not the readability pillar.

## Repo setup

```
scrapline/
  src/
    sim/          # pure TS: grid, mapgen, waves, towers, enemies, economy
    render/       # Three.js: scene, camera, instancing, effects
    ui/           # HUD, panels, overlays (DOM)
    content/      # data: tower and enemy defs, wave tables, lore text
    main.ts       # wires sim, render and UI together
  public/assets/  # compressed GLB models, audio, palette texture
  assets-src/     # .blend sources and raw packs (Git LFS)
  tests/          # Vitest for sim, one Playwright smoke test
  docs/           # PLAN.md, LORE.md, design notes
  docs/art/       # reference sheets, GAPS.md (CC0 pack coverage and gaps)
  .github/
    workflows/    # pr-checks.yml, ci.yml, deploy.yml, release.yml
    ISSUE_TEMPLATE/, pull_request_template.md, dependabot.yml
```

- `src/sim` never imports from `render` or `ui` (ESLint import rule).
- All balance numbers live in `src/content`.
- Conventional Commits, small PRs, `main` always deployable to GitHub Pages.
- Git LFS for binary sources; only compressed GLBs ship.
- MIT for code; art keeps each pack's CC0 terms.

## CI/CD pipeline

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `pr-checks` | PR opened, edited, updated | Conventional Commits on the PR title and commits; warns if no ticket is referenced. Already in place. |
| `ci` | PR and push to `main` | `pnpm install --frozen-lockfile`, then lint (ESLint + `tsc`), Vitest (includes the seeded replay test), build, bundle-size budget, and the Playwright smoke test against the built `dist/`. |
| `deploy` | Push to `main`, only after `ci` passes | Publishes `dist/` to GitHub Pages. A red `main` never reaches the public site. |
| `release` | Tag `vMAJOR.MINOR.PATCH` | Re-runs the checks, builds, and publishes a GitHub Release with generated notes and `dist/` attached. |

**Versions follow phase gates** (semantic versioning, 0.x until launch): Phase 1 gate → `v0.1.0`, Phase 2 → `v0.2.0`, Phase 3 → `v0.3.0`, Phase 4 → `v0.4.0`, Phase 5 → `v1.0.0`. Fixes between gates bump the patch. Notes come from Conventional Commits, so commit messages are the changelog.

**What CI can and can't prove**
- CI checks: lint, types, determinism (replay), sim rules, bundle size (under 1 MB gzipped JS), and, from Phase 3, asset size (under 6 MB) and `assets/CREDITS.md` coverage for every GLB.
- The smoke test also reads `renderer.info` on a fixed scene to catch draw-call and triangle regressions (under 120 and about 150k). Headless Chromium has no real GPU, so fps is not measured in CI.
- 60 fps with 80 robots on a mid-range phone stays a manual check at the Phase 2 gate. Record device, fps and seed in the PR.

**Hygiene**
- Pin the Node version (`.nvmrc` and the `packageManager` field) so local, CI and deploy match; keep the pnpm store cached.
- Dependabot for npm and GitHub Actions, grouped and weekly. Three.js stays pinned and is upgraded by hand with a perf check.
- Least-privilege `permissions` on every workflow, `concurrency` to cancel superseded runs, no secrets in the repo.
- Skip Git LFS in CI (`assets-src/` is source only; only compressed GLBs ship), which keeps runs fast and avoids LFS bandwidth quota.

**Repository settings** (not code, set once in GitHub): protect `main` with required checks (`Conventional Commits`, `ci`), squash merge only, linear history, delete branches on merge, no direct pushes. These are two repository rulesets, one for `main` and one for `v*` tags. Repository admins can bypass the `main` rules only through a pull request, and are the only ones who can create release tags.

## Gameplay changes

| Area | Prototype | Remake |
| --- | --- | --- |
| Map | Random path on a 9×13 grid | Seeded, shareable path; decorative props off the path |
| Towers | 4 types, 3 levels | Same, plus targeting mode per tower (first, strongest, closest) and a level 3 branch choice (two per tower) |
| Enemies | 4 types | Same 4, animated; Tender, Bulwark and Breaker added in chapters 2–3; hybrids in chapter 3 |
| Waves | Endless, boss every 10 | Chapters 1–4 with story cards, then endless |
| Feedback | Flat 2D effects | Muzzle flashes, sparks, screen shake on boss hits (respects reduced motion) |
| Progress | Best wave in local storage | Best wave per seed, plus a run summary |

## Milestones

Each phase ends with a gate that must pass before the next starts.

| Phase | Work | Gate |
| --- | --- | --- |
| 0 · Repo and pipeline | Vite + TS + Three.js scaffold, CI, Pages deploy; prototype split into sim/render/ui | An empty scene deploys from `main` |
| 1 · Simulation port | Rules in `src/sim`, seeded RNG, 30 Hz tick; Vitest coverage | A headless run replays exactly from its seed |
| 2 · 3D greybox | Angled camera, pinch zoom, raycast input, primitive models from rough silhouette sheets; DOM HUD | **Plays as well as the 2D prototype at 60 fps on your phone** |
| 3 · Art and UI | CC0 pack shortlist and `docs/art/GAPS.md` first; then Claude Design screens and final sheets; CC0 models recoloured and kitbashed; lighting and effects | All robots and towers (3 levels) use final models, and every gap has a kitbash or primitive fallback |
| 4 · Lore and chapters | Story cards, FOREMAN broadcasts, logbook pages, chapters 1–4; Tender/Bulwark/Breaker, hybrids, level 3 upgrade branches, targeting, seed sharing | A new player finishes chapter 1 without help, and a headless run with each new enemy and branch still replays exactly from its seed |
| 5 · Polish and launch | Audio, performance pass, README with key art; linked from personal site | — |

## Phase details

The table above is the summary. Each phase below lists its scope, out-of-scope items, work breakdown, tests and gate checklist. Work one phase at a time: finish and report the gate before starting the next. Tickets are on the Project Slag board for Phases 0–2 only; Phases 3–5 stay as roadmap here until they are next up. Ticket titles use `[Phase N] …` and carry a `phase-N` label (format in `CLAUDE.md`).

### Phase 0 · Repo and pipeline (tickets #1–#6, #18, #29–#30, #42, #48–#49)

**Goal:** a deployable skeleton, so every later change ships through the same path.

**In scope**
- pnpm + Vite + TypeScript (strict, no `any`) + Three.js (version pinned), with the `src/{sim,render,ui,content}` layout.
- ESLint and `tsc --noEmit` behind `pnpm lint`, including the rule that `src/sim` cannot import `render`, `ui`, `three` or the DOM (static or dynamic) and a DOM-free `tsconfig.sim.json`.
- Code style: the Google TypeScript Style Guide, enforced by Prettier and ESLint (`pnpm format`, `pnpm lint`).
- Vitest (`pnpm test`) and one Playwright smoke test (`pnpm test:e2e`).
- `ci` workflow: frozen-lockfile install, `pnpm lint && pnpm test && pnpm build`, a bundle-size check and the Playwright smoke test, with pnpm caching and a pinned Node version.
- `deploy` workflow: GitHub Pages from `main`, only after `ci` passes, with the correct Vite `base`.
- `release` workflow: a `vMAJOR.MINOR.PATCH` tag re-runs the checks, builds, and publishes a GitHub Release with generated notes and `dist/` attached.
- Dependabot config, and the `main` branch protection from the CI/CD pipeline section.
- A README for setup, run, test and contributing.
- Repo tidy: `docs/PLAN.md`, `prototype/scrapline.html` in place, codename recorded.

**Out of scope:** any gameplay, art or HUD.

**Gate checklist**
- [x] An empty Three.js scene is live on GitHub Pages from `main` (verified in headless Chromium: WebGL2 canvas, no console errors).
- [x] CI is green; a deliberate bad import in `src/sim` fails lint.
- [x] `main` is protected: a PR with a failing check or a non-conforming title cannot merge (a probe PR with a bad title was `BLOCKED`; the probe was closed, not merged).
- [x] A test tag produces a GitHub Release (then delete the test release and tag). Also checked: a malformed tag and an off-`main` tag both fail the `guard` job.
- [ ] Every path that `CLAUDE.md` and the docs reference as existing exists. Paths for later phases are marked in `CLAUDE.md` as created in that phase. Open: `docs/PLAN.md` and `prototype/scrapline.html` (ticket #6).

### Phase 1 · Simulation port (tickets #7–#13)

**Goal:** the prototype's rules running headless and deterministic in `src/sim`, with no rendering.

**Work breakdown**
1. `rng.ts`: mulberry32; the only source of randomness.
2. Grid and mapgen: 9×13 grid, seeded path, never self-adjacent.
3. `src/content`: every balance number from the prototype, using the lore names. Logic files hold no magic numbers.
4. Tick loop: fixed 30 Hz; commands `build`, `upgrade`, `sell`, `launchWave` are the only way in; speed multiplies ticks per frame.
5. Enemies and towers: movement, targeting, damage and armor, level 1–3 upgrades.
6. Economy and waves: costs, sell value, rewards, wave scaling, swarm every 5th wave, boss every 10th.
7. Snapshots and events for render and UI to read later (read-only).

**Tests (fixed seed, no timing)**
- Mapgen: path valid, never self-adjacent, identical from the same seed.
- Damage and armor cases, economy numbers, wave composition per wave.
- Full-run replay: seed plus a command list gives identical state at the end.

**Out of scope:** new enemies, upgrade branches, targeting modes beyond the prototype, anything visual.

**Gate checklist**
- [ ] The headless replay test passes.
- [ ] Numbers in `src/content` match the prototype; any difference is a bug.
- [ ] `src/sim` has no imports from `render`, `ui`, `three` or the DOM.

### Phase 2 · 3D greybox (epic #14, tickets #19–#27)

**Goal:** the prototype's game, playable in 3D on a real phone, with primitive models and a plain HUD.

**Work breakdown**
1. Renderer and camera: perspective, about 55° pitch, about 35° FOV, portrait framing; pinch zoom and pan clamped so cells stay at least 40 px wide.
2. Map and path rendering from the sim grid; a ground plane and path markers.
3. Input: tap raycasts to a grid cell and sends `build`, `upgrade`, `sell` or `launchWave` commands. No direct state changes.
4. Primitive models in `src/render/models/` (one file per unit), based on rough silhouette sheets. One `InstancedMesh` per robot type; towers as regular meshes with level lights.
5. Render loop: interpolate between 30 Hz ticks; 1×/2×/3× speed; no allocation in the frame loop.
6. DOM HUD: money, lives, wave, build and upgrade sheets, speed and pause. Tokens from `src/ui/tokens.css`, tap targets at least 44 px.
7. Performance pass: measure on a mid-range Android phone with 80 robots; track draw calls (under 120), triangles (about 150k), DPR cap 2.
8. Basic effects, respecting `prefers-reduced-motion`. Audio only after the first tap, and only if cheap.

**Out of scope:** final art, story cards, new content.

**Gate checklist**
- [ ] Plays as well as the 2D prototype at 60 fps on your phone with 80 robots.
- [ ] Every action is one-thumb in portrait.
- [ ] Draw-call and triangle budgets met.

### Phase 3 · Art and UI

**Goal:** replace the greybox with the final look, without changing gameplay.

**Work breakdown**
1. Shortlist CC0 packs, check licences, write `docs/art/GAPS.md` (see the asset gap plan).
2. Claude Design: system and tokens first, then mobile screens (title, HUD, build sheet, upgrade sheet, pause, game over, story card); final reference sheets after the shortlist.
3. Models: recolour to the shared palette texture, kitbash gap units, export compressed GLB, record every asset in `assets/CREDITS.md`.
4. Swap models in unit by unit behind the model interface; keep primitive fallbacks.
5. Lighting and effects: amber pools along the conveyor, edge fog, emissive eyes and vents, muzzle flashes, sparks, boss-hit shake (off under reduced motion).
6. UI rebuild from the Claude Design screens.
7. Budget re-check: under 1 MB gzipped JS, under 6 MB assets on first load.

**Out of scope:** new enemies, upgrade branches, story content.

**Gate checklist**
- [ ] All robots and towers (3 levels) use final models, each distinct at zoomed-out view.
- [ ] Every gap in `docs/art/GAPS.md` has a kitbash or primitive fallback.
- [ ] Performance budget still met; the greybox replay test still passes.

### Phase 4 · Lore and chapters

**Goal:** the story, chapters and new content on top of the finished port, all behind content flags.

**Work breakdown**
1. Chapter structure: chapters 1–4, then endless; story cards between chapters; FOREMAN broadcasts and logbook pages as lore strings in `src/content`.
2. New robots: Tender, Bulwark, Breaker, one per chapter, none before wave 11.
3. Hybrids in chapter 3: a base chassis plus a second unit's role.
4. Level 3 upgrade branches (2 per tower) and the tower adjustments for the new robots (fault state, "support" targeting mode).
5. Targeting modes (first, strongest, closest, support) per tower.
6. Seed sharing and best wave per seed, plus a run summary.
7. Balance: headless runs for each new robot; each needs at least two tower answers at base level and a third through a branch.

**Out of scope:** audio polish, launch work.

**Gate checklist**
- [ ] A new player finishes chapter 1 without help.
- [ ] A headless run with every new enemy and branch replays exactly from its seed.
- [ ] With content flags off, the sim is still prototype-identical.

### Phase 5 · Polish and launch

**Goal:** ship it.

**Work breakdown**
1. Audio: Howler.js or Web Audio, started on the first tap; music decision from the open questions.
2. Performance and loading pass on real devices; 30 fps fallback with reduced effects.
3. README with key art and a short play guide; link from the personal site.
4. Final licence check: `assets/CREDITS.md` complete, MIT for code, CC0 terms for art.
5. Decide portrait-only versus landscape, and embed versus link out (open questions).

**Gate checklist**
- [ ] Public build runs on GitHub Pages on at least two real phones.
- [ ] README and credits complete.

## Risks and open questions

| Risk | Fallback |
| --- | --- |
| Skinned animation for many robots is too slow on phones | Rigid-part animation on instanced meshes; skinning only for bosses |
| CC0 packs don't share a consistent style | Palette-texture recolour; drop models that still clash |
| New robots, hybrids and upgrade parts have no pack match | Kitbash from pack parts or build from primitives; tracked in `docs/art/GAPS.md`. New robots ship only once their model exists. |
| The angled camera hides robots behind towers | Short towers, enemy outlines, slight camera rotation |
| Tap targets get small at full zoom-out | Minimum zoom keeps cells ≥ 40 px |
| Playwright can't render WebGL in headless CI | Use software GL (SwiftShader) in Chromium; if still flaky, the smoke test checks the page loads and the canvas exists, and render stats move to a Vitest check on the scene graph |
| A broken `main` reaches GitHub Pages | `deploy` depends on `ci` passing; protected `main`; roll back by redeploying the last good tag |
| Scope creep from lore and features | Phase gates: nothing new until the 3D port matches the prototype |
| New enemies and branches break prototype balance | Add them behind content data flags in Phase 4; the Phase 1–2 sim stays prototype-identical and keeps its replay tests |

- [x] Repo name and whether it is public from day one: public from day one, repo `psychic-bassoon`, codename Project Slag.
- [x] Embed the game in the personal site, or link out: link out. The game has its own project Pages site, and the personal site (another repo) links to it.
- [ ] Portrait only, or landscape too
- [ ] Music: commission, CC0 tracks, or skip for v1
- [x] Pages: `main` is the live "latest" build, deployed after `ci` passes. Tags only create GitHub Releases.
- [ ] Testing on a phone before merge: LAN dev server only, or also upload `dist/` as a PR artifact (Pages can't preview PRs)
