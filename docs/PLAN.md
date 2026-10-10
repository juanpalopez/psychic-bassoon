# Scrapline: 3D Remake Plan

Codename: **Project Slag**. The repo is `psychic-bassoon`; the game and its tracker board use Scrapline and Project Slag.

_Updated 2026-10-10: the game moves from Three.js to Godot. Living version: the Claude doc of the same name._

> **Status:** Phases 0 to 2 are complete in TypeScript and Three.js, and the web build is live at https://juanpalopez.github.io/psychic-bassoon/ (owner-tested on iPhone). On 2026-10-10 the owner decided to move the game to the **Godot engine** for more freedom (see [Engine decision](#engine-decision-godot)). The TypeScript sim, tests and prototype are the reference until the Godot sim reproduces them exactly. Next: Phase 3, the Godot foundation. Use `prototype/scrapline.html` and the TypeScript sim as the reference for rules and numbers.

## Vision

Scrapline becomes a 3D low-poly tower defense for mobile browsers, built with Godot. The camera is angled like League of Legends, and foes march along procedurally generated roads, which can branch. It lives in this repo, deploys to GitHub Pages first and to native apps later, and doubles as a portfolio piece.

**Pillars**

- **One-thumb play.** Every action works with a single tap, in landscape. The game holds 60 fps on a mid-range phone.
- **Readable at a glance.** Silhouette and colour tell you each foe's type and each tower's level, even zoomed out.
- **Every run is a new road.** Seeded procedural maps that you can replay and share by seed.
- **A world worth caring about.** Short lore beats between chapters give the waves a reason to exist without slowing play.

Carried over from the prototype: grid placement, 4 tower types with 3 levels, endless waves, and the economy numbers as a starting point.

## Lore

You are Castellan Quell, last warden of Greyhold Keep, the final stronghold of a kingdom that fell long ago. Beneath the keep burns the Heartstone, the last crystal of the old realm. While it shines, the gates hold and the Hollow cannot cross into the living lands. The Hollow King, a dead monarch who still issues edicts, is sending his warband down the King's Road to collect the Heartstone as unpaid tithe.

- **Greyhold Keep.** A crumbling border fortress on a crystal-veined hill. The Hollow King re-surveys the King's Road every night, which is why no two maps are the same.
- **The Heartstone.** The last independent light in the realm. While it burns, the gates stay shut and the Hollow King cannot ride out.
- **The Hollow King.** A dead king who speaks only in royal edicts, tithes and ledgers. He never threatens you; he enters you in the ledger of the fallen as arrears.
- **You.** Castellan Quell, alone on the night watch with a ballista, a few catapults and a handful of cut crystals.

> **Design status:** everything marked _(Phase 6–7)_ below is design only. Per the phase gates, none of it enters the sim until the Godot port reproduces the base game exactly (Phase 4).

### Why the Hollow King rides

The Hollow King ruled a kingdom whose treasury ran dry, and rather than admit it he declared the whole realm his debtor. Death did not end the audit. Every edict since is technically lawful and completely unmoored from reality. This gives the Hollow King a consistent voice: he is never angry, only procedural, and every defeat is entered as "tithe unpaid."

- **The Chronicle.** Quell finds pages of the previous castellan's journal, one per chapter, nailed inside watchtowers. They explain the Heartstone's offensive uses (the source of the Storm Spire) and reveal that the castellan tried to break the Hollow King's seal and was entered as "exiled." This is the story's slow reveal, and it pays off in chapter 4.
- **Quell.** Stays mostly silent. Quell's only lines are short replies to the herald's proclamations, so the player projects onto them. Upgrades are framed the same way: Quell scavenges, the Hollow King's herald complains about the shrinkage of his tithe.
- **The King's Road.** The Hollow King re-surveys it nightly because he treats the realm as a "boundary dispute." Each chapter's path generator can lean into a different theme (long loops through the meadows, tight switchbacks in the hills).

### Enemy roster

| Unit | Prototype type | Gameplay role | Look | The herald's proclamation |
| --- | --- | --- | --- | --- |
| Scamp | Scout | Fast, fragile, swarms every 5th wave | Small goblin runner with a stolen lantern | "Couriers dispatched ahead of the host." |
| Raider | Walker | The baseline unit | Hollow footman with a rusted axe and round shield | "The levy marches for the Heartstone." |
| Ironclad | Tank | Slow, armoured | Heavy knight in black plate, glowing eye slits | "The vanguard advances. Delays will be absorbed." |
| Warlord | Boss | Boss every 10th wave | Towering champion with a crown of iron spikes and a red-glowing core | "The Warlord is present. Audit in progress." |

