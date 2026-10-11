# Scrapline: 3D Remake Plan

Codename: **Project Slag**. The repo is `psychic-bassoon`; the game and its tracker board use Scrapline and Project Slag.

_Updated 2026-10-11: the game moves from Three.js to Godot. Living version: the Claude doc of the same name._

> **Status:** Phases 0 to 3 are complete. Phases 0 to 2 were built in TypeScript and Three.js; that game is retired and its last build is the tag `web-three-final` (the site root now serves the Godot stub scene). Phase 3 (the Godot foundation) passed its go/no-go on the owner's iPhone 15 Pro. On 2026-10-10 the owner decided to move the game to the **Godot engine** for more freedom (see [Engine decision](#engine-decision-godot)). The TypeScript sim, tests and prototype are the reference until the Godot sim reproduces them exactly. Phase 5 (play in Godot) started on 2026-10-11 as a greybox, in parallel with the rest of Phase 4 (owner decision; see Phase 5). Phase 4 is in progress: the PRNG, map generation with routes, and the game state, commands and tick are ported; foes, combat and waves are next. The target is web first, then native iOS. The setting is moving to fantasy medieval, so the lore and the game name will change (see Open questions). Use `prototype/scrapline.html` and the TypeScript sim as the reference for rules and numbers.

## Vision

Scrapline becomes a 3D low-poly tower defense for mobile browsers, built with Godot. The camera is angled like League of Legends, and foes march along procedurally generated roads, which can branch. It lives in this repo, deploys to GitHub Pages first and to native apps later, and doubles as a portfolio piece.

**Pillars**

- **One-thumb play.** Every action works with a single tap, in landscape. The game holds 60 fps on a mid-range phone.
- **Readable at a glance.** Silhouette and colour tell you each foe's type and each tower's level, even zoomed out.
- **Every run is a new road.** Seeded procedural maps that you can replay and share by seed.
- **A world worth caring about.** Short lore beats between chapters give the waves a reason to exist without slowing play.

Carried over from the prototype: grid placement, 4 tower types with 3 levels, endless waves, and the economy numbers as a starting point.

## Lore

> **Under revision:** the owner is moving the setting to fantasy medieval. The text below is the current draft; names (Greyhold Keep, the Hollow King, Castellan Quell, the unit and tower names) may change. Ids (`scamp`, `ballista`…) are stable keys in the fixtures and code; display names and lore strings live in `godot/content` and the Naming table in `CLAUDE.md`, so a rename does not touch logic or fixtures.

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

**Decision (owner, 2026-10-10):** build the game in Godot 4 instead of Three.js, for more freedom: a real editor for scenes, terrain, lighting and particles; animation and skeleton tools for foes; a UI toolkit; and a path to a native iOS app. Web in a phone browser comes first, native iOS later; Android is optional and not planned.

