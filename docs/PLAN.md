# Papercraft Kingdom Defense: Plan

Codename: **Project Slag**. The repo is `psychic-bassoon`; the game is **Papercraft Kingdom Defense** (formerly Scrapline; the code was renamed on 2026-10-13) and its tracker board is Project Slag.

_Updated 2026-10-11: the owner adopted the Papercraft Kingdom Defense GDD (`docs/GDD.md`) as the design. Living version: the Claude doc of the same name; the GDD itself lives in the owner's Google Doc._

> **Status (2026-10-18): a new art direction, a bigger map and native platforms (owner).** The look becomes "Hand-Folded Fantasy", a boundless papercraft diorama of a fantasy valley (`docs/art/STYLE.md`); the desk, cutting mat and tape road are dropped, and the lore stays. The map grows to 32x20 cells with curved routes the sim walks, a river with bridges held by guards, and a hero you move across the map. The web build is dropped: iOS first, then macOS, Windows and Linux, on the Forward+ and Mobile renderers; a debug build already runs on the owner's iPhone 15 Pro. Epic #316; decision records `docs/lessons/2026-10-18-hand-folded-fantasy.md`, `2026-10-18-native-only.md` and `2026-10-18-valley-map.md`. Where this plan or `docs/GDD.md` still says cutting mat, desk, tape road, web or Safari in a section below, these decisions win.

> **Status (2026-10-13):** Phases 0 to 4 are complete. Phases 0 to 2 were built in TypeScript and Three.js; that game is retired (last build: the tag `web-three-final`). The game moved to the **Godot engine** on 2026-10-10 and the owner adopted the GDD on 2026-10-11: a papercraft stop-motion tower defense with a hero, spells and a tech tree. Phase 4 (the simulation in GDScript) closed on 2026-10-13: the whole sim is in GDScript, deterministic and covered by replay goldens, with the Phase 4 gate checked below. Phase 5 (play in Godot) is a finished greybox (board, picking, foes, towers, HUD, win and lose, speeds) whose gate still waits on two checks on the owner's phone (60 fps with 80 foes, and the road, sockets and foes lining up by eye). Phase 7 content started early at the owner's request: three shooting towers, the Guard Tent and the Kitchen Mess Tent, blocking guards, and bigger swarm waves; flying and support foes, tier 4 specs, the hero and spells are not built. The owner models the art themselves in Blender (Meshy was dropped on 2026-10-13). The target is web first, then native iOS.

## Vision

Papercraft Kingdom Defense is a tactile, isometric 3D tower defense for phones and tablets, built with Godot 4. You are the Grand Crafter defending a folded paper valley, building towers from spools, tents, prisms and thimbles to hold back corrupted stationery. It lives in this repo, ships natively on iOS first and on Mac and PC next (the web build was dropped on 2026-10-18), and doubles as a portfolio piece.

**Pillars**

- **One-thumb play.** Every action works with a tap or a drag, in landscape, with 48 pt targets. The game holds 60 fps on a mid-range phone.
- **Readable at a glance.** Silhouette, material and colour tell you each foe's type and each tower's tier, even zoomed out.
- **Handmade.** Everything looks cut, folded and glued: kraft paper, cardboard, foil, tape and ink; animation steps at 12 fps like stop-motion while the camera stays smooth.
- **Tactical, not twitchy.** Pre-etched sockets, a few strong choices per tower, and a hero and spells for the moments that matter.
- **Every run is a new valley.** Seeded procedural maps that you can replay and share by seed.

## Lore

**The War of the Cutting Mat.** In a forgotten corner of an old craft room, an abandoned green self-healing cutting mat holds a thriving miniature civilization of recycled paper strips and cardboard cutouts. Peace ends when The Blot strikes: a bottle of corrupted, magical purple India ink tips over from the high shelves. As the ink seeps into the paper fibre it twists peaceful scraps into jagged monsters that want to shred everything into confetti. You are The Grand Crafter, and your legendary craft artifacts (scissors, glue guns, tape rolls) guide origami defenders and corrugated bastions against the ink-born tide.

The look no longer shows the mat or the craft room (owner, 2026-10-18): the paper folk's kingdom is drawn as a folded fantasy valley, and the story is unchanged. The full text is in `docs/GDD.md`. The old Scrapline lore (Greyhold Keep, the Hollow King, Castellan Quell) is dropped. Names appear in `godot/content` only; ids are stable keys (see Naming in `CLAUDE.md`).

## Design (from the GDD)

`docs/GDD.md` is the source; this is the summary the plan is built on.

**Loop.** Scout and build (spend Buttons, the currency, on pre-etched sockets) → engage the wave (call it early for bonus income) → combat (targeting priorities, hero commands, drop-scraps, spells powered by regenerating PVA Ink / Crafting Energy) → rewards (Golden Staples from remaining Heartstone health, spent in a workshop tech tree on permanent skills, base stats and new origami blueprints).