**New foes _(Phase 7, chapters 2–3)_.** Working names; each forces the player to change targeting or tower mix, not just add more damage.

| Unit | Gameplay role | Look | Counter and pressure | The herald's proclamation |
| --- | --- | --- | --- | --- |
| Mender | Heals foes within a short radius, never itself | Hooded hedge-priest with a green-lit censer and a floating bandage tray | Kill it first (targeting mode "closest" or a focused Ballista). Ignoring it makes Raiders and Ironclads outlast your damage. | "Physicians dispatched. Loss of levy is unacceptable." |
| Shieldbearer | Carries a tower shield that absorbs hits for foes behind it | Wide, low brute holding a door-sized shield | The shield blocks Catapult splash; Frost Spire and Storm Spire ignore it. Pushes players to diversify instead of stacking one tower. | "Protective gear issued. Compliance is mandatory." |
| Saboteur | Shorts out the nearest tower for a few seconds, then keeps walking | Thin, hooded creeper with a smoking fuse and a blinking spark | Disabled towers show a visible "dimmed" state. Reward for overlapping coverage and for sniping it before it reaches a tower. | "A fault has been found in your defences. The fault has been assigned to you." |

Design guardrails: at most one new foe type is introduced per chapter, new types never appear before wave 11, and each gets a readable silhouette and colour per the readability pillar. Hybrids in chapter 3 combine these roles with a base body (for example, an Ironclad with a Mender's censer).

### Towers

| Tower | Prototype type | In-world origin |
| --- | --- | --- |
| Ballista | Laser | A siege crossbow that looses bolts in quick succession |
| Catapult | Rocket | A counterweight catapult that hurls cracked boulders |
| Frost Spire | EMP | A cut violet crystal on a stone spire that freezes everything near it |
| Storm Spire | Tesla | A yellow crystal tapped from the Heartstone's vein that throws lightning |

### Upgrade branches _(Phase 6–7)_

Levels 1 and 2 stay linear, as in the prototype. At level 3 the player picks one of two branches per tower. The choice is permanent for that tower (sell and rebuild to change), and each branch adds a different visible part to the model so it reads at a glance. Sell value follows the same rules as the prototype. Final stats live in the content data.

| Tower | Branch A | Branch B |
| --- | --- | --- |
| Ballista | **Piercing Bolt:** narrow bolt, big single-target damage, ignores some armour. Good against Ironclads and Warlords. | **Twin Bolt:** the bolt splits to hit a second nearby foe. Good against Scamp swarms. |
| Catapult | **Heavy Boulder:** slower, larger blast, short stun. Good against clumps. | **Cluster Stones:** a salvo of small stones that scatter along the road. Reliable against Shieldbearers from behind. |
| Frost Spire | **Deep Freeze:** stronger slow, stops Saboteurs from acting. | **Rime Field:** a wider pulse that also weakens armour briefly. Sets up other towers. |
| Storm Spire | **Chain Surge:** more jumps between foes. | **Thunderclap:** charges up, then a heavy discharge that hits the first foe hard. Good against bosses. |

Design goals: every branch has a clear job and a clear weakness, none is strictly better, and the choice should depend on what the current chapter throws at you.

### Tower adjustments for the new foes _(Phase 7)_

The new foes only work as counters if every tower has a sensible answer to each of them. These adjustments ship with the new foes and apply only when their content flags are on, so the base game as ported in Phase 4 is untouched. All numbers live in the content data and are tuned with headless runs.

| New foe | Ballista | Catapult | Frost Spire | Storm Spire |
| --- | --- | --- | --- | --- |
| Mender | Best answer: fast, accurate, kills it before it heals much. | Weak: splash heals back quickly. | Slows the Mender's heal pulse, not just its movement. | Chains reach Menders hiding behind the group. |
| Shieldbearer | Bolts hit the shield first, so low damage per hit is wasted. | The shield absorbs part of the splash for foes behind it; a direct hit on the Shieldbearer itself still counts in full. | Slow and armour weaken ignore the shield. | Lightning ignores shields, so it becomes the default counter. |
| Saboteur | Can snipe it at range before it reaches a tower. | Slow shells miss fast Saboteurs; weak here. | Slowed Saboteurs take longer to reach a tower, and Deep Freeze stops their sabotage. | Chains help clear Saboteurs that arrive in a group. |

Supporting changes:

- **Dimmed state.** A disabled tower shows a clear dimmed light and stops firing. Tapping it pays a small cost to relight early, so the response stays one tap. Otherwise it recovers on its own.
- **Targeting mode "support".** Added next to first, strongest and closest. It prioritises Menders and Saboteurs over the main column, so players can opt in without micromanaging.
- **No power creep.** Base tower stats and prices stay unchanged. New foes add pressure by role, not by raw HP, so a run that was fine before chapter 2 does not need re-tuning to survive it.
- **Tuning rule.** Each new foe must have at least two tower answers at base level and a third through an upgrade branch. If a headless run shows only one tower solving it, tune the foe, not the tower.

### Story beats

1. **First Watch (waves 1–10).** The King's Road begins to shift on its own. The herald proclaims the Heartstone "levied in kind." Boss: Warlord of the Vanguard.
2. **Second Watch (11–20).** Ironclads arrive, then Menders. Quell finds the first pages of the old castellan's Chronicle hinting the Heartstone can be used offensively. Level 3 upgrade branches unlock.
3. **Siege Season (21–30).** The Hollow King raises fallen foes again as hybrids and adds Shieldbearers and Saboteurs. Boss: Warlord of the Siege.
4. **Final Tithe (31–40).** The Hollow King addresses Quell by name and offers a pardon. The Chronicle's last page reveals what happened to its author. Boss: the Hollow King's champion.
5. **Long Night (41+).** Endless mode. Every 10 waves the herald reads a new, increasingly absurd edict.

## Engine decision: Godot

**Decision (owner, 2026-10-10):** build the game in Godot 4 instead of Three.js, for more freedom: a real editor for scenes, terrain, lighting and particles; animation and skeleton tools for foes; a UI toolkit; and a path to native iOS and Android apps. Web in a phone browser comes first, native later.

**What carries over:** the lore, naming, balance numbers, map and wave algorithms, all GLB assets and textures (including the owner's Blender models), the docs, tickets and review process.

**What is rewritten:** the simulation (TypeScript to GDScript), the renderer, the HUD, the tests and the build pipeline. The TypeScript game stays in the repo (tag `web-three-final`, folder `legacy/` once Godot replaces it) until the Godot build passes the same gates.

**How the port stays correct:** the TypeScript sim is the oracle. It exports JSON fixtures (maps, routes, wave lists, damage cases, replay fingerprints for many seeds). The GDScript sim must reproduce them exactly (GUT tests). Same seed, same commands, same result: the Phase 1 replay gate is repeated, not skipped.

**Known costs and risks, accepted:**
- **Web export is heavier.** The standard Godot 4 web engine is tens of MB uncompressed and several MB compressed (not yet measured here), against about 150 kB for the Three.js bundle. Startup is slower; show a loading screen. Measuring it on the owner's iPhone is a go/no-go gate in Phase 3.
- **iOS Safari.** Use the single-threaded web export (no `SharedArrayBuffer`, so GitHub Pages works without special headers) and the Compatibility renderer (WebGL2). Audio must start after the first tap. Memory limits are tight: test on the real phone early.
- **GDScript only for the web.** As of the pinned 4.x, C# does not export to web and GDExtension is not an option for the web build, so the sim is GDScript. At 30 ticks per second with about 100 entities this is fine; check it in Phase 4.
- **Determinism (value parity, not byte parity).** GDScript floats are 64-bit like JavaScript's, so results match if we use the same operations (`+ - * /`, `sqrt`, `floor`; never `randf`, `randi`, trig or engine `round`). Traps to port deliberately: `/` between two integers is integer division in GDScript (divide by a float such as `4294967296.0`); JavaScript's `Math.imul` and `>>>` need every value kept in [0, 2^32) and masked after each `*`, `+` and `^`; `Math.round` becomes `int(floor(x + 0.5))`. Fixtures store integers above 2^53 and fingerprints as hex strings and are compared with exact `==` (Godot's `JSON.parse` returns every number as a float).
- **Different tooling.** gdtoolkit for lint and format, GUT for tests, the Godot CLI for export. CI must download a pinned Godot and its export templates (cache them).

**Native later:** the same project exports to iOS and Android once the web build is solid; it needs signing, store accounts and review, so it is its own phase.

## Tech stack and architecture

The simulation is plain GDScript with no Node, scene or engine-singleton dependencies: deterministic, unit-testable, and able to run headless (`godot --headless`) for balance testing. Rendering and the HUD only read its state.

```
Content data ──defs──▶ Simulation (30 Hz, seeded) ──state──▶ Godot 3D scene (MultiMesh, camera)
Input / HUD taps ──commands──▶          │           ──events──▶ HUD (Control nodes)
```

| Layer | Choice | Why |
| --- | --- | --- |
| Engine | Godot 4.x (version pinned at setup), Compatibility renderer, single-threaded Web export | WebGL2 and no special server headers, so it runs from GitHub Pages and iOS Safari |
| Language | GDScript, typed everywhere | The script language that exports to web in the pinned 4.x |
| Simulation | `RefCounted` classes and plain data (Dictionary and typed arrays) under `sim/` | No scene tree, so tests and headless runs are fast and deterministic |
| Rendering | `MultiMeshInstance3D` per foe type, one scene per tower, a terrain scene built from the road tiles | Few draw calls on a phone |
| Models | glTF/GLB (the owner's Blender models, CC0 packs); the Godot importer | Assets carry over from the web build |
| HUD and menus | `Control` nodes with a Theme resource | Native layout, anchors and touch input; a Theme mirrors the Claude Design tokens |
| Randomness | Seeded PRNG (mulberry32 on masked 32-bit integers) | Maps and waves replay exactly from a seed, and match the TypeScript fixtures |
| Tests | GUT (Godot Unit Test) run headless; fixtures exported from the TypeScript sim; one Playwright smoke test on the exported build | Balance, maps and replays stay verifiable |
| Audio | Godot `AudioStreamPlayer`, started after the first tap on web | Browsers block sound before a user gesture |
| CI/CD | GitHub Actions: PR checks, gdlint and gdformat, GUT, Godot web export, size budget, Pages deploy, tagged releases | Every change ships through the same checked path (see CI/CD pipeline) |

- **Camera.** Perspective `Camera3D` pitched about 55° down with a ~35° field of view, landscape framing. Pinch to zoom and drag to pan within clamped limits.
- **Simulation.** Fixed 30 Hz tick (an accumulator in `_process`) owns all state. Rendering interpolates between ticks. 2×/3× speed means extra ticks per frame.
- **Rendering.** One `MultiMesh` per foe type; each tower is its own scene instance. Dusk lighting, fog for the edges.
- **Input.** A tap ray-casts the ground plane to a grid cell and sends a command. No direct state changes.
- **Orientation.** Landscape only: the web page shows a "turn your phone" prompt when upright (custom HTML shell).

**Phone performance budget:** 60 fps with 80 foes on screen (30 fps fallback with reduced effects); under 120 draw calls and about 150k triangles per frame; DPR capped at 2. Download budget to be set after the Phase 3 measurement (the web engine alone is several MB).

## Art direction and Claude Design

Low-poly storybook medieval: dark moss and slate ground, torch-amber light, stone towers with glowing crystals, one saturated colour per tower. CC0 models recoloured to a shared palette so mixed sources look like one game.

- **Palette.** Deep slate and moss ground, torch-amber UI accent, red glowing cores on the Hollow's champions. Cyan Ballista bolts, orange Catapult, violet Frost Spire, yellow Storm Spire.
- **Lighting.** Low-key with amber torch pools along the King's Road, light edge mist, glowing eyes and crystals.
- **Level readability.** Each upgrade adds a visible part plus coloured level lights on the base.

**Asset pipeline**

1. Shortlist CC0 low-poly packs: Kenney (Tower Defense Kit, Castle Kit, Fantasy Town Kit, Mini Dungeon) and Quaternius (fantasy, monsters and medieval packs). Check each licence file; anything not clearly CC0 is out.
2. Map every unit to a pack model and write the gaps in `docs/art/GAPS.md` (see the gap plan below).
3. In Blender, build or remap faces to one shared palette texture; kitbash gap units from pack parts.
4. Export GLB (meshopt compression is optional in Godot; the importer handles plain GLB).
5. Record source, licence and edits in `assets/CREDITS.md`.

**Models.** The Three.js build used procedural primitives and then Kenney CC0 GLBs while the owner generated original models with Claude and Blender (`assets-src/blender/`). In Godot the GLBs are imported as scenes; the owner's Blender models are the preferred source (towers done; foes, terrain and ambient props in progress), with Kenney pieces as placeholders.

**Claude Design:** design system (tokens, type, panels) first; then mobile screens (title, HUD, build sheet, upgrade sheet, pause, game over, story card); key art for the README and personal site; reference sheets per foe and tower level. Claude Design covers 2D screens and reference art, not 3D models.

- **Rough silhouette sheets** (shape and colour only) for the 4 base foes and 4 towers come first and brief the models.
- **Final reference sheets** are drawn after the pack shortlist, so they follow what the packs can supply instead of asking for shapes that can't be sourced.

### Asset gap plan _(Phase 6)_

Which units a CC0 pack can plausibly cover, and what has to be built. Coverage is an expectation to confirm during the shortlist, not a verified fact; `docs/art/GAPS.md` holds the result.

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Scamp, Raider, Ironclad, Warlord | Goblin, footman, knight and champion models from a fantasy or monster pack | Kenney's Tower Defense Kit only has UFO enemies, so foes need a second CC0 source; none is chosen yet. Recolour; Warlord needs a red glowing core and is the only unit allowed skinning. |
| Mender, Shieldbearer, Saboteur | Probably no exact match | Kitbash: a base body plus an added part (censer and floating tray; door-sized shield; smoking fuse). Fall back to primitives if kitbashing clashes. |
| Hybrids (chapter 3) | None | Compose a base body with a second unit's part; no new full models. |
| Towers (4) | Kenney Tower Defense Kit | Stone tower pieces, ballista, catapult and cannon weapons, and crystal pieces cover all four; recolour crystals to violet and yellow. |
| Terrain and road | Kenney Tower Defense Kit | Grass and dirt road tiles, spawn and end tiles, trees, rocks and crystals; snow variants for later chapters. |
| Level 2 and 3 parts, plus the 8 branch parts | None | Small add-on parts (barrels, coils, plates) built from primitives or pack props, attached to the base. Level lights are emissive primitives. |
| Dimmed state (disabled tower) | None | Emissive flicker and a small spark effect; no new model. |

Rule: if a unit's silhouette is not distinct at zoomed-out view after recolouring, change the model, not the readability pillar.

## Repo setup

```
scrapline/
  godot/                 # the Godot project (project.godot at its root)
    sim/                 # pure GDScript: grid, mapgen, routes, waves, towers, foes, economy
    content/             # data: tower and foe defs, wave tables, lore text (JSON or Resources)
    render/              # scenes and scripts: terrain, foes (MultiMesh), towers, camera, effects
    ui/                  # HUD scenes and the Theme resource
    assets/              # imported GLB models, audio, textures
    tests/               # GUT tests, including fixtures from the TypeScript sim
    export_presets.cfg   # web export preset (Godot reads it from the project root)
    web/                 # the custom HTML shell (landscape prompt, meta tags, loader)
  fixtures/              # JSON from the TypeScript sim: maps, waves, replays (the oracle)
  legacy/                # the TypeScript and Three.js game, until Godot replaces it
  assets-src/            # .blend sources and raw packs (Git LFS)
  docs/                  # PLAN.md, design notes; docs/art/ has GAPS.md
  .github/
    workflows/           # pr-checks.yml, ci.yml, deploy.yml, release.yml
    ISSUE_TEMPLATE/, pull_request_template.md, dependabot.yml
```

- `godot/sim` never touches the scene tree: no `Node`, no `get_tree`, no `Engine` or `Time` singletons, no `randf`/`randi`. A lint script enforces it.
- All balance numbers live in `godot/content`.
- Conventional Commits, small PRs, `main` always deployable to GitHub Pages.
- Git LFS for binary sources; only compressed GLBs ship.
- MIT for code; art keeps each pack's CC0 terms.

## CI/CD pipeline

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `pr-checks` | PR opened, edited, updated | Conventional Commits on the PR title and commits; warns if no ticket is referenced. Already in place. |
| `ci` | PR and push to `main` | Pinned Godot and export templates (cached); `gdformat --check` and `gdlint`; the sim purity lint; GUT headless (fixtures, replay); Web export; download-size budget; Playwright smoke test against the exported build. During the migration it also runs the legacy TypeScript checks. |
| `deploy` | Push to `main`, only after `ci` passes | Publishes to GitHub Pages. **Layout until the Phase 5 gate:** the TypeScript web build stays at the root URL and the Godot export is served under `/godot/`; at the gate the Godot export takes the root and the TypeScript build moves to `/legacy/` (or is dropped). A red `main` never reaches the public site. |
| `release` | Tag `vMAJOR.MINOR.PATCH` | Re-runs the checks, exports, and publishes a GitHub Release with generated notes and the build attached. |

**Versions follow phase gates** (semantic versioning, 0.x until launch). No release tags exist yet (the TypeScript phases were never tagged): the first tag, `v0.1.0`, is cut at the Phase 3 gate and each later gate bumps the minor version. The tag `web-three-final` marks the last Three.js web build and is created at the Phase 3 gate, before any Godot content is deployed to the root. Notes come from Conventional Commits, so commit messages are the changelog.

**What CI can and can't prove**
- CI checks: lint, formatting, determinism (replay against the TypeScript fixtures), sim rules, export size, `assets/CREDITS.md` coverage for every GLB.
- Headless Chromium has no real GPU, so fps is not measured in CI. The Godot web build can report draw calls and frame time through a debug overlay that the smoke test reads on a fixed scene.
- 60 fps with 80 foes on a mid-range phone stays a manual check at the Phase 5 gate. Record device, fps and seed in the PR.

**Hygiene**
- Pin the Godot version and export templates (`.godot-version`), so local, CI and deploy match; cache the templates.
- Dependabot for GitHub Actions. Godot is upgraded by hand with a perf check.
- Least-privilege `permissions` on every workflow, `concurrency` to cancel superseded runs, no secrets in the repo.
- Skip Git LFS in CI (`assets-src/` is source only; only compressed GLBs ship).

**Repository settings** (not code, set once in GitHub): protect `main` with required checks (`Conventional Commits`, `ci`), squash merge only, linear history, delete branches on merge, no direct pushes. These are two repository rulesets, one for `main` and one for `v*` tags. Repository admins can bypass the `main` rules only through a pull request, and are the only ones who can create release tags.

## Gameplay changes

| Area | Prototype | Remake |
| --- | --- | --- |
| Map | Random path on a 9×13 grid | Seeded, shareable map with one main road and often a detour (two routes from spawn to Heartstone); decorative props off the road. Drawn in landscape. |
| Towers | 4 types, 3 levels | Same, plus targeting mode per tower (first, strongest, closest) and a level 3 branch choice (two per tower) |
| Enemies | 4 types | Same 4, animated; Mender, Shieldbearer and Saboteur added in chapters 2–3; hybrids in chapter 3 |
| Waves | Endless, boss every 10 | Chapters 1–4 with story cards, then endless |
| Feedback | Flat 2D effects | Muzzle flashes, sparks, screen shake on boss hits (respects reduced motion) |
| Progress | Best wave in local storage | Best wave per seed, plus a run summary |

## Milestones

**Ticket labels.** The board's old labels `phase-3` (Art and UI), `phase-4` (Lore and chapters) and `phase-5` (Polish and launch) map to the new phases 6, 7 and 8; new labels `phase-6` to `phase-8` are added and the old art tickets (#89 to #97) are relabelled `phase-6`. The Three.js terrain ticket #108 is closed as done in TypeScript; the Godot terrain is part of Phase 5. New Godot tickets use `phase-3` onward with the new meaning from the day the move is merged.

Each phase ends with a gate that must pass before the next starts. Phases 0 to 2 were built in TypeScript and Three.js and are complete; the Godot track starts at Phase 3.

| Phase | Work | Gate |
| --- | --- | --- |
| 0 · Repo and pipeline (done) | Vite + TS + Three.js scaffold, CI, Pages deploy | An empty scene deploys from `main` |
| 1 · Simulation port, TypeScript (done) | Rules in `src/sim`, seeded RNG, 30 Hz tick; Vitest coverage | A headless run replays exactly from its seed |
| 2 · 3D greybox, Three.js (done) | Angled camera, picking, models, DOM HUD, landscape | Plays as well as the 2D prototype on a phone (owner-tested on iPhone) |
| 3 · Godot foundation | Godot project, pinned version, web export (single-thread), CI (gdlint, gdformat, GUT, export, size), Pages deploy, fixtures exported from the TypeScript sim | An empty Godot scene deploys from `main` and loads on the owner's iPhone Safari; download size measured and budgeted |
| 4 · Sim port to GDScript | PRNG, map generation with routes, game, commands, tick, combat, waves, economy, headless run | **The GDScript sim reproduces every TypeScript fixture exactly** (maps, routes, waves, replays) |
| 5 · Play in Godot | Terrain from GLB tiles, MultiMesh foes, towers, camera, picking, effects, Control-node HUD, landscape prompt, audio on first tap | **Plays as well as the TypeScript web build at 60 fps on the owner's phone with 80 foes**; then the Three.js code moves to `legacy/` |
| 6 · Art and ambience | The owner's Blender foes, towers, terrain and ambient props; Claude Design screens and Theme; lighting, fog, torches, effects | All foes and towers (3 levels) use final models; every gap in `docs/art/GAPS.md` has a fallback |
| 7 · Lore and chapters | Story cards, herald proclamations, Chronicle pages, chapters 1–4; Mender/Shieldbearer/Saboteur, hybrids, level 3 branches, targeting, seed sharing | A new player finishes chapter 1 without help, and a headless run with each new foe and branch replays exactly from its seed |
| 8 · Polish, launch, native | Audio, performance pass, README with key art; linked from the personal site; iOS and Android export | Public web build on two real phones; native builds on one device each |

## Phase details

### Phases 0 to 2 · TypeScript and Three.js: complete

Built and merged: the repo, CI/CD and protected `main` (Phase 0); the seeded, deterministic simulation with maps, branching routes, waves, combat, economy and a replay test (Phase 1); the 3D greybox with camera, picking, models, effects, HUD, landscape layout, GLB pipeline, Kenney and Blender models (Phase 2 and early Phase 3 work). Their tickets are closed on the board. The code is the reference for the port.

### Phase 3 · Godot foundation

**Goal:** an empty Godot project that builds, tests and deploys through the same checked pipeline, and proves the web export runs on the owner's iPhone.

**Work breakdown**
1. Add `godot/` with a pinned Godot 4 version, the Compatibility renderer and a single-threaded Web export preset; a custom HTML shell (landscape prompt, meta tags, loading screen).
2. CI: install the pinned Godot and templates (cached), `gdformat --check`, `gdlint`, GUT, the sim-purity lint, export, size budget, Playwright smoke on the export.
3. Deploy the export to GitHub Pages from `main` under `/godot/`; the TypeScript build stays at the root until the Phase 5 gate (see the Pages layout in CI/CD). Tag `web-three-final`.
4. Export fixtures from the TypeScript sim into `fixtures/` (maps and routes for many seeds, wave lists, damage cases, replay fingerprints) with a script and a test that regenerates and compares them.
5. Measure on the iPhone: download size, start time, a stub scene with 80 animated instances; set the budgets.

**Out of scope:** any gameplay.

**Gate checklist**
- [ ] An empty Godot scene deploys from `main` and loads on the owner's iPhone Safari.
- [ ] CI runs lint, GUT and the export, and a red check blocks the deploy.
- [ ] Fixtures exist and the TypeScript tests regenerate them identically.
- [ ] **Go/no-go:** on the owner's iPhone Safari the export's download size, start time, memory and an 80-instance stub scene are within the budget set here. If not, stop and take the fallback in Risks (keep Three.js for web, Godot for native only) before any Phase 4 work.

### Phase 4 · Sim port to GDScript

**Goal:** the whole simulation in GDScript, byte-for-byte equal to the TypeScript oracle.

**Work breakdown** (test-first, one context at a time)
1. PRNG (mulberry32 and `deriveRng`) on masked 32-bit integers; golden values from the fixtures.
2. Map generation with the main road, the detour and tile data; routes and positions.
3. Game state, commands and the 30 Hz tick; the command queue and rejection events.
4. Combat: movement, targeting across routes, damage and armor, the four towers' behaviour, shells.
5. Waves and economy: composition, spawning, route choice, bonuses.
6. Replay: the scripted bot and the fingerprint, compared with the TypeScript fingerprints for many seeds; a headless CLI (`godot --headless`) that prints the map and wave log.

**Gate checklist**
- [ ] Every fixture matches exactly (maps, routes, waves, replay fingerprints).
- [ ] The sim imports nothing from the scene tree (lint).
- [ ] A 12-minute headless run finishes within a time budget on CI.

### Phase 5 · Play in Godot

**Goal:** the game playable on the phone in Godot, at least as good as the web build.

**Work breakdown**
1. Terrain and road from the GLB tiles (straight, corner, end, T), scenery ring, spawn and Heartstone, dusk lighting and fog.
2. `MultiMesh` foes with interpolation, towers with levels, selection highlight and range ring.
3. Camera: landscape framing, pinch, pan, clamps; tap picking to a cell.
4. Control-node HUD: gold, lives, wave, build sheet, tower sheet, speed, pause, next-wave popup, auto-start, game over, landscape prompt.
5. Effects (beams, arcs, rings, sparks, shells), reduced motion, audio after the first tap.
6. Performance pass on the phone: 80 foes at 60 fps within the draw-call and triangle budget.

**Gate checklist**
- [ ] Plays as well as the TypeScript web build at 60 fps on the owner's phone with 80 foes.
- [ ] Every action is reachable in landscape; tap targets at least 44 px.
- [ ] The replay gate still passes. The Three.js code moves to `legacy/`.

### Phase 6 · Art and ambience

**Goal:** the final look, without changing gameplay.

**Work breakdown**
1. The owner's Blender models: towers (done), foes, terrain and ambient props; record each in `assets/CREDITS.md`.
2. Claude Design: system and tokens first, then mobile screens; build the Godot Theme from them.
3. Foe animation (skeletons or part animation); torches, mist, glow, crystals, particles.
4. Budget re-check.

**Gate checklist**
- [ ] All foes and towers (3 levels) use final models, each distinct at zoomed-out view.
- [ ] Every gap in `docs/art/GAPS.md` has a fallback.
- [ ] Performance budget still met; the replay gate still passes.

### Phase 7 · Lore and chapters

**Goal:** the story, chapters and new content on top of the finished port, all behind content flags.

**Work breakdown**
1. Chapter structure: chapters 1–4, then endless; story cards; herald proclamations and Chronicle pages as lore strings in `godot/content`.
2. New foes: Mender, Shieldbearer, Saboteur, one per chapter, none before wave 11.
3. Hybrids in chapter 3: a base body plus a second unit's role.
4. Level 3 upgrade branches (2 per tower) and the tower adjustments for the new foes (dimmed state, "support" targeting).
5. Targeting modes (first, strongest, closest, support) per tower.
6. Seed sharing and best wave per seed, plus a run summary.
7. Balance: headless runs for each new foe; each needs at least two tower answers at base level and a third through a branch.

**Gate checklist**
- [ ] A new player finishes chapter 1 without help.
- [ ] A headless run with every new foe and branch replays exactly from its seed.
- [ ] With content flags off, the sim is still identical to the Phase 4 fixtures.

### Phase 8 · Polish, launch, native

**Goal:** ship it, then take it native.

**Work breakdown**
1. Audio and music (decision from the open questions).
2. Performance and loading pass on real devices; 30 fps fallback with reduced effects.
3. README with key art and a short play guide; link from the personal site.
4. Final licence check: `assets/CREDITS.md` complete, MIT for code, CC0 terms for art.
5. iOS and Android export: signing, store accounts, input and safe areas, store listing.

**Gate checklist**
- [ ] Public web build runs on GitHub Pages on at least two real phones.
- [ ] README and credits complete.
- [ ] Native builds run on one iPhone and one Android phone.

## Risks and open questions

| Risk | Fallback |
| --- | --- |
| The Godot web build is too heavy or slow to start on a phone | Measure in Phase 3 before porting; trim export (disable unused modules with a custom build), lazy-load assets, loading screen. If it is still too heavy, fall back to the Three.js build for web and use Godot for native only. |
| iOS Safari limits (memory, audio, no threads) break the export | Single-threaded export, Compatibility renderer, test on the real phone every phase; keep the TypeScript web build live until Phase 5 passes |
| The GDScript sim drifts from the TypeScript oracle | Fixtures from the TypeScript sim and exact-match GUT tests; the TypeScript sim is frozen once the fixtures exist; it changes only for a bug, with the fixtures regenerated and the Godot sim updated in the same PR |
| Floating-point or integer differences (integer division, 32-bit wrap, rounding) | Use only `+ - * /`, `sqrt`, `floor`; divide by floats; mask integers to 32 bits after every operation; `int(floor(x + 0.5))` for `Math.round`; golden-value tests for the PRNG and `deriveRng`; hex-string fixtures compared with `==` |
| The DOM HUD is lost (screen readers, text scaling, crisp text, `prefers-reduced-motion`) | Control nodes with a Theme and large text; read reduced motion through a small `JavaScriptBridge` call in the web shell; accept the accessibility loss and record it |
| Part animation and skeletons fight `MultiMesh` (each part or material is another draw call; skinned meshes cannot use MultiMesh) | One MultiMesh per foe type and part, count draw calls in the Phase 5 gate; bake animation into vertex shaders or use a few skinned bosses only |
| The TypeScript tests and smoke test are forgotten after `legacy/` | The Vitest suite keeps running in CI while `src/` exists; fixtures stay in CI forever |
| Skinned animation for many foes is too slow on phones | Part animation on `MultiMesh` instances; skeletons only for bosses |
| CC0 packs don't share a consistent style | Prefer the owner's Blender models; palette-texture recolour; drop models that still clash |
| The angled camera hides foes behind towers | Short towers, outlines, slight camera rotation |
| Tap targets get small at full zoom-out | Minimum zoom keeps cells readable; the whole board always fits |
| Godot web export cannot be tested headless in CI | Software GL (SwiftShader) in Chromium for the smoke test; fps stays a manual phone check |
| A broken `main` reaches GitHub Pages | `deploy` depends on `ci` passing; protected `main`; roll back by redeploying the last good tag |
| Scope creep from lore and features | Phase gates: nothing new until the Godot build matches the web build |
| New foes and branches break the balance | Content flags; the Phase 4 fixtures keep the base game identical |

- [x] Repo name and whether it is public from day one: public from day one, repo `psychic-bassoon`, codename Project Slag.
- [x] Embed the game in the personal site, or link out: link out.
- [x] Landscape only (owner decision).
- [x] Engine: Godot 4 (owner decision, 2026-10-10); web first, native later.
- [ ] Music: commission, CC0 tracks, or skip for v1
- [x] Pages: `main` is the live "latest" build, deployed after `ci` passes. Tags only create GitHub Releases.
- [ ] Testing on a phone before merge: LAN or an uploaded build artifact (Pages can't preview PRs)
- [ ] Download budget for the Godot web build (set after the Phase 3 measurement)
- [ ] Rename the game: Scrapline no longer fits the medieval setting
