# Papercraft Kingdom Defense

A papercraft stop-motion tower defense for phones and tablets, in the browser first and as a native iOS app next (Android only if wanted later). **Godot 4 + GDScript**, web export first (GitHub Pages). The design is the GDD in `docs/GDD.md` (adopted by the owner on 2026-10-11); the old Scrapline medieval design and the 2D prototype are no longer the rules target. The Three.js game that shipped Phases 0 to 2 is retired (last build: the tag `web-three-final`); the TypeScript simulation that held the formulas is removed from the tree (Phase 4, step 8) and stays readable in that tag (`git show web-three-final:src/sim/...`). The game is renamed Papercraft Kingdom Defense; the repo stays `psychic-bassoon`, and the code still says Scrapline until the rename ticket.

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
mkdir -p build/web && godot --headless --path godot --export-release "Web" ../build/web/index.html   # web export
python3 -m http.server -d build/web                  # serve the export; open on a phone over LAN
```

Repo checks and tooling (TypeScript and Node):

```bash
pnpm install
pnpm test         # Vitest (repo scripts)
pnpm test:e2e:godot   # Playwright smoke test of the web export in build/web
pnpm serve        # serve build/web on your LAN (port 8080), to open on a phone
pnpm check:assets # godot/assets against assets/CREDITS.md
pnpm check:fixtures # the frozen fixtures against fixtures/SHA256SUMS
pnpm lint         # Prettier check + ESLint + tsc --noEmit
pnpm format       # Prettier --write (run before committing)
```

## Working rules

- **Work one phase at a time.** Implement only the current phase from `docs/PLAN.md`, then stop and report whether its gate passes. Don't start the next phase or add features from later phases. **Exception (owner, 2026-10-11):** Phase 5 starts now as a greybox, in parallel with the rest of Phase 4. The greybox only reads sim snapshots and sends commands, so it cannot change parity; it never edits `godot/sim` or `fixtures/`. Art, lore and everything else from Phases 6 to 8 still wait, except Track B: ticket #157, the Scrap Goblin (the old Scamp) through the asset pipeline. Sim API the greybox needs (a read-only snapshot, previous foe positions, event draining) is added by Phase 4 sim tickets with tests and deep review, never inside a greybox PR; `godot/render` and `godot/ui` use only `Game.create`, `Game.submit`, `Game.tick`, read-only accessors and drained events, and never `rng`, `route_rng`, `pending` or field assignments on the state (a CI check enforces it from greybox step A1, ticket #156; it scans `godot/render`, `godot/ui` and `godot/main.gd`; plain reads of state fields are allowed until read-only accessors exist).
- **The design is the GDD; numbers start from the prototype.** Port before inventing applies only to the ported core (PRNG, road generator, routes), which stays equal to its fixtures (made by the retired TypeScript sim); those fixtures are frozen and never regenerated, and `fixtures/SHA256SUMS` enforces it in CI, and the game state, commands and tick are covered by GUT tests. Foes, towers, combat and economy are designed from `docs/GDD.md` and tested in GDScript; where the GDD gives no number, start from the prototype's (`web-three-final:src/content`) and tune with headless runs. From the combat port on, GDScript replay goldens (written by the sim itself, with float bits) are the regression check.
- **Keep `main` deployable.** Run the checks for the code you touched before every commit: `pnpm lint && pnpm test` for the repo's TypeScript and Node scripts, and `gdformat`, `gdlint`, GUT and the web export for Godot.

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
- Player actions reach the sim only as commands (`build`, `upgrade`, `sell`, `launchWave`), never by mutating state directly.
- All randomness goes through the seeded PRNG in `godot/sim/rng.gd` (mulberry32 on 32-bit integers). The same seed plus the same commands (plus, from Phase 8, the run's frozen meta-loadout: the tech-tree state at the start of the run) must replay identically; the ported core must give values equal to the TypeScript fixtures. Sockets, elevation and other new map layers draw from their own derived streams (`deriveRng`), never the map stream, so the frozen fixtures keep matching.
- All balance numbers (cost, damage, range, rate, hp, speed, rewards, wave scaling) live in `godot/content`. Logic files contain no magic numbers.
- A map is a grid (the GDD now says 22 columns by 16 rows; the code still builds 9 by 13 until the Map v2 tickets land) with one route from the one spawn point to the Heartstone (owner, 2026-10-12: no detour or branching for now; several spawn sources are a backlog idea), 12 to 22 sockets for towers (2x2 cells each in the GDD), and three elevation levels. The road generator and routes are ported (a main road and, until Map v2 turns it off, a detour); sockets and elevation are new map layers on top of it. Foes pick a route; towers target across routes. The sim keeps the grid, the polyline routes and the sockets as plain data; Godot nodes (`GridMap`, `Path3D`) only draw them.
- Game speed (1×/2×/3×) means more sim ticks per frame, never a bigger tick.
- For value parity with TypeScript use only `+ - * /`, `sqrt`, `floor`, `min`, `max`, `abs`. Traps: `/` on two integers is integer division in GDScript (divide by a float); keep PRNG values in [0, 2^32) and mask after every `*`, `+` and `^` (replacing `Math.imul` and `>>>`); `Math.round` becomes `int(floor(x + 0.5))`; avoid trig and `round`. Fixtures and goldens keep large integers and floats as hex bits and are compared with exact `==`.

### Domain-driven design

- `godot/sim` is the domain. Split it into bounded contexts by game concept (for example map, waves, combat, economy), one folder each, with a small public entry class. Contexts talk through commands, events and snapshots, not by reaching into each other's internals.
- Use the ubiquitous language from the lore table in names, types and tests (Scrap Goblin, Spool Guard, Prism Spire, Heartstone health, wave, Buttons, Golden Staples). No synonyms for the same concept. Display names and lore strings live in `godot/content` and the Naming table; a rename changes those, not the logic.
- Model state as plain data and pure functions. Value objects are immutable; the sim state is the single aggregate root that only commands change.
- Domain code never depends on infrastructure. `render`, `ui`, storage and the browser are adapters that read snapshots and send commands.

## Rendering and performance

- Target: 60 fps with 80 foes on a mid-range phone. Budget: under 120 draw calls, about 150k triangles, DPR capped at 2. The web export uses the Compatibility renderer (WebGL2) and the single-threaded build.
- One `MultiMeshInstance3D` per foe type. Don't create a node per foe.
- Camera: perspective, about 35° FOV, pitched about 55° by default and tilting between 30° and 65° with the pinch, landscape framing (the board is drawn turned so the road runs left to right; the sim is untouched, one script converts sim cells to world positions); pinch zoom and pan are clamped so grid cells stay at least 40 px wide, except that the whole board must always fit.
- Models come from glTF/GLB. Sources, in order of preference: the owner's Blender models (`assets-src/blender/`, some made with Claude) and CC0 packs as placeholders. AI mesh generators such as Meshy are not used (owner decision, 2026-10-13: the models were not good enough); a Blender model scripted with Claude counts as the owner's own. Keep a simple fallback mesh for any unit whose file is missing.
- Foes and towers are animated: foes walk, attack (a guard of the Guard Tent), get hit and die; towers idle and fire; guards idle, strike, fall and rise. The sim reports a foe being held (`FOE_ENGAGED`) and a guard falling or rising, not each blow, so the attack and strike clips loop while a foe is engaged until the foe dies, the guard falls or the foe is released; a per-blow event is added only if that looks wrong. `MultiMeshInstance3D` cannot skin, so foes with many instances play baked vertex animation in a shader, with the clip index and start time per instance in instance custom data. Render keeps a dying instance alive until its death clip ends, driven by the death event. Bosses are skinned glTF (`Skeleton3D` plus `AnimationPlayer`); towers animate separate parts in an `AnimationPlayer` with no skeleton. Triangle budgets (whole model per level): foe 800 to 1,200 with its own baked 512 px map, tower 1,500 to 3,000 on a shared atlas, boss 3,000 to 5,000 with a 1,024 px map, under frame caps of foes 80k, towers 45k, terrain and effects 20k and one boss 5k in total (see the plan; the tower cap assumes 20 towers, to be measured). One foe, the Scrap Goblin, goes through the whole pipeline first (the owner's Blender model, rig, clips and baked vertex animation; gate: 80 animated Scrap Goblins at 60 fps on the owner's phone) before any other foe does. Count draw calls and triangles with animation on, towers included.
- Terrain is built from the sim map at load time from modular 1 m tiles (a `GridMap` or a `MultiMesh` per tile type) with papercraft materials (kraft paper, cardboard, the cutting mat, foil, tape; see the plan). Sockets draw as etched circles. How the path is drawn (a printed line, tape or the earlier ribbon idea) is decided in Phase 5; the sim's polyline routes stay the truth for movement, range, hits and tap picking. Terrain code reads the map snapshot only.
- Reuse meshes and materials, free nodes you remove, and avoid allocating objects every frame.

## UI

- The HUD is built from Godot `Control` nodes with one Theme resource that mirrors the Claude Design tokens. Never hard-code colours in scenes or scripts.
- The game is landscape only (owner decision). A phone held upright shows a "turn your phone" prompt (in the web export's HTML shell) and the game pauses. Every action is reachable by the thumbs holding the phone, with tap targets of at least 44 px.
- Respect reduced motion: read the setting through one platform adapter (on the web, `prefers-reduced-motion` via the HTML shell and `JavaScriptBridge`; on iOS Godot may have no API for Reduce Motion, so plan an in-game setting or a small native plugin) and turn off screen shake and reduce particle effects. The landscape prompt and fullscreen button live in the web shell only.
- Start audio only after the first tap (browsers block it before).

## Testing

- Every sim module gets GUT tests: map generation (road valid, routes valid, sockets valid, reproducible from its seed), wave composition, damage and armor, economy, and a full-run replay from a seed. The ported core is compared with `fixtures/`; from the combat port on, replays are compared with goldens written by the GDScript sim, and a golden changes only by a reviewed balance change.
- Fix the seed in tests; never depend on timing.
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

### Reviews

Every PR gets an adversarial review before it merges, scaled to its risk so reviews stay affordable. Reviewers are Claude subagents, never the author's own context.

- **Agent and rulebook:** the project agent `adversarial-reviewer` (`.claude/agents/adversarial-reviewer.md`) reads `docs/REVIEW-CHECKLIST.md`, which holds the tiers, checks, limits and report format. Keep the checklist in step with this file.
- **Tiers:**
  - **Skip:** Dependabot bumps with green CI, wording-only docs. Check CI and the title, then merge.
  - **Standard** (`sonnet`, the agent's default): most PRs, including pure-logic sim modules (`godot/sim`) (map generation, combat, economy, waves). They still need tests first, and a sim PR that touches seeds, randomness or the tick loop is deep.
  - **Deep** (`opus`, pass `model: opus`): workflows, determinism-critical sim code (the PRNG, the tick and command loop, the replay test, seed and snapshot handling), secrets, permissions, deploy or release, rule changes in this file. When unsure, take the higher tier.
- **When:** once the PR is ready and `ci` has run, not on every push. Run `gh pr checks <N>` first; reviewers do not repeat what green CI proved (lint, types, tests, build, size, smoke test, title format).
- **Input:** give the reviewer the PR number, base branch, head commit, ticket number, tier and, for a re-review, the earlier findings. Don't paste whole docs.
- **Stacks:** review a stack as a whole in one pass (one reviewer, a report per PR, grouped by tier), not one reviewer per PR. The rules are in `docs/REVIEW-CHECKLIST.md`.
- **Output limits:** at most 5 findings (blockers and majors first) plus at most 5 one-line minors, and a verdict. The report starts with `Reviewed commit: <sha>`.
- **Re-review:** after fixes, send only the earlier findings and the diff since the reviewed commit.
- **Post** the report on the PR as a comment headed `Adversarial review (Claude)`.
- **Resolve:** fix every `blocker` and `major`, or reply on the PR with the reason for declining. Never dismiss a finding without a reason. A PR with unresolved blockers does not merge.
- **Not a substitute for CI.** `ci` and `PR checks` must still pass. Move any finding a tool could catch (an ESLint rule, `actionlint`, a script) into CI, so the reviewer does not pay for it again.
- Other reviewers (a human, or Copilot when quota allows) are welcome extras, never the only review.

### Stacked PRs

- Use `gh stack` for work that builds on an unmerged change: `gh stack add <branch>` for the next layer, `gh stack submit` to push and link the PRs. One ticket per PR.
- Open each PR with `gh pr create` using a conforming title (`gh stack submit --auto` generates titles that fail `PR checks`), then run `gh stack submit` to link them.
- Merge from the bottom of the stack up, and run `gh stack sync` afterwards.
- Assets: only GLB (meshopt-compressed where it helps) in `godot/assets/`; sources go in `assets-src/` (Git LFS). Record every asset in `assets/CREDITS.md` with its source and licence. Allowed sources: CC0 packs (the row says CC0) and the owner's original models (the row says `Owned by the owner (all rights reserved)`; the owner keeps the rights, and CI checks that each row says one of the two). Do not use copyrighted characters, third-party images, brands or real people's likeness as a reference. Anything else needs the owner's say-so.
- Before drawing final reference sheets, shortlist CC0 packs and list the gaps in `docs/art/GAPS.md`. Sheets for pack-sourced units follow what the packs can supply; gaps are kitbashed from pack parts or built from primitives. Check each pack's licence file; if it is not clearly CC0, don't use it. The owner's foe models are built to the unit's triangle budget in Blender, baked to one 512 px map per foe with colours matched to the shared palette, and checked for a distinct zoomed-out silhouette before they replace a placeholder.

## CI/CD and releases

- CI runs on every pull request and push to `main`: workflow lint, `pnpm lint`, `pnpm test`, the asset check, the frozen-fixture check, and the Godot job: pinned Godot and export templates (cached), `gdformat --check`, `gdlint`, the sim purity lint, GUT (including the fixtures), the web export with a download-size budget, and the Playwright smoke test on the export. A red CI blocks merging.
- CD: every push to `main` deploys the Godot export to GitHub Pages at the site root (for now the Phase 3 stub scene, until the game exists). The Three.js game is not served any more.
- Releases: pushing a version tag (`vMAJOR.MINOR.PATCH`, semantic versioning) runs the release workflow. It re-runs the checks, exports, and creates a GitHub Release with generated notes from the Conventional Commits and the build attached.
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