**Maps.** _Superseded in part on 2026-10-18: the map is a 32x20 valley with curved routes, terraces, a river and guarded bridges (#320 to #323), drawn as a diorama, not a mat._ A seeded cutting-mat board of 1 m tiles, **16 columns by 11 rows (176 cells), landscape** (owner, 2026-10-14, Map v3 #255: 22 by 16 showed too many cells at a readable unit size; before that 9 by 13), inside an out-of-bounds diorama skirt. Three levels: level 0 the mat (lanes 1 to 2 cells wide), level 1 a glued cardboard rise (+1.0 m), level 2 tiered cliffs (+2.0 m, a +15% range bonus and no line-of-sight blockers). Hazards: foil rivers with popsicle-stick bridges (a foe knocked into the water is slowed 50%), single-use tape strips, PVA glue puddles. Building is on 12 to 15 pre-etched circular sockets per map, each a **2x2 cell footprint** (2 m), not on free cells; towers stand 3 m to 6 m tall. The objective is the **Heartstone**, a 2x2 to 3x3 cell crystal at the end of the lane. **Owner decision, 2026-10-12: one path and one spawn source for now.** No detour or branching, and drawbridges and levers are dropped; the update no longer mentions level 1 as a choke point either. Several spawn sources that merge into the one path are a backlog idea (Phase 8 and later), see Backlog.

**Towers.** Four archetypes, each with tiers 1 to 3 (linear damage, range and fire-rate upgrades) and a tier 4 that splits into two specialisations, each with one active and one passive ability.

| Tower (archetype) | Base unit | Spec A | Spec B |
| --- | --- | --- | --- |
| The Spool Guard (archer) | A thread spool with a toothpick ballista firing paper-strip darts | Crossbow Ballista: piercing Heavy Skewer, Bleed; Armor Piercing 40% | Paper-Plane Aviary: Squadron Launch of 3 paper planes; High Recon +20% range to neighbours |
| The Guard Tent (barracks) | A folded origami tent that spawns 2 guards to block the path | Cardboard Knights: Shield Wall; reflect 15% melee | Scissor Rogues: Precision Snipe; Paper Cuts slow stacks |
| The Prism Spire (mage) | Rolled construction paper topped by a glass marble prism | Cryo-Origami Spire: Flash Freeze; Frostbite +20% damage taken | Blot Singularity: Ink Vortex pulls light foes; Corrosive Light strips armor |
| The Thimble Mortar (artillery) | A metal thimble with matchstick powder, splash paper pellets | Glitter Cannon: Confetti Burst blinds; splash +35% | Sticky Glue Mortar: PVA Deluge slows 70%; Lingering Residue pools |

**Foes.** Scrap Goblin (swarm: fast, low health, weak to splash), Razor Moth (flying: ignores ground paths and blockers, needs anti-air), Corrugated Orc (armored: high armor, slow, needs armor stripping or magic), Ink Shaman (support: heals and speeds up nearby foes, prioritise it), Cardboard Golem (boss: huge health, spawns Scrap Goblins when destroyed).

**Hero and spells.** The Knight of Cardboard is a movable, persistent hero (passive Rally Cry, active Blade Whirl with a 15 s cooldown). Three global spells from a bottom-right Toolbox Tray, cast by dragging with a live ground decal: PVA Glue Trap (slow 60% for 8 s), Falling Thumbtacks (damage and stumble on a 2×2 area), The Crafter's Eraser (strips non-boss armor, shields and buffs in a radius).

**Touch.** A radial context menu (48 pt targets, offset above the finger), one-finger pan with rubber-band edges, two-finger pinch to zoom with a 30° to 65° view angle, drag-and-drop spells.

### Mapping from the ported sim

The ids in the code are stable keys; the GDD renames what the player sees and adds content. `godot/content` holds the GDD's three combat tower ids (`spoolGuard`, `thimbleMortar`, `prismSpire`); the Guard Tent comes in Phase 7.

| Ported or prototype concept | In the GDD |
| --- | --- |
| Ballista (`ballista`) | The Spool Guard |
| Catapult (`catapult`) | The Thimble Mortar |
| Frost Spire, Storm Spire | The Prism Spire: a magic beam tower (the GDD has no chain lightning); the slow comes with its Cryo-Origami spec (tier 4) and the Blot specs, and from glue and hazards |
| (none) | The Guard Tent: new, needs foes that stop and fight |
| Scamp | Scrap Goblin |
| Raider, Ironclad | Corrugated Orc (one armored foe; speed and armor tiers by wave) |
| Warlord | Cardboard Golem |
| (none) | Razor Moth (flying), Ink Shaman (support), the hero, the spells, the tech tree |
| Heartstone, lives | The Heartstone's health (the Heartstone returns in the 2026-10-12 GDD; the code says `heartstone_health`) |
| Free plots on every non-road cell | 24 to 30 sockets on the 32x20 valley (#320; 12 to 15, mostly 12, on the 16x11 board before) |
| Gold | Buttons (in a run), Golden Staples (between runs) |

### Gaps in the GDD

The GDD sets the direction and few numbers. These need a decision or a number before they can be built; each gets a ticket when its phase starts.

1. **Numbers.** Costs, damage, range and fire rate per tier; foe health, speed, armor and rewards; wave composition; Button and Golden Staple payouts; Crafting Energy regeneration and spell costs; hero stats and what happens when it falls; the tech tree's contents. Start from the prototype's numbers where a concept is the same, and tune with headless runs.
2. **Sockets and elevation.** The ported generator makes roads and treats every other cell as a plot. Sockets (12 to 22), the three levels and the range bonus are a new map layer on top of it; the tiles stay in the sim and Godot only draws them.
3. **Engine nodes versus the pure sim.** The GDD sketches `GridMap`, `Path3D` splines and an `Area3D` per socket. The sim stays plain data (grid, polyline routes, sockets as cells); `GridMap` or a `MultiMesh` draws the terrain, and `Path3D` is at most a visual aid. This keeps replays deterministic.
4. **Blocking and melee.** The Guard Tent's guards block and fight, so foes need an attack and units need health. The prototype has neither. This is a new combat context.
5. **Flying foes.** Razor Moths ignore routes: their line from spawn to the Heartstone and which towers can hit them (an anti-air flag) are open.
6. **Status effects.** Slow, bleed, freeze, blind, armor strip, buffs and healing need one shared status model with stacking and timers.
7. **New commands.** Choose a tier-4 specialisation, activate an ability, move the hero, cast a spell at a point, spend Golden Staples. They are commands like `build`, never direct state changes.
8. **Radial menu and the greybox.** The greybox build menu is a side panel (step A2); the radial menu replaces it in A5. Pan, pinch and the 30° to 65° tilt are camera work for Phase 5.
9. **Stop-motion at 12 fps.** Animation is sampled at 12 fps while the sim ticks at 30 Hz and the camera runs at 60: baked vertex-animation clips are sampled at a stepped time, so it costs nothing extra; it needs checking with the `MultiMesh` foes.
10. **Story presentation.** The GDD has lore but no chapters, story cards or voice. The old chapter plan is dropped until the owner asks for it.
11. **Persistence.** The tech tree needs saved progress (a file on iOS and desktop) behind one adapter.
12. **Landscape.** The GDD says phones and tablets and does not mention orientation; the owner's rule stays: landscape only.
13. **Damage types and beams.** The GDD relies on physical, magic and true damage (the Orc "requires magic", Frostbite boosts "physical towers", Precision Snipe is "true damage") and on a continuous beam (the Prism Spire). The ported model has one armor floor. Define the types, how armor and resistances apply to each, and beam versus projectile attacks before the combat core (Phase 4 step 6).
14. **Meta-progression and determinism.** Golden Staples upgrade permanent skills and base stats, so the same seed and commands give different runs for different tech trees. A run's input must be the seed, the commands and a frozen meta-loadout (the tech-tree state at the start of the run), stored with replays, shared seeds and best-wave records.
15. **Smaller mechanics.** Line-of-sight blockers (level 2 towers bypass them), harvesting drop-scraps (a tap command?), the wave timer that starts a wave when it expires, and the Golem spawning Scrap Goblins when destroyed (needed for the Phase 5 gate "to the boss").
16. **Asset pipeline.** The GDD's section 7 is titled "asset pipeline" but has no pipeline content; the plan's Blender and Godot pipeline stands (the owner models every unit in Blender; Meshy was tried and dropped on 2026-10-13).
17. **GDD update, 2026-10-12.** The map is 22×16 with 2x2 sockets and a Heartstone footprint (Map v2, step 5a of Phase 4). The update no longer mentions branching routes, toggleable drawbridges, levers or level 1 as a choke point (dropped), and the river slow is now 50% only for a foe knocked into the water (a knockback mechanic nobody has yet: Guard Tent units or the hero). It adds the Kitchen Mess Tent (an aura and shield model for friendly troops), the Camp Cook hero and the Messenger Crow. Owner answers, 2026-10-12: **one path and one spawn source**, so the detour, branching, drawbridges and levers are all dropped for now (the earlier "detour stays" is superseded); the Mess Tent and Camp Cook numbers are generated by Claude to fit the other towers and heroes when they are built in Phase 7, for the owner to tune; the balance pass for the longer roads follows the generator and socket tickets.

### Backlog

- **Several spawn sources that merge into the existing path** (owner idea, 2026-10-12). Each source would have its own entry road joining the main road. Not planned for a phase; the sim already lets a foe pick among several routes (`routes` and the route stream), which is the starting point. Needs a design pass (wave composition per source, tower coverage, how the roads merge) and its own ticket once a phase takes it.
- **Branching with drawbridges and levers** (the original GDD): dropped on 2026-10-12; revisit only if the owner asks.

## Engine decision: Godot

**Decision (owner, 2026-10-10):** build the game in Godot 4 instead of Three.js, for more freedom: a real editor for scenes, terrain, lighting and particles; animation and skeleton tools for foes; a UI toolkit; and a path to a native iOS app. Web in a phone browser comes first, native iOS later; Android is optional and not planned.

**What carries over:** the seeded PRNG, the road generator, the game state, commands and tick, the docs, tickets and review process, and the Blender sources. The prototype's lore, names and balance numbers are a starting point only (see the GDD adoption below).

**What is rewritten:** the simulation (TypeScript to GDScript), the renderer, the HUD, the tests and the build pipeline. The Three.js game was removed from the tree (tag `web-three-final` keeps it).

**GDD adoption (owner, 2026-10-11):** the GDD in `docs/GDD.md` replaces the prototype as the design. Parity with the TypeScript prototype stops being the goal for new content: the foes, towers, combat and economy are designed from the GDD and tested in GDScript. The TypeScript sim stays as a read-only reference for formulas (armor floor, wave scaling, the kill rule) until the GDScript combat lands, then `src/` and the unused fixtures go. The PRNG, the road generator, the routes and the game core keep their fixtures as regression tests, and those fixtures are never regenerated.

**How the sim stays correct:** the same seed plus the same commands must give the same result. From the combat port on, GDScript-generated replay goldens (fixtures written by the GDScript sim itself, with float bits) are the regression check, and any change to them is a reviewed, deliberate balance change.

**Known costs and risks, accepted:**
- **Web export is heavier.** _(Retired with the web build, 2026-10-18.)_ The standard Godot 4 web engine is tens of MB uncompressed and several MB compressed (not yet measured here), against about 150 kB for the Three.js bundle. Startup is slower; show a loading screen. Measuring it on the owner's iPhone is a go/no-go gate in Phase 3.
- **iOS Safari.** _(Retired with the web build, 2026-10-18.)_ Use the single-threaded web export (no `SharedArrayBuffer`, so GitHub Pages works without special headers) and the Compatibility renderer (WebGL2). Audio must start after the first tap. Memory limits are tight: test on the real phone early.
- **GDScript only for the web.** _(Retired with the web build, 2026-10-18.)_ As of the pinned 4.x, C# does not export to web and GDExtension is not an option for the web build, so the sim is GDScript. At 30 ticks per second with about 100 entities this is fine; check it in Phase 4.
- **Determinism.** The ported pieces still match the TypeScript fixtures bit for bit, and the rules that made that possible stay: GDScript floats are 64-bit like JavaScript's, so results match if we use the same operations (`+ - * /`, `sqrt`, `floor`; never `randf`, `randi`, trig or engine `round`). Traps to port deliberately: `/` between two integers is integer division in GDScript (divide by a float such as `4294967296.0`); JavaScript's `Math.imul` and `>>>` need every value kept in [0, 2^32) and masked after each `*`, `+` and `^`; `Math.round` becomes `int(floor(x + 0.5))`. Fixtures store integers above 2^53 and fingerprints as hex strings and are compared with exact `==` (Godot's `JSON.parse` returns every number as a float).
- **Different tooling.** gdtoolkit for lint and format, GUT for tests, the Godot CLI for export. CI must download a pinned Godot and its export templates (cache them).

**Native now (owner, 2026-10-18):** the web build is dropped and the game ships natively (`docs/lessons/2026-10-18-native-only.md`, #318, #319). The history: the same project was to export to iOS once the web build was solid (Android only if wanted); it needs an Apple Developer account, signing, App Store review and safe-area and input checks, so it is its own phase. The web shell went with the web build (#318); its jobs (the landscape prompt, the fullscreen button, the reduced-motion read and the `?stress` and `?fps` parameters) move into the game behind one small platform adapter, outside `godot/sim`, `render` and `ui` logic (#319).

## Tech stack and architecture

The simulation is plain GDScript with no Node, scene or engine-singleton dependencies: deterministic, unit-testable, and able to run headless (`godot --headless`) for balance testing. Rendering and the HUD only read its state.

```
Content data ──defs──▶ Simulation (30 Hz, seeded) ──state──▶ Godot 3D scene (MultiMesh, camera)
Input / HUD taps ──commands──▶          │           ──events──▶ HUD (Control nodes)
```

| Layer | Choice | Why |
| --- | --- | --- |
| Engine | Godot 4.x (version pinned at setup); Forward+ on desktop and the Mobile renderer on iOS and Android (decided 2026-10-18, #318; Compatibility before that, for the web build) | SSAO, fog, glow and depth of field for the diorama look; native iOS, macOS, Windows and Linux exports |
| Language | GDScript, typed everywhere | Runs on every export target in the pinned 4.x (it was also the only language for the web build) |
| Simulation | `RefCounted` classes and plain data (Dictionary and typed arrays) under `sim/` | No scene tree, so tests and headless runs are fast and deterministic |
| Rendering | `MultiMeshInstance3D` per foe type, one scene per tower, the diorama terrain built from the map at load time in culled chunks with scatter as one `MultiMesh` per prop type (2026-10-18, #324 to #326; it was modular 1 m tiles) | Few draw calls on a phone |
| Models | glTF/GLB (the owner's Blender models, CC0 packs); the Godot importer | Assets carry over from the Three.js build |
| HUD and menus | `Control` nodes with a Theme resource | Native layout, anchors and touch input; a Theme mirrors the Claude Design tokens; a radial context menu for sockets and towers |
| Randomness | Seeded PRNG (mulberry32 on masked 32-bit integers) | Maps and waves replay exactly from a seed (the ported pieces match the TypeScript fixtures) |
| Tests | GUT (Godot Unit Test) run headless; the TypeScript fixtures for the ported core, then GDScript replay goldens; a Linux desktop export in CI that must start and run headless (it replaced the web export and the Playwright smoke test in #318) | Balance, maps and replays stay verifiable |
| Audio | Godot `AudioStreamPlayer` | Native builds can start sound at once |
| CI/CD | GitHub Actions: PR checks, gdlint and gdformat, GUT, a Linux desktop export, a Pages page that links to the releases list, tagged releases with the Linux, Windows and macOS builds | Every change ships through the same checked path (see CI/CD pipeline) |

- **Camera.** Perspective `Camera3D`, 20° field of view, landscape framing, pitched 62° zoomed out and 56° zoomed in; one-finger pan with rubber-band edges and a two-finger pinch that zooms around the fingers; no follow camera (owner, 2026-10-14). On the 32x20 map (owner, 2026-10-18) the camera pans across the map: a run starts near the spawn, the zoom-out limit shows the whole map as an overview (a tap there zooms in first), and pan is clamped to the map plus a scenery margin (#328; it used to start with the whole 16x11 board in view).
- **Simulation.** Fixed 30 Hz tick (an accumulator in `_process`) owns all state. Rendering interpolates between ticks. 2×/3× speed means extra ticks per frame.
- **Rendering.** One `MultiMesh` per foe type; each tower is its own scene instance. Warm sunlit diorama with cool magic (see Art direction and `docs/art/STYLE.md`).
- **Input.** A tap ray-casts the ground plane to a cell, a socket or a tower, and sends a command. No direct state changes.
- **Orientation.** Landscape only, locked by the exports (#319).

**Phone performance budget** (provisional for the 32x20 map and the diorama until #97 re-measures it on the iPhone in a native build; triangles count what is in view, so terrain and scatter are built in culled chunks): 60 fps with 80 foes on screen (30 fps fallback with reduced effects); under 120 draw calls and at most 200k triangles per frame (owner, 2026-10-18, provisional until #97 measures it on the iPhone: `docs/lessons/2026-10-18-diorama-budget.md`); DPR capped at 2. Per unit (the whole model at that level, not an increment): a foe 800 to 1,200 triangles with its own baked 512 px map; a tower 1,500 to 3,000 triangles on a shared atlas; a boss 3,000 to 5,000 triangles with a 1,024 px map. These ranges only fit together under worst-case caps for the 200k frame: foes at most 80k in total (80 foes average at most 1,000, so the Scrap Goblin swarm sits at the low end and only a few foes reach 1,200), towers at most 45k in total (22 towers, the most sockets a map has, at the top tier average about 2,050, so top-of-range towers must be few), the diorama's terrain and road beds at most 40k (the terraces, the water, the road beds and the bridges), its scenery at most 32k, one boss at most 5k (effects fit in the rest). `godot/tests/render/test_diorama.gd` asserts the terrain and scenery caps. A tower is at most 3 mesh parts of one surface each (the Prism Spire's glass marble adds a fourth), so 22 towers are at most 88 of the 120 draw calls plus 22 shadow draws (only a tower's base casts a shadow), and each guard is 3 more (2 a Guard Tent), so a board full of tents is the case the Phase 5 pass must measure (the desk lamp's shadows came with the board look, `docs/lessons/2026-10-17-papercraft-board-look.md`; towers and units: `docs/lessons/2026-10-18-papercraft-towers-and-units.md`). The Phase 5 performance pass checks the caps with the real counts. Download budget to be set after the Phase 3 measurement (the web engine alone is several MB).

## Art direction and Claude Design

**Hand-Folded Fantasy** (owner, 2026-10-18): the rules, palette, materials, lighting and characters are in `docs/art/STYLE.md`, which wins over the older desk-top notes in this section; the look-dev that set it is in `assets-src/diorama_lookdev/` and `docs/art/diorama/`. The earlier direction, kept for its readability rules and the Blot (where it asks for foil, metal or purple specular, STYLE.md's paper-not-plastic rule wins: only water and magic shine): **Papercraft stop-motion** (from the GDD): a tactile desk-top diorama. Everything looks cut, folded and glued from recycled office supplies on a green self-healing cutting mat, lit by bright desk light; the corrupted side is wet purple ink.

- **Materials.** Kraft paper and corrugated cardboard (roughness about 0.85, subtle height maps for the corrugation, detail normal maps for paper fibre), translucent creased edges (subsurface transmission), foil for rivers and armor, tape and PVA glue for hazards. The Blot: a vertex-displacement shader with saturated purple specular for ink-drenched surfaces.
- **Palette.** Cutting-mat green and kraft brown for the board and the defenders, white pencil outlines for sockets, saturated purple for everything the Blot touches, one accent colour per tower.
- **Animation.** Characters and projectiles step at 12 fps like stop-motion (stepped keyframes, no continuous interpolation) while the camera renders at 60.
- **Readability.** Silhouette and material tell the foe type (newsprint goblin, tissue-and-wire moth, cardboard orc, filter-paper shaman, shipping-box golem); each tier adds a visible part; tier 4 shows its specialisation.
- **Reference.** `docs/art/reference-wide-road.jpg` was a reference for the earlier fantasy look and is superseded: keep it only for HUD placement (lives, gold, wave counter, tower buttons). The road is masking tape on the cutting mat (owner, 2026-10-17; the dirt ribbon of #147 is dropped): taped once per stretch of road, one strip per straight run, built at load time, with paper trees, shrubs and desk clutter scattered where nothing is played (`docs/lessons/2026-10-17-papercraft-board-look.md`).

**Asset pipeline**

Track B, one asset end to end (owner rescope, 2026-10-11): the Scrap Goblin (the swarm foe, the Scamp in the old plan) goes through the whole pipeline before any other foe does. Its gate is 80 animated Scrap Goblins at 60 fps on the owner's phone in a native build; the pipeline steps are then written down for the next foe. The owner models it in Blender (Meshy was tried and dropped on 2026-10-13); the steps after the model:

1. Clean up: fix scale, put the origin at the feet facing forward, reduce to the triangle budget, bake the texture onto one map.
2. Armature: a small skeleton of about 15 to 20 bones (hips, spine, head, arms, legs, plus ears or a weapon if needed).
3. Skinning: automatic weights, then fix armpits and crotch.
4. Clips: walk, attack (a guard is the target), hit and die, each a short loop or one-shot.
5. Export for the way the unit is drawn in Godot (below).

| Unit | Godot setup | Why |
| --- | --- | --- |
| Foes (many) | Clips baked into a vertex-animation texture, played by a shader on a `MultiMesh` | `MultiMesh` cannot play skeletons |
| Bosses | Skinned glTF as `Skeleton3D` plus `AnimationPlayer` | Few on screen, so skinning is affordable |
| Towers | Separate parts animated in an `AnimationPlayer`, no skeleton | The head turns and the arm swings; nothing bends |

If the Scrap Goblin cannot reach 60 fps with vertex animation, the fallback is part animation and fewer animated instances (see Risks).


0. Foes: modelled by the owner in Blender in a papercraft look (flat cut-out shapes, visible fold lines and paper grain), then reduce to the triangle budget, bake one 512 px map per foe with colours matched to the shared palette, rig and make the clips; this is the Track B list above.
1. Shortlist CC0 sources for the papercraft look: paper, cardboard, kraft and cutting-mat textures (Poly Haven, ambientCG) and any low-poly or paper-style packs. Kenney and Quaternius medieval kits no longer fit the style and are placeholders only. Check each licence file; anything not clearly CC0 is out.
2. Map every unit to a pack model and write the gaps in `docs/art/GAPS.md` (see the gap plan below).
3. In Blender, build or remap faces to one shared palette texture; kitbash gap units from pack parts.
4. Export GLB (meshopt compression is optional in Godot; the importer handles plain GLB).
5. Record source, licence and edits in `assets/CREDITS.md`.

**Models.** The Three.js build used procedural primitives, then Kenney CC0 GLBs, and original models built with Claude and Blender (`assets-src/blender/`). The medieval towers and props from those sources are superseded by the GDD's papercraft towers and are not carried into Godot. In Godot the GLBs are imported as scenes; the owner's Blender models are the source, with primitives as placeholders.

**Claude Design:** design system (tokens, type, panels) first, in the papercraft style; then mobile screens (title, HUD, radial menu, Toolbox Tray, workshop tech tree, pause, game over); key art for the README and personal site; reference sheets per foe and tower tier. Claude Design covers 2D screens and reference art, not 3D models.

- **Rough silhouette sheets** (shape and colour only) for the 5 foes and 5 towers (Spool Guard, Guard Tent, Prism Spire, Thimble Mortar, Kitchen Mess Tent) come first and brief the models.
- **Final reference sheets** are drawn after the pack shortlist, so they follow what the packs can supply instead of asking for shapes that can't be sourced. The owner's foe models are briefed from the silhouette sheets.

### Asset gap plan _(Phase 6)_

Which units can come from where, and what has to be built. Nothing here is verified; `docs/art/GAPS.md` holds the result once the first models exist (its medieval pack shortlist is superseded).

| Unit | Likely source | Gap and fallback |
| --- | --- | --- |
| Scrap Goblin, Corrugated Orc, Cardboard Golem | The owner's Blender models in a papercraft look | A baked 512 px map per foe (1,024 px for the Golem), a rig for the Golem, walk, attack, hit and death clips baked to vertex animation sampled at 12 fps. The Golem is skinned. Licence: owned by the owner (all rights reserved), recorded in `assets/CREDITS.md`. |
| Razor Moth, Ink Shaman | Same pipeline | Flying wings (tissue paper and wire) need a flap clip; the Shaman needs a healing aura effect. |
| Towers (5, tiers 1 to 4; 8 specialisations on four of them) | Blender, built with Claude, from spools, tents, prisms and thimbles | Parts animated in an `AnimationPlayer`, no skeleton, at most 3 mesh parts each. Tier lights or paper tags show the tier; specialisations add a visible part. |
| Hero (Knight of Cardboard), planes, guards, Mess Tent | The owner's Blender models | The hero is skinned like a boss; paper planes and guards are small `MultiMesh` or scene instances (a guard needs idle, strike, fall and rise clips); the Kitchen Mess Tent is a fifth tower. |
| Terrain and props | The diorama built at load time from the map (terraces, corrugated cliffs, road beds, bridges, river) and the owner's Blender props (trees, rocks, dirt, grass), from the look-dev in `assets-src/diorama_lookdev/` | #324 to #326; one `MultiMesh` per prop type; sockets readable on the terraces. |
| Effects | Shaders and particles | The Blot shader, glue pools, thumbtacks, confetti, ink vortex, wax freeze; no new models. |

Rule: if a unit's silhouette is not distinct at zoomed-out view, change the model, not the readability pillar.

## Repo setup

```
papercraft-kingdom-defense/   # the repo is still psychic-bassoon
  godot/                 # the Godot project (project.godot at its root)
    sim/                 # pure GDScript: grid, mapgen, routes, waves, towers, foes, economy
    content/             # data: tower and foe defs, wave tables, lore text (JSON or Resources)
    render/              # scenes and scripts: terrain, foes (MultiMesh), towers, camera, effects
    ui/                  # HUD scenes and the Theme resource
    assets/              # imported GLB models, audio, textures
    tests/               # GUT tests, including the fixtures for the ported core
    export_presets.cfg   # iOS (Xcode project only), macOS, Windows and Linux presets (Godot reads it from the project root)
  fixtures/              # frozen JSON from the retired TypeScript sim for the ported core (prng, maps, routes), checked by SHA256SUMS (GDScript replay goldens live in godot/tests/goldens/)
  assets-src/            # .blend sources and raw packs (Git LFS)
  site/                  # the static page GitHub Pages serves (the web build is retired; it links to the releases list)
  scripts/               # repo checks, scripts/ios-run.sh (build and run on a connected iPhone) and balance tooling
  docs/                  # PLAN.md, design notes; docs/art/ has GAPS.md
  .github/
    workflows/           # pr-checks.yml, ci.yml, deploy.yml, release.yml
    ISSUE_TEMPLATE/, pull_request_template.md, dependabot.yml
```

- `godot/sim` never touches the scene tree: no `Node`, no `get_tree`, no `Engine` or `Time` singletons, no `randf`/`randi`. A lint script enforces it.
- All balance numbers live in `godot/content`.
- Conventional Commits, small PRs, `main` always releasable.
- Git LFS for binary sources; only compressed GLBs ship.
- MIT for code; each art source keeps its terms (CC0 packs; the owner's own models stay all rights reserved).

## CI/CD pipeline

| Workflow | Trigger | What it does |
| --- | --- | --- |
| `pr-checks` | PR opened, edited, updated | Conventional Commits on the PR title and commits; warns if no ticket is referenced. Already in place. |
| `ci` | PR and push to `main` | Pinned Godot and export templates (cached); `gdformat --check` and `gdlint`; the sim purity lint; GUT headless (fixtures, replay); the headless game time budget; the Linux desktop export, checked for its binary and `.pck` and run 300 frames headless through `scripts/run-godot-checked.sh` (fails on a non-zero exit, a timeout, or an `ERROR:`, `SCRIPT ERROR:` or `SHADER ERROR:` line), uploaded as `godot-desktop` for releases; with the `all-desktop` input (releases) also the Windows and macOS exports. The `ci` job also runs the repo's script checks (lint, Vitest, assets, frozen fixtures). |
| `deploy` | Push to `main`, only after `ci` passes | Publishes `site/index.html` to GitHub Pages: a short download page that links to the releases list (pre-releases included), with install steps for Windows, macOS and Linux (#356; the web build is retired, #318). Only the tip of `main` deploys, and the job checks that the live page has the releases link. The Three.js build is not served (to run it, check out the tag `web-three-final`). A red `main` never reaches the public site. |
| `release` | Tag `vMAJOR.MINOR.PATCH` | Re-runs the checks with the Linux, Windows and macOS exports, and publishes a GitHub Release with generated notes and the three builds attached as zips (the macOS app is ad-hoc signed, not notarized). |

**Versions follow phase gates** (semantic versioning, 0.x until launch). Tags so far: `web-three-final` (the last Three.js web build, created 2026-10-11 before the Three.js code was removed) and `v0.1.0-alpha.1` (2026-10-19, the first desktop pre-release; a tag with a `-` suffix is published as a pre-release). `v0.1.0` has not been cut yet; each later gate bumps the minor version. Notes come from Conventional Commits, so commit messages are the changelog.

**What CI can and can't prove**
- CI checks: lint, formatting, determinism (the fixtures for the ported core, then replay goldens), sim rules, the asset size budget, `assets/CREDITS.md` coverage for every GLB, and that the Linux export runs 300 frames with a clean log (scripts, resources and shader compiles that log an error).
- CI has no GPU: the exported Linux build runs headless (no rendering), so fps and draw calls are not measured in CI.
- 60 fps with 80 foes on a mid-range phone stays a manual check at the Phase 5 gate. Record device, fps and seed in the PR.

**Hygiene**
- Pin the Godot version and export templates (`.godot-version`), so local, CI and deploy match; cache the templates.
- Dependabot for GitHub Actions. Godot is upgraded by hand with a perf check.
- Least-privilege `permissions` on every workflow, `concurrency` to cancel superseded runs, no secrets in the repo.
- Skip Git LFS in CI (`assets-src/` is source only; only compressed GLBs ship).

**Repository settings** (not code, set once in GitHub): protect `main` with required checks (`Conventional Commits`, `ci`), squash merge only, linear history, delete branches on merge, no direct pushes. These are two repository rulesets, one for `main` and one for `v*` tags. Repository admins can bypass the `main` rules only through a pull request, and are the only ones who can create release tags.

## Gameplay changes

From the 2D prototype (the ported base) to the GDD design.

| Area | Prototype | Papercraft Kingdom Defense |
| --- | --- | --- |
| Map | Random path on a 9×13 grid | A seeded valley of 32×20 cells (owner, 2026-10-18, #320) with curved routes the sim walks (#321), terraces, regions and a river with guarded bridges (#322, #323). Before that: a seeded cutting-mat board of 16×11 cells (was 22×16) with three levels, 12 to 15 sockets of 2x2 cells (the generator gives 12 on about three maps in four), a Heartstone footprint, river, tape and glue hazards. The ported road generator (a main road and a detour) is the first layer, made size-aware; its 9×13 output stays pinned by the frozen fixtures. |
| Building | Any free cell | Pre-etched sockets; a radial context menu |
| Towers | 4 types, 3 levels | 4 archetypes, tiers 1 to 3 plus a tier 4 specialisation each (8 specialisations) with an active and a passive ability; targeting priorities |
| Foes | Scout, walker, tank, boss | Scrap Goblin, Razor Moth (flying), Corrugated Orc, Ink Shaman (support), Cardboard Golem (boss) |
| Player power | Build and sell | Plus the Knight hero and three global spells |
| Economy | Gold per kill and per wave | Buttons in a run; Golden Staples between runs, spent in a workshop tech tree |
| Waves | Endless, boss every 10 | Waves with a Cardboard Golem boss; call early for a bonus. Chapters and story cards are dropped for now. |
| Feedback | Flat 2D effects | Stop-motion animation at 12 fps, paper and ink shaders, decals for spells |
| Progress | Best wave in local storage | Golden Staples and the tech tree saved between runs, best wave per seed |

## Milestones

**Ticket labels.** The board's old labels `phase-3` (Art and UI), `phase-4` (Lore and chapters) and `phase-5` (Polish and launch) map to the new phases 6, 7 and 8 (the old `phase-4` 'Lore and chapters' is now 'Depth', since chapters are dropped); new labels `phase-6` to `phase-8` are added and the old art tickets (#89 to #97) are relabelled `phase-6`. The Three.js terrain ticket #108 is closed as done in TypeScript; the Godot terrain is part of Phase 5. New Godot tickets use `phase-3` onward with the new meaning from the day the move is merged.

Each phase ends with a gate that must pass before the next starts (exception: the Phase 5 greybox runs in parallel with Phase 4, see Phase 5; the Phase 5 gate itself still waits for the Phase 4 gate). Phases 0 to 2 were built in TypeScript and Three.js and are complete; the Godot track starts at Phase 3.

| Phase | Work | Gate |
| --- | --- | --- |
| 0 · Repo and pipeline (done) | Vite + TS + Three.js scaffold, CI, Pages deploy | An empty scene deploys from `main` |
| 1 · Simulation port, TypeScript (done) | Rules in `src/sim`, seeded RNG, 30 Hz tick; Vitest coverage | A headless run replays exactly from its seed |
| 2 · 3D greybox, Three.js (done) | Angled camera, picking, models, DOM HUD, landscape | Plays as well as the 2D prototype on a phone (owner-tested on iPhone) |
| 3 · Godot foundation | Godot project, pinned version, web export (single-thread), CI (gdlint, gdformat, GUT, export, size), Pages deploy, fixtures exported from the TypeScript sim | An empty Godot scene deploys from `main` and loads on the owner's iPhone Safari; download size measured and budgeted |
| 4 · Sim in GDScript, designed from the GDD (done 2026-10-13) | PRNG, road generator and routes, game core (done); sockets and elevation, foes and waves, combat core and economy for the first towers and foes, replay goldens, headless run | **The same seed and commands replay to the same result** (goldens), the ported core still matches its fixtures, and `src/` is gone (done) |
| 5 · Play in Godot (greybox started in parallel with Phase 4, 2026-10-11) | Greybox board, picking, foes, towers, HUD and loop (steps A1 to A6); papercraft terrain tiles, camera pan, pinch and tilt, the radial menu | **A full run to the boss at 60 fps on the owner's phone with 80 foes**, every action reachable in landscape |
| 6 · Art and ambience (Hand-Folded Fantasy) | The diorama terrain, road beds, bridges and scatter; the painterly paper material; lighting and post; the camera and minimap for the big map; the platform switch; the Scrap Goblin through the pipeline first, then the other foes, the hero, the towers and guards in the chunky style; stop-motion stepping at 12 fps; Claude Design HUD and Theme (#316) | All foes, towers, guards and the hero use final models, each distinct at the overview zoom; performance budget met on the iPhone |
| 7 · Depth (the rest of the GDD) | Razor Moth and anti-air, Ink Shaman, the Guard Tent and blocking, tier 4 specialisations with actives and passives, the hero, global spells and the Toolbox Tray, the Kitchen Mess Tent, the Camp Cook, the Messenger Crow, the 32×20 valley map, curved routes, terraces and the river with bridges held by guards (#320 to #323), hazards (tape, PVA puddles) | Every new element has GUT tests, a replay golden with it on, and a balanced headless run; the owner plays a full set of waves |
| 8 · Meta, polish, launch, native | Golden Staples tech tree and saved progress, audio, performance pass, README with key art; iOS export (Android optional) | Native builds on two real iPhones (TestFlight) and on Mac and PC |

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
- [x] **Go/no-go:** on the owner's iPhone Safari the export's download size, start time, memory and an 80-instance stub scene are within the budget set here. If not, stop and take the fallback in Risks (keep Three.js for web, Godot for native only) before any Phase 4 work.
  - **Result (2026-10-10): go.** The stub runs on the owner's iPhone 15 Pro (60 Hz). The export is 11.67 MB gzipped (`index.wasm` 10.15 MB, `index.pck` 1.40 MB). Download budget: 14 MB gzipped, as CI enforces (raised to 18.5 MB on 2026-10-18 for the music tracks). Not measured: start time and memory in numbers, frame rate beyond "works", and any mid-range phone; the iPhone 15 Pro is a flagship, so the 60 fps target on a mid-range phone stays open for the Phase 5 gate. Phase 4 started before this was recorded, on the owner's instruction.

### Phase 4 · The simulation in GDScript, designed from the GDD

**Goal:** the simulation in GDScript for the first playable slice of the GDD, deterministic and tested. It started as a port of the prototype; since the GDD adoption (2026-10-11) the foes, towers, combat and economy are designed from the GDD, with the prototype's formulas as a starting point.

**Work breakdown** (test-first, one context at a time)
1. Done: PRNG (mulberry32 and `deriveRng`) on masked 32-bit integers, matching its fixtures.
2. Done: the road generator (main road and a detour; the game will use the main road only, see 5a) and the routes, matching their fixtures. This is the first map layer.
3. Done: game state, commands, the command queue and rejection events, the 30 Hz tick, the clock and the frame stepper.
4. Done: sockets and elevation: 12 to 22 sockets on non-road cells within reach of the road (their own random stream, so the road fixtures still match), three elevation levels by weight with the +15% range multiplier on level 2, `build` only on a socket, and a first golden written by the GDScript sim (`godot/tests/goldens`, `godot/tools`).
5. Done, except the Golem's split (it needs combat): foes, waves and economy: content for the Scrap Goblin, Corrugated Orc and Cardboard Golem (ground foes first), movement along routes, wave composition and scaling (from the prototype's numbers), Heartstone health, Buttons, early-call and wave-clear bonuses, game over. All numbers are starting points for the owner to tune. Calling a wave early while the previous wave's foes still walk lets those foes count toward the new wave's clear, so the earlier wave pays no clear bonus of its own (the prototype's rule). The Heartstone's health stops at 0.
5a. **Map v2** (GDD update, 2026-10-12; owner decisions the same day): (1) done: `kingdom_health` renamed to `heartstone_health` in code, HUD and docs; (2) make the road generator size-aware, parameterised by columns and rows and by whether it grows a detour (the game: no detour, one path from one spawn), with the 9×13 case with detours still checked against the frozen fixtures; the game uses a landscape 22×16 board, generated on the transposed grid (16 columns by 22 rows) and turned, so the road crosses the long side, then a new golden; (3) sockets become 2x2 footprint blocks that never overlap each other or the road, range measured from the block's centre; (4) the Heartstone's footprint; (5) a balance pass for the longer roads (wave pacing, tower reach in cells). The greybox follows in Phase 5 (the board render, camera fit and picking for 22×16).
6. Combat core: targeting priorities, damage and armor, tiers 1 to 3 of the Spool Guard (fast single target, physical), Thimble Mortar (splash) and Prism Spire (a continuous magic beam; the Corrugated Orc's armor makes it the counter), with damage types (physical, magic, true) and how armor applies to each, and one shared status model starting with slow (used later by rivers, tape and the specialisations). Tower and foe ids change to the GDD's here.
7. Determinism: a scripted bot, replay goldens for several seeds, and a headless CLI (`godot --headless`) that prints the map and the wave log.
8. Cleanup (done, #211), once step 6 no longer needs the TypeScript formulas: remove `src/`, the fixture exporter (`scripts/export-fixtures.ts` and its staleness test), the TypeScript sim CLI (`pnpm sim`, replaced by the `godot --headless` CLI of step 7), the `tsconfig.sim.json` lint step, the `src/**` blocks in `eslint.config.js`, the Vitest `src` include, and the fixtures nobody uses (`damage.json`, `waves.json`, `scaling.json`, `replays.json`). Keep `prng.json`, `maps.json` and `routes.json` frozen, and replace the staleness test with a committed SHA-256 of those three files checked in CI, so "never regenerated" is enforced. Update `CLAUDE.md`, the README and `fixtures/README.md` in the same PR.

Flying foes, support foes, the Guard Tent and blocking, tier 4, the hero, spells and hazards are Phase 7. Their content flags and commands are added then.

**Gate checklist**
- [x] The same seed and commands give the same result: replay goldens for six games (won, lost and stopped runs, every strategy, a tent game) pass, and change only by a reviewed balance change (#214, #227).
- [x] The ported core still matches its fixtures (PRNG, maps, routes): GUT compares them and `fixtures/SHA256SUMS` plus a CI diff guard keep them frozen (#212).
- [x] The sim imports nothing from the scene tree (`pnpm check:sim-purity` in CI).
- [x] A whole headless bot game (20 waves, about 25 minutes of play) finishes within a time budget on CI (#215): 5 s measured on the CI runner (5 s on a laptop), budget 60 s, so it catches a sim several times slower. Measured 2026-10-13.
- [x] `src/` and the unused fixtures are removed (#211).

### Phase 5 · Play in Godot

**Goal:** the game playable on the phone in Godot: a full run to the boss, in the GDD's interaction model.

**Rescope (owner decision, 2026-10-11): greybox first, in parallel with Phase 4.** Phase 5 starts now as a greybox while the rest of the sim port continues. This is a deliberate exception to "work one phase at a time". The risk is low because the greybox only reads sim snapshots and sends commands, so it cannot change the sim's results; if a sim change breaks a greybox scene, the greybox adapts. The Three.js renderer and HUD are already gone; the TypeScript sim and the fixture exporter were removed in Phase 4 step 8 (they stay in the tag `web-three-final`). Track C (terrain art) is parked at the proof of concept (Blender tiles plus world-space Godot shaders and scatter) and returns as the art pass over A1, with the terrain code reading the real map; how the path is drawn is decided in Phase 5.

| Step | You get | What it teaches |
| --- | --- | --- |
| A1 Board | The real `MapGen` map as flat tiles (cubes for plots, a strip for the road), a camera rig, a `@tool` preview with a seed field | Scenes, `Node3D` transforms, `@export`, `@tool` |
| A2 Picking | Tap a cell: highlight it, open a build menu, send a build command | Input events, a raycast onto the board, signals |
| A3 Foes | Capsules walking the routes, one `MultiMesh` per foe type, smooth movement between ticks | `_process` against the fixed tick, interpolation, `MultiMesh` |
| A4 Towers | A tower scene with its look (mesh, colours, range-ring style) in a `.tres` resource and its stats read from `godot/content` (never a second copy of the numbers), a range ring, shots | `PackedScene`, custom resources, the Inspector |
| A5 HUD (the Heartstone-health, wave and game-over parts wait for the combat and wave ports) | Buttons, Heartstone health, wave, speed and pause, game over, landscape layout | `Control` nodes, containers, anchors, Theme |
| A6 Loop (waits for the wave and economy ports) | Waves, a win and lose screen, 1×/2×/3× speed | Game flow, scene switching |

A1 and A2 can start now (map generation, game state and commands are ported); A3 onward lands as the combat and wave ports merge. **Limits of the exception:** the greybox only calls `Game.create`, `Game.submit` and `Game.tick`, reads state through read-only accessors, and drains events; it never touches `rng`, `route_rng` or `pending`, never assigns to or calls a mutating method on a field of the state (plain reads are allowed until the read-only accessors exist), and it never edits `godot/sim`, `godot/content` numbers or `fixtures/`. Any sim API the greybox needs (a read-only snapshot, the previous foe positions for A3 interpolation, event draining) is added by a Phase 4 sim ticket with GUT tests and deep review, never inside a greybox PR. A CI check rejects `godot/render` and `godot/ui` code that reaches into those fields (added with A1). Each step is built by Claude and read by the owner with the Remote scene tree open, then tweaked in the Inspector. A Godot MCP server that can launch the project, read its output and take screenshots (checked with Godot 4.7) lets Claude see the result without copying logs by hand.

**Work breakdown**
1. Terrain from the map as modular 1 m tiles (the cutting mat, the cardboard rise, tiered cliffs), sockets as etched circles, spawn and Heartstone markers; the path is drawn as masking tape (decided 2026-10-17, replacing the ribbon idea of #149 and #147). The sim polyline stays the truth for movement, range and hits. _Superseded on 2026-10-18 by the diorama terrain, road beds and scatter (#324 to #326)._
2. `MultiMesh` foes with interpolation and baked vertex animation sampled at 12 fps (decided by the Scrap Goblin spike, #157), towers with tiers and idle/fire animation, selection highlight and range ring.
3. Done: camera: landscape framing, one-finger pan with rubber-band edges, two-finger pinch (and the mouse wheel and trackpad pinch) that zooms and tilts between 65° and 30°, a tap that is not a drag; tap picking to a socket, a tower or a cell (the cell decides, not the visible art).
4. Control-node HUD: Buttons, Heartstone health, wave, the radial context menu (48 pt targets, offset above the finger), speed, pause, next-wave popup, game over, landscape prompt.
5. Effects (shots, splash, slows), reduced motion, audio after the first tap.
6. Performance pass on the phone: 80 foes at 60 fps within the draw-call and triangle budget. The tower caps assume 22 towers at the top tier, the most sockets a map has; the GDD's guards, paper planes and hero are not in the tower cap: guards and planes count in the frame's headroom outside the terrain (40k) and scenery (32k) caps, the hero like a boss: measure the real late-game tower count from a seeded replay, and if it is higher, batch towers with one `MultiMesh` per tower type, tier and part so draw calls scale with types, or decide a tower cap as a design change.

**Gate checklist**
- [x] 60 fps with 80 foes on the owner's phone: the owner ran `?stress=200&fps` on an iPhone (2026-10-15) and got 60 fps from about 2 seconds after loading (the first second is slow: shader and model warm-up plus the first fill of the crowd), with 200 foes, 2.5 times the gate's 80 (model and draw calls not recorded; the headless browser counts 52 draws with 80 foes). A full run to the boss with the real towers is still to play; the stress crowd has no towers or waves.
- [x] Every action is reachable in landscape; tap targets at least 44 px on an 844x390 phone (`test_hud_flow.gd` checks the overlap and the size; the GDD asks for 48 pt, which stays a Phase 6 polish item).
- [ ] The path, sockets and foes line up by eye on the phone: foes stay on the path, hits land on visible foes at corners.
- [x] The replay goldens still pass.
- [x] (Interim, greybox) A1 to A6 play a full run in Godot with boxes and capsules, before any final art.

**Phase 5 status (2026-10-13):** the two open items need the owner's phone and cannot be closed by tests: the 60 fps run with 80 foes, and the path, sockets and foes lining up by eye.

**Phase 5 status (2026-10-15):** the 60 fps check passed on the owner's iPhone with 200 foes, after a slow first second. Left: the path, sockets and foes lining up by eye on the phone.

**How to run the phone checks (2026-10-15, #241; the web URL went with #318, and #319 brings them back as `--stress=80 --fps` flags and a debug menu in the native build, so until then they cannot run on the phone):** the steps were: open the deployed site with `?stress=80&fps` (for example `https://juanpalopez.github.io/psychic-bassoon/?stress=80&fps`). Do not build towers during the check (kills make the crowd refill one foe a tick at the spawn point). The page keeps 80 foes walking (goblins, orcs and a golem now and then, made by the sim's own spawner, no towers or waves, the Heartstone never dies) and shows `fps, draws, foes, tris` at the bottom. Read the fps after 20 seconds, once with a mouse-free phone held in landscape, and record device, fps and draw calls here. For the by-eye check, play a run with the intro (`?tour=0` skips it) and look at the road, sockets and foes at the corners. The draw-call budget is 120; the headless browser shows 52 draws with 80 foes.

### Phase 6 · Art and ambience (Hand-Folded Fantasy)

**Goal:** the final look in the Hand-Folded Fantasy style (`docs/art/STYLE.md`), on native builds, on the bigger valley map. Rescoped on 2026-10-18 (epic #316): the desk-top board (cutting mat, tape road, desk clutter) is replaced by a boundless diorama.

**Work breakdown**
1. Rules and reference: the style guide, these plan and `CLAUDE.md` updates, the decision records and the look-dev (#317).
2. Platforms: drop the web build; export for iOS and desktop on Forward+ and Mobile; `scripts/ios-run.sh` (#318); the web shell's jobs move into the game (#319).
3. The diorama: terraces built from the map with boundless edges (#324), road beds and bridges along the curved routes (#325), scenery scatter by region (#326).
4. Look: the painterly paper material (#327), lighting and post (#95).
5. Camera and navigation for the 32x20 map: pan, start near the spawn, overview zoom (#328, #313); off-screen indicators and a minimap (#329).
6. Characters in the chunky style: the Scrap Goblin through the whole pipeline first (#157), then the Corrugated Orc (#330), the Cardboard Golem (#331), the Ink Shaman (#332), the Razor Moth (#333) and the Knight of Cardboard (#334). Record each in `assets/CREDITS.md`.
7. Towers, guards and the Camp Cook restyled to the guide, with tier parts and specialisations as visible changes (#300).
8. Stop-motion stepping at 12 fps for characters and projectiles (in place since Phase 5).
9. Claude Design: the HUD and Theme (done in #282), restyled only where the new look needs it.
10. Budget re-check on the iPhone and the gate (#97).

**Gate checklist**
- [ ] All foes, towers (tiers 1 to 3), guards and the hero use final models in the new style, each distinct at the overview zoom.
- [ ] Every gap in the asset gap plan has a fallback.
- [ ] Performance budget met on the owner's iPhone in a native build (Mobile renderer); the replay goldens still pass.

### Phase 7 · Depth (the rest of the GDD)

**Goal:** the GDD's remaining mechanics on top of the finished slice, each behind a content flag.

**Work breakdown**
1. Flying: the Razor Moth, its line to the Heartstone, an anti-air flag on towers.
2. Support: the Ink Shaman (healing and speed buffs) and a support-first targeting priority.
3. Blocking and melee: foes attack and units have health; the Guard Tent and its guards (done 2026-10-13, #220, #222; the Kitchen Mess Tent too, #224).
4. Tier 4: the eight specialisations with one active and one passive each; a command to choose one and one to activate an ability (framework and the Crossbow Ballista in #273; see `docs/lessons/2026-10-16-tier4-framework.md`).
5. The hero: the Knight of Cardboard (movement command, Rally Cry, Blade Whirl), moved anywhere walkable on the map, a little like an RTS (owner, 2026-10-18; #275, #335).
6. Global spells and the Toolbox Tray: PVA Glue Trap, Falling Thumbtacks, The Crafter's Eraser, with Crafting Energy.
7. Map depth: the 32x20 valley (#320), curved routes the sim walks (#321), the terrain layer with terraces, regions and a river (#322), bridges held by guards posted on them (#323, owner 2026-10-18), tape strips and PVA puddles (#277). Drawbridges and levers stay dropped (owner, 2026-10-12).
8. Balance: headless runs for each new foe and tower; each foe needs at least two answers at tier 3 and a third from a specialisation.

**Gate checklist**
- [ ] Every new element has GUT tests and a replay golden with its flag on.
- [ ] With the flags off, the sim still equals the Phase 4 goldens.
- [ ] A balanced headless run for each foe and each specialisation.
- [ ] The owner plays a full set of waves and calls it fun.

### Phase 8 · Meta, polish, launch, native

**Goal:** the between-run progression, then ship it and take it native.

**Work breakdown**
1. The workshop: Golden Staples, the permanent tech tree (skills, base stats, new blueprints) and saved progress behind one persistence adapter (a file on iOS and desktop).
2. Audio and music (decision from the open questions).
3. Performance and loading pass on real devices; 30 fps fallback with reduced effects.
4. README with key art and a short play guide; link from the personal site.
5. Final licence check: `assets/CREDITS.md` complete, MIT for code; each art source keeps its terms (CC0 packs, the owner's own models).
6. iOS export: Apple Developer account, signing, input and safe areas, store listing. Android only if the owner asks.

**Gate checklist**
- [ ] A run earns Golden Staples that survive a restart and change the next run.
- [ ] Native builds run on at least two real iPhones (TestFlight, or local installs while the owner stays on a free Apple ID) and on Mac and PC (the web build was dropped on 2026-10-18).
- [ ] README and credits complete.

## Risks and open questions

| Risk | Fallback |
| --- | --- |
| The Godot web build is too heavy or slow to start on a phone _(retired with the web build, 2026-10-18)_ | Measure in Phase 3 before porting; trim export (disable unused modules with a custom build), lazy-load assets, loading screen. If it is still too heavy, fall back to the Three.js build for web and use Godot for native only. |
| iOS Safari limits (memory, audio, no threads) break the export _(retired with the web build, 2026-10-18)_ | Single-threaded export, Compatibility renderer, test on the real phone every phase; the Three.js build can be redeployed from the tag `web-three-final` if the Godot web build fails on a target phone |
| The sim changes by accident | GDScript replay goldens with float bits, written by the sim itself; a golden changes only by a reviewed balance change, or by a reviewed sim change that a decision record names (#320 and #321). The ported core keeps its TypeScript fixtures, never regenerated. |
| Floating-point or integer differences (integer division, 32-bit wrap, rounding) | Use only `+ - * /`, `sqrt`, `floor`; divide by floats; mask integers to 32 bits after every operation; `int(floor(x + 0.5))` for `Math.round`; golden-value tests for the PRNG and `deriveRng`; hex-string fixtures compared with `==` |
| The DOM HUD is lost (screen readers, text scaling, crisp text, `prefers-reduced-motion`) | Control nodes with a Theme and large text; read reduced motion through one platform adapter (an in-game setting, #319; a native plugin may later read the iOS setting); accept the accessibility loss and record it |
| Part animation and skeletons fight `MultiMesh` (each part or material is another draw call; skinned meshes cannot use MultiMesh) | One MultiMesh per foe type and part, count draw calls in the Phase 5 gate; bake animation into vertex shaders or use a few skinned bosses only |
| The TypeScript reference outlives its use | Phase 4 step 8 removes `src/` and the unused fixtures once the GDScript combat lands |
| The greybox (Phase 5) builds on a sim that is still being ported | The greybox only reads snapshots and sends commands; sim API changes are caught by its tests and by CI; the replay goldens decide any disagreement |
| Animation for many foes is too slow on phones | Baked vertex animation on `MultiMesh` first; fall back to part animation and fewer animated instances; skeletons only for bosses (towers use part animation, counted in the draw-call budget) |
| The owner's foe models do not read as paper at zoomed-out view | Flat cut-out shapes with fold lines and paper grain baked onto one paper texture, or layered flat shapes in Blender; checked against the silhouette sheets |
| The path drawing drifts from the sim polyline (foes look off the path or hits look wrong at corners) | The sim polyline decides hits, range and distance; the Phase 5 gate checks the path by eye on the phone |
| The angled camera hides foes behind towers | Short towers, outlines, slight camera rotation |
| Tap targets get small at full zoom-out | The overview zoom is for reading the map; a tap there zooms in first, and building happens only at a zoom where a 2x2 socket is at least 44 pt (#328) |
| Godot web export cannot be tested headless in CI _(retired with the web build, 2026-10-18)_ | Software GL (SwiftShader) in Chromium for the smoke test; fps stays a manual phone check |
| A broken `main` reaches GitHub Pages _(retired with the web build, 2026-10-18)_ | `deploy` depends on `ci` passing; protected `main`; roll back by redeploying the last good tag |
| The GDD is large (hero, spells, tech tree, eight specialisations) and has few numbers | Phase gates and content flags: only the slice in Phase 4 and 5 first; the rest in Phase 7 and 8; every number is tuned by headless runs |
| New foes and specialisations break the balance | Content flags; the replay goldens keep the base game identical with the flags off; headless balance runs per foe |
| The diorama (terrain, scatter, post) is too heavy for the Mobile renderer on a phone | Chunked and culled terrain, one `MultiMesh` per prop type, baked contact shading instead of SSAO, a quality setting; measure on the iPhone in each art PR and at the gate (#97) |
| The 32x20 map makes runs long and taps small | The camera starts near the spawn and pans; taps at the overview zoom zoom in first (#328); wave pacing re-tuned (#237) |
| Curved routes churn the replay goldens | Re-record them as reviewed changes in #320 and #321 (named in `docs/lessons/2026-10-18-valley-map.md`); the ported grid path and its frozen fixtures stay untouched |
| No shareable web link for playtesters | Desktop builds on GitHub Releases; TestFlight once the owner joins the Apple Developer Program |

- [x] Repo name and whether it is public from day one: public from day one, repo `psychic-bassoon`, codename Project Slag.
- [x] Embed the game in the personal site, or link out: link out.
- [x] Landscape only (owner decision).
- [x] Engine: Godot 4 (owner decision, 2026-10-10); native only from 2026-10-18 (iOS, then Mac and PC; the web build is dropped).
- [ ] Music: commission, CC0 tracks, or skip for v1
- [x] Pages: `main` was the live "latest" web build until 2026-10-18; since #318 Pages serves a page that links to the latest release, and tags create the GitHub Releases with the desktop builds.
- [x] Testing on a phone before merge: a local build installed over the cable (`scripts/ios-run.sh`, #318); TestFlight needs the paid Apple Developer Program (the owner's call).
- [x] Download budget for the Godot web build _(retired with the web build in #318; the asset budget stays)_: 14 MB gzipped (11.67 MB measured at the Phase 3 gate); trim the export if it grows. Raised to 18.5 MB on 2026-10-18 for the three full-length music tracks (about 5.8 MB of Vorbis that does not gzip); the asset budget went from 6 MB to 9 MB. Re-set after the iPhone measurement (ticket #124).
- [x] Name: Papercraft Kingdom Defense (owner, 2026-10-11). The repo stays `psychic-bassoon` and the board Project Slag. The code, project name, web shell, manifest and package were renamed on 2026-10-13 (#163).
- [x] Meshy: tried and dropped (owner, 2026-10-13): the generated models were not good enough, so the owner models every foe in Blender. No generated models are used; the earlier paid-plan rules no longer apply.
- [ ] Vertex animation on `MultiMesh` for many animated foes: works on iPhone Safari within budget? Decided by the Scrap Goblin spike (ticket #157); fallback is part animation and fewer animated instances.