**What carries over:** the lore, naming, balance numbers, map and wave algorithms, all GLB assets and textures (including the owner's Blender models), the docs, tickets and review process.

**What is rewritten:** the simulation (TypeScript to GDScript), the renderer, the HUD, the tests and the build pipeline. The Three.js game was removed from the tree (tag `web-three-final` keeps it); the TypeScript simulation, content and fixtures stay as the oracle until the Godot sim passes parity, then move to `legacy/` or go.

**How the port stays correct:** the TypeScript sim is the oracle. It exports JSON fixtures (maps, routes, wave lists, damage cases, replay fingerprints for many seeds). The GDScript sim must reproduce them exactly (GUT tests). Same seed, same commands, same result: the Phase 1 replay gate is repeated, not skipped.

**Known costs and risks, accepted:**
- **Web export is heavier.** The standard Godot 4 web engine is tens of MB uncompressed and several MB compressed (not yet measured here), against about 150 kB for the Three.js bundle. Startup is slower; show a loading screen. Measuring it on the owner's iPhone is a go/no-go gate in Phase 3.
- **iOS Safari.** Use the single-threaded web export (no `SharedArrayBuffer`, so GitHub Pages works without special headers) and the Compatibility renderer (WebGL2). Audio must start after the first tap. Memory limits are tight: test on the real phone early.
- **GDScript only for the web.** As of the pinned 4.x, C# does not export to web and GDExtension is not an option for the web build, so the sim is GDScript. At 30 ticks per second with about 100 entities this is fine; check it in Phase 4.
- **Determinism (value parity, not byte parity).** GDScript floats are 64-bit like JavaScript's, so results match if we use the same operations (`+ - * /`, `sqrt`, `floor`; never `randf`, `randi`, trig or engine `round`). Traps to port deliberately: `/` between two integers is integer division in GDScript (divide by a float such as `4294967296.0`); JavaScript's `Math.imul` and `>>>` need every value kept in [0, 2^32) and masked after each `*`, `+` and `^`; `Math.round` becomes `int(floor(x + 0.5))`. Fixtures store integers above 2^53 and fingerprints as hex strings and are compared with exact `==` (Godot's `JSON.parse` returns every number as a float).
- **Different tooling.** gdtoolkit for lint and format, GUT for tests, the Godot CLI for export. CI must download a pinned Godot and its export templates (cache them).

**Native later:** the same project exports to iOS once the web build is solid (Android only if wanted); it needs an Apple Developer account, signing, App Store review and safe-area and input checks, so it is its own phase. Keep game code free of browser-only calls: the web shell (landscape prompt, reduced-motion read) stays outside `godot/sim`, `render` and `ui` logic behind one small adapter, so the iOS build swaps the adapter.

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
| Rendering | `MultiMeshInstance3D` per foe type, one scene per tower, a terrain scene built from ground tiles and a road ribbon | Few draw calls on a phone |
| Models | glTF/GLB (the owner's Blender models, Meshy-generated foes, CC0 packs); the Godot importer | Assets carry over from the web build |
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

**Phone performance budget:** 60 fps with 80 foes on screen (30 fps fallback with reduced effects); under 120 draw calls and about 150k triangles per frame; DPR capped at 2. Per unit: a foe 800 to 1,200 triangles with one 512 px texture map; a tower 1,500 to 3,000 triangles per level on a shared atlas; a boss 3,000 to 5,000 triangles with a 1,024 px map. Foes decide the budget: 80 of them at 1,200 triangles is about 96k, so the Scamp (the swarm foe) aims for the low end. Download budget to be set after the Phase 3 measurement (the web engine alone is several MB).

## Art direction and Claude Design

Low-poly storybook medieval: dark moss and slate ground, torch-amber light, stone towers with glowing crystals, one saturated colour per tower. CC0 models recoloured to a shared palette so mixed sources look like one game.

- **Palette.** Deep slate and moss ground, torch-amber UI accent, red glowing cores on the Hollow's champions. Cyan Ballista bolts, orange Catapult, violet Frost Spire, yellow Storm Spire.
- **Lighting.** Low-key with amber torch pools along the King's Road, light edge mist, glowing eyes and crystals.
- **Level readability.** Each upgrade adds a visible part plus coloured level lights on the base.

**Asset pipeline**

Track B, one asset end to end (owner rescope, 2026-10-11): the Scamp goes through the whole pipeline before any other foe does. Its gate is 80 animated Scamps at 60 fps on the owner's phone in the web export; the pipeline steps are then written down for the next foe. Meshy stays the source (polygon target set in Meshy, cleanup in Blender, driven through the Blender MCP with the owner watching the viewport):

1. Clean up: fix scale, put the origin at the feet facing forward, reduce to the triangle budget, bake the texture onto one map.
2. Armature: a small skeleton of about 15 to 20 bones (hips, spine, head, arms, legs, plus ears or a weapon if needed). Meshy's auto-rig for humanoid bipeds may save this step for the Scamp.
3. Skinning: automatic weights, then fix armpits and crotch.
4. Clips: walk, hit and die, each a short loop or one-shot.
5. Export for the way the unit is drawn in Godot (below).

| Unit | Godot setup | Why |
| --- | --- | --- |
| Foes (many) | Clips baked into a vertex-animation texture, played by a shader on a `MultiMesh` | `MultiMesh` cannot play skeletons |
| Bosses | Skinned glTF as `Skeleton3D` plus `AnimationPlayer` | Few on screen, so skinning is affordable |
| Towers | Separate parts animated in an `AnimationPlayer`, no skeleton | The head turns and the arm swings; nothing bends |

If the Scamp cannot reach 60 fps with vertex animation, the fallback is part animation and fewer animated instances (see Risks).


0. Foes: generate in Meshy, then clean up in Blender (retopology, decimate, shared palette texture, rig, clips). Record the Meshy plan, date and prompt or reference (see Open questions).
1. Shortlist CC0 low-poly packs: Kenney (Tower Defense Kit, Castle Kit, Fantasy Town Kit, Mini Dungeon) and Quaternius (fantasy, monsters and medieval packs). Check each licence file; anything not clearly CC0 is out.
2. Map every unit to a pack model and write the gaps in `docs/art/GAPS.md` (see the gap plan below).
3. In Blender, build or remap faces to one shared palette texture; kitbash gap units from pack parts.
4. Export GLB (meshopt compression is optional in Godot; the importer handles plain GLB).
5. Record source, licence and edits in `assets/CREDITS.md`.

**Reference image.** `docs/art/reference-wide-road.jpg` (see `docs/art/REFERENCES.md`) is the owner's target for the look: a wide, curved road with worn edges, towers on round stone bases, dusk light, crystals and torches. The road is drawn as a ribbon over the unchanged grid (Phase 5); a wider road in the sim itself (a finer grid with 2-cell roads and 2×2 plots, which changes every balance number) stays an option for the post-parity map version 2.

**Models.** The Three.js build used procedural primitives and then Kenney CC0 GLBs while the owner generated original models with Claude and Blender (`assets-src/blender/`). In Godot the GLBs are imported as scenes; the owner's Blender models are the preferred source (towers done; foes, terrain and ambient props in progress), with Kenney pieces as placeholders.

**Claude Design:** design system (tokens, type, panels) first; then mobile screens (title, HUD, build sheet, upgrade sheet, pause, game over, story card); key art for the README and personal site; reference sheets per foe and tower level. Claude Design covers 2D screens and reference art, not 3D models.

- **Rough silhouette sheets** (shape and colour only) for the 4 base foes and 4 towers come first and brief the models.
- **Final reference sheets** are drawn after the pack shortlist, so they follow what the packs can supply instead of asking for shapes that can't be sourced. Meshy foes are briefed from the silhouette sheets.

### Asset gap plan _(Phase 6)_

Which units a CC0 pack can plausibly cover, and what has to be built. Coverage is an expectation to confirm during the shortlist, not a verified fact; `docs/art/GAPS.md` holds the result.

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Scamp, Raider, Ironclad, Warlord | Meshy-generated models (owner's plan), cleaned up in Blender; CC0 fantasy or monster packs as placeholders | Kenney's Tower Defense Kit only has UFO enemies. Meshy output needs retopology and decimation to the triangle budget, recolour to the shared palette, a rig and walk, hit and death clips (an attack clip only if the sim gains a foe attack, such as the Saboteur) (baked to vertex animation for `MultiMesh`). Warlord needs a red glowing core and can use a skeleton. Licence: owned under the paid plan; record the plan, date and prompt in `assets/CREDITS.md`. |
| Mender, Shieldbearer, Saboteur | Probably no exact match | Kitbash: a base body plus an added part (censer and floating tray; door-sized shield; smoking fuse). Fall back to primitives if kitbashing clashes. |
| Hybrids (chapter 3) | None | Compose a base body with a second unit's part; no new full models. |
| Towers (4) | Kenney Tower Defense Kit | Stone tower pieces, ballista, catapult and cannon weapons, and crystal pieces cover all four; recolour crystals to violet and yellow. |
| Terrain and road | Procedural in Godot (textures and shaders), plus Blender-made tiles and props (some built with Claude); Kenney tiles as placeholders | Ground blend, road edge and fog are shader work. Tiles for corners, junctions (for forked routes), spawn and Heartstone, trees, rocks, crystals; snow variants for later chapters. |
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
  src/                   # the TypeScript sim and content: the oracle (to `legacy/` or removed after parity)
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
- MIT for code; each art source keeps its terms (CC0 packs, the owner's own models, Meshy plan terms).

## CI/CD pipeline

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `pr-checks` | PR opened, edited, updated | Conventional Commits on the PR title and commits; warns if no ticket is referenced. Already in place. |
| `ci` | PR and push to `main` | Pinned Godot and export templates (cached); `gdformat --check` and `gdlint`; the sim purity lint; GUT headless (fixtures, replay); Web export; download-size budget; Playwright smoke test against the exported build. During the migration it also runs the legacy TypeScript checks. |
| `deploy` | Push to `main`, only after `ci` passes | Publishes to GitHub Pages. The Godot export is served at the root URL. Until the game exists that is the Phase 3 stub scene; the Three.js build is no longer served (to run it, check out the tag `web-three-final`). A red `main` never reaches the public site. |
| `release` | Tag `vMAJOR.MINOR.PATCH` | Re-runs the checks, exports, and publishes a GitHub Release with generated notes and the build attached. |

**Versions follow phase gates** (semantic versioning, 0.x until launch). The only tag so far is `web-three-final` (the last Three.js web build, created 2026-10-11 before the Three.js code was removed). `v0.1.0` has not been cut yet; each later gate bumps the minor version. Notes come from Conventional Commits, so commit messages are the changelog.

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
| Map | Random path on a 9×13 grid | Seeded, shareable map drawn with a wide, smooth road (a ribbon over the same grid), with several routes from spawn to Heartstone (a main road and a detour at first; forks and loops after parity); procedural terrain with decorative props off the road. Drawn in landscape. |
| Towers | 4 types, 3 levels | Same, plus targeting mode per tower (first, strongest, closest) and a level 3 branch choice (two per tower) |
| Enemies | 4 types | Same 4, animated (walk, hit, death); Mender, Shieldbearer and Saboteur added in chapters 2–3; hybrids in chapter 3 |
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
| 5 · Play in Godot (greybox started in parallel with Phase 4, 2026-10-11) | Procedural terrain (shaders plus Blender tiles), MultiMesh foes, towers, camera, picking, effects, Control-node HUD, landscape prompt, audio on first tap | **Plays as well as the Three.js build (tag `web-three-final`, run locally) at 60 fps on the owner's phone with 80 foes** |
| 6 · Art and ambience | Meshy foes cleaned up in Blender, the owner's Blender towers, terrain tiles and ambient props; Claude Design screens and Theme; lighting, fog, torches, effects | All foes and towers (3 levels) use final models; every gap in `docs/art/GAPS.md` has a fallback |
| 7 · Lore and chapters | Story cards, herald proclamations, Chronicle pages, chapters 1–4; Mender/Shieldbearer/Saboteur, hybrids, level 3 branches, targeting, seed sharing | A new player finishes chapter 1 without help, and a headless run with each new foe and branch replays exactly from its seed |
| 8 · Polish, launch, native | Audio, performance pass, README with key art; linked from the personal site; iOS export (Android optional) | Public web build on two real phones; native iOS build on one iPhone |

## Phase details

### Phases 0 to 2 · TypeScript and Three.js: complete

Built and merged: the repo, CI/CD and protected `main` (Phase 0); the seeded, deterministic simulation with maps, branching routes, waves, combat, economy and a replay test (Phase 1); the 3D greybox with camera, picking, models, effects, HUD, landscape layout, GLB pipeline, Kenney and Blender models (Phase 2 and early Phase 3 work). Their tickets are closed on the board. The code is the reference for the port.

### Phase 3 · Godot foundation

**Goal:** an empty Godot project that builds, tests and deploys through the same checked pipeline, and proves the web export runs on the owner's iPhone.

**Work breakdown**
1. Add `godot/` with a pinned Godot 4 version, the Compatibility renderer and a single-threaded Web export preset; a custom HTML shell (landscape prompt, meta tags, loading screen).
2. CI: install the pinned Godot and templates (cached), `gdformat --check`, `gdlint`, GUT, the sim-purity lint, export, size budget, Playwright smoke on the export.
3. Deploy the export to GitHub Pages from `main` (at the site root since the Three.js game was retired). Tag `web-three-final`.
4. Export fixtures from the TypeScript sim into `fixtures/` (maps and routes for many seeds, wave lists, damage cases, replay fingerprints) with a script and a test that regenerates and compares them.
5. Measure on the iPhone: download size, start time, a stub scene with 80 animated instances; set the budgets.

**Out of scope:** any gameplay.

**Gate checklist**
- [x] An empty Godot scene deploys from `main` and loads on the owner's iPhone Safari (iPhone 15 Pro, 60 Hz).
- [x] CI runs lint, GUT and the export, and a red check blocks the deploy.
- [x] Fixtures exist and the TypeScript tests regenerate them identically.
- [ ] **Go/no-go:** on the owner's iPhone Safari the export's download size, start time, memory and an 80-instance stub scene are within the budget set here. If not, stop and take the fallback in Risks (keep Three.js for web, Godot for native only) before any Phase 4 work.
  - **Result (2026-10-10): go.** The stub runs on the owner's iPhone 15 Pro (60 Hz). The export is 11.67 MB gzipped (`index.wasm` 10.15 MB, `index.pck` 1.40 MB). Download budget: 14 MB gzipped, as CI enforces. Not measured: start time and memory in numbers, frame rate beyond "works", and any mid-range phone; the iPhone 15 Pro is a flagship, so the 60 fps target on a mid-range phone stays open for the Phase 5 gate. Phase 4 started before this was recorded, on the owner's instruction.

### Phase 4 · Sim port to GDScript

**Goal:** the whole simulation in GDScript, byte-for-byte equal to the TypeScript oracle.

**Work breakdown** (test-first, one context at a time)
1. PRNG (mulberry32 and `deriveRng`) on masked 32-bit integers; golden values from the fixtures.
2. Map generation with the main road, the detour and tile data; routes and positions. This is the first sim work after the PRNG, so the map and terrain can be looked at early.
3. Game state, commands and the 30 Hz tick; the command queue and rejection events.
4. Combat: movement, targeting across routes, damage and armor, the four towers' behaviour, shells.
5. Waves and economy: composition, spawning, route choice, bonuses.
6. Replay: the scripted bot and the fingerprint, compared with the TypeScript fingerprints for many seeds; a headless CLI (`godot --headless`) that prints the map and wave log.
7. After parity, map version 2: more routes (forks, loops) behind a content flag. Validity is per route: each route is a simple path from spawn to Heartstone, not adjacent to itself except at consecutive cells; a junction is any cell on two or more routes, routes may share runs of cells (a trunk) between junctions, and outside shared runs two routes are not adjacent. The GDScript sim exports the new fixtures.

**Gate checklist**
- [ ] Every fixture matches exactly (maps, routes, waves, replay fingerprints).
- [ ] The sim imports nothing from the scene tree (lint).
- [ ] A 12-minute headless run finishes within a time budget on CI.
- [ ] After parity (step 7): maps support more than two routes as a new map version behind a content flag, with GUT tests for validity and new fixtures exported from the GDScript sim.

### Phase 5 · Play in Godot

**Goal:** the game playable on the phone in Godot, at least as good as the web build.

**Rescope (owner decision, 2026-10-11): greybox first, in parallel with Phase 4.** Phase 5 starts now as a greybox while the rest of the sim port continues. This is a deliberate exception to "work one phase at a time". The risk is low because the greybox only reads sim snapshots and sends commands, so it cannot break parity; if a sim change breaks a greybox scene, the greybox adapts. The Three.js renderer and HUD are already gone; `src/sim` and the fixture export script stay until the Phase 4 gate, because the combat port may need new fixture cases. Track C (terrain art) is parked at the proof of concept (Blender tiles plus world-space Godot shaders and scatter) and returns as the art pass over A1, with the terrain code reading the real map and the smooth road ribbon below.

| Step | You get | What it teaches |
| --- | --- | --- |
| A1 Board | The real `MapGen` map as flat tiles (cubes for plots, a strip for the road), a camera rig, a `@tool` preview with a seed field | Scenes, `Node3D` transforms, `@export`, `@tool` |
| A2 Picking | Tap a cell: highlight it, open a build menu, send a build command | Input events, a raycast onto the board, signals |
| A3 Foes | Capsules walking the routes, one `MultiMesh` per foe type, smooth movement between ticks | `_process` against the fixed tick, interpolation, `MultiMesh` |
| A4 Towers | A tower scene with stats in a `.tres` resource, a range ring, shots | `PackedScene`, custom resources, the Inspector |
| A5 HUD | Gold, lives, wave, speed and pause, game over, landscape layout | `Control` nodes, containers, anchors, Theme |
| A6 Loop | Waves, a win and lose screen, 1×/2×/3× speed | Game flow, scene switching |

A1 and A2 can start now (map generation, game state and commands are ported); A3 onward lands as the combat and wave ports merge. Each step is built by Claude and read by the owner with the Remote scene tree open, then tweaked in the Inspector. A Godot MCP server that can launch the project, read its output and take screenshots (checked with Godot 4.7) lets Claude see the result without copying logs by hand.

**Work breakdown**
1. Procedural terrain built from the map, with the road drawn as a smooth ribbon: a curve through each route's cell centres (corner radius 0.5 cell on the centreline; the inner edge radius is `max(0, r - w/2)`, so a sharp inner corner is fine), up to 1.25 cells wide (`w`), with a dirt shader and worn, grassy edges. Two roads two cells apart (a detour) leave 0.75 of a plot cell visible between them, and a ribbon covers at most 0.125 of a neighbouring plot cell, so stone bases are at most 0.75 cell wide. Junctions are where ribbons meet and blend. The sim polyline stays the truth for movement, range and hits. Foes walk the smoothed centreline: their progress maps onto the curve by arc-length fraction per segment, and a render-only sideways offset, stable per foe (derived from the foe id, never random per frame) and bounded by `min((w - foe width) / 2, r - ε)` (below the corner radius, so a foe never loops backwards at a corner), spreads a crowd. GLB tiles are used for ground, edge dressing and scenery, not for road pieces. Also: Godot ground textures and shaders, scenery ring, spawn and Heartstone, dusk lighting and fog.
2. `MultiMesh` foes with interpolation and baked vertex animation (spike it on the phone first), towers with levels and idle/fire animation, selection highlight and range ring.
3. Camera: landscape framing, pinch, pan, clamps; tap picking to a cell (the cell decides, not the visible dirt; the plot highlight shows the whole cell over the ribbon edge).
4. Control-node HUD: gold, lives, wave, build sheet, tower sheet, speed, pause, next-wave popup, auto-start, game over, landscape prompt.
5. Effects (beams, arcs, rings, sparks, shells), reduced motion, audio after the first tap.
6. Performance pass on the phone: 80 foes at 60 fps within the draw-call and triangle budget.

**Gate checklist**
- [ ] Plays as well as the Three.js build (tag `web-three-final`, run locally) at 60 fps on the owner's phone with 80 foes.
- [ ] Every action is reachable in landscape; tap targets at least 44 px.
- [ ] The road ribbon matches the sim routes by eye on the phone: foes stay on the dirt, hits land on visible foes at corners, and plot bases are not covered by the road.
- [ ] The replay gate still passes.

### Phase 6 · Art and ambience

**Goal:** the final look, without changing gameplay.

**Work breakdown**
1. Final models: the owner's Blender towers (done); foes from Meshy cleaned up in Blender; Blender terrain tiles and ambient props. Record each in `assets/CREDITS.md`, with the Meshy plan, date and prompt for generated models.
2. Claude Design: system and tokens first, then mobile screens; build the Godot Theme from them.
3. Foe and tower animation (rigged clips baked for `MultiMesh`, `AnimationPlayer` for towers and bosses); torches, mist, glow, crystals, particles.
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
4. Final licence check: `assets/CREDITS.md` complete, MIT for code; each art source keeps its terms (CC0 packs, the owner's own models, Meshy plan terms).
5. iOS export: Apple Developer account, signing, input and safe areas, store listing. Android only if the owner asks.

**Gate checklist**
- [ ] Public web build runs on GitHub Pages on at least two real phones.
- [ ] README and credits complete.
- [ ] The native iOS build runs on one iPhone.

## Risks and open questions

| Risk | Fallback |
| --- | --- |
| The Godot web build is too heavy or slow to start on a phone | Measure in Phase 3 before porting; trim export (disable unused modules with a custom build), lazy-load assets, loading screen. If it is still too heavy, fall back to the Three.js build for web and use Godot for native only. |
| iOS Safari limits (memory, audio, no threads) break the export | Single-threaded export, Compatibility renderer, test on the real phone every phase; the Three.js build can be redeployed from the tag `web-three-final` if the Godot web build fails on a target phone |
| The GDScript sim drifts from the TypeScript oracle | Fixtures from the TypeScript sim and exact-match GUT tests; the TypeScript sim is frozen once the fixtures exist; it changes only for a bug, with the fixtures regenerated and the Godot sim updated in the same PR |
| Floating-point or integer differences (integer division, 32-bit wrap, rounding) | Use only `+ - * /`, `sqrt`, `floor`; divide by floats; mask integers to 32 bits after every operation; `int(floor(x + 0.5))` for `Math.round`; golden-value tests for the PRNG and `deriveRng`; hex-string fixtures compared with `==` |
| The DOM HUD is lost (screen readers, text scaling, crisp text, `prefers-reduced-motion`) | Control nodes with a Theme and large text; read reduced motion through one platform adapter (a small `JavaScriptBridge` call in the web shell; an in-game setting or native plugin on iOS); accept the accessibility loss and record it |
| Part animation and skeletons fight `MultiMesh` (each part or material is another draw call; skinned meshes cannot use MultiMesh) | One MultiMesh per foe type and part, count draw calls in the Phase 5 gate; bake animation into vertex shaders or use a few skinned bosses only |
| The TypeScript oracle and its tests are forgotten | The Vitest suite keeps running in CI while `src/` exists; fixtures stay in CI forever |
| The greybox (Phase 5) builds on a sim that is still being ported | The greybox only reads snapshots and sends commands; sim API changes are caught by its tests and by CI; parity fixtures decide any disagreement |
| Animation for many foes is too slow on phones | Baked vertex animation on `MultiMesh` first; fall back to part animation and fewer animated instances; skeletons only for bosses and towers, counted in the draw-call budget |
| CC0 packs don't share a consistent style | Prefer the owner's Blender models; palette-texture recolour; drop models that still clash |
| The smoothed road ribbon drifts from the sim polyline (foes look off the road or hits look wrong at corners) | The centreline stays inside its cell band (corner radius 0.5 cell, ribbon at most 1.25 cells wide); the sim polyline decides hits, range and distance; the Phase 5 gate checks it by eye on the phone |
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
- [x] Download budget for the Godot web build: 14 MB gzipped (11.67 MB measured at the Phase 3 gate); trim the export if it grows.
- [ ] Rename the game: Scrapline no longer fits the medieval setting, and the lore is being rewritten as fantasy medieval. Decide the name and which lore names stay before Phase 6 art and Phase 7 text.
- [x] Meshy: the owner is on the paid premium plan (3,000 credits a month). Per Meshy's FAQ (checked 2026-10-10, not the full Terms of Service) a paid customer owns the assets, provided the inputs do not violate anyone's copyright; free-plan outputs are CC BY 4.0, so they are not used. Rules: generate only on the paid plan (the plan at generation time is what counts; the FAQ does not say what happens if the subscription lapses, so keep the source files); never prompt with or upload copyrighted characters, third-party images, brands or real people's likeness (our policy); record the source, licence, date and prompt or reference per model in `assets/CREDITS.md`. Re-check the terms if the plan changes.
- [ ] Vertex animation on `MultiMesh` for many animated foes: works on iPhone Safari within budget? Spike in Phase 5; fallback is part animation and fewer animated instances.
