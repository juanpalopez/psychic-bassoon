# Scrapline

Medieval tower defense for mobile browsers: 3D low-poly remake of a 2D canvas prototype. **Godot 4 + GDScript**, web export first (GitHub Pages), native iOS and Android later. The TypeScript and Three.js game that shipped Phases 0 to 2 is the reference (oracle) until the Godot build replaces it.

- Plan and roadmap: `docs/PLAN.md` (phases 0–8, each closed by a gate; the engine decision is in it)
- Lore and naming: `docs/PLAN.md` → Lore (Greyhold Keep, the Hollow King, Castellan Quell)
- Original prototype (rules and balance reference): `prototype/scrapline.html`

> Paths named in this file that do not exist yet are created in the phase that needs them: `godot/`, `fixtures/` and the Godot CI (Phase 3), `godot/sim/` (Phase 4), `godot/render/` and `godot/ui/` (Phase 5), `godot/assets/` and `docs/art/` (Phase 6). The TypeScript game lives in `src/` and moves to `legacy/` after the Phase 5 gate.

## Commands

Godot (from Phase 3; versions pinned in `.godot-version`):

```bash
godot --path godot                                   # open or run the project
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit   # GUT tests
gdformat godot/ && gdlint godot/                     # gdtoolkit: format and lint
godot --headless --path godot --export-release "Web" ../build/web/index.html        # web export
python3 -m http.server -d build/web                  # serve the export; open on a phone over LAN
```

TypeScript reference game (until it moves to `legacy/`):

```bash
pnpm install
pnpm dev          # Vite dev server; add --host to test on a phone over LAN
pnpm build        # static build to dist/
pnpm test         # Vitest (simulation)
pnpm test:e2e     # Playwright smoke test
pnpm lint         # Prettier check + ESLint + tsc --noEmit
pnpm format       # Prettier --write (run before committing)
pnpm sim -- --seed 42   # headless run: map and wave log
```

## Working rules

- **Work one phase at a time.** Implement only the current phase from `docs/PLAN.md`, then stop and report whether its gate passes. Don't start the next phase or add features from later phases.
- **The TypeScript game is the oracle.** During the Godot migration, gameplay must match it: same rules, same numbers, same results for the same seed. Don't change the TypeScript sim except to fix a bug, and when you do, regenerate `fixtures/` and say so in the PR. `prototype/scrapline.html` is the original reference.
- **Keep `main` deployable.** Run the checks for the code you touched before every commit (`gdformat`, `gdlint`, GUT, export for Godot; `pnpm lint && pnpm test && pnpm build` for TypeScript).

## Architecture

```
godot/
  sim/       pure GDScript game logic: grid, mapgen, routes, waves, towers, foes, economy
  content/   data only: tower/foe defs, wave tables, lore strings
  render/    scenes and scripts: terrain, foes (MultiMesh), towers, camera, effects
  ui/        HUD scenes (Control nodes) and the Theme
  tests/     GUT tests and the fixtures from the TypeScript sim
fixtures/    JSON exported from the TypeScript sim: the oracle for the port
```

- `godot/sim` must never touch the scene tree or engine singletons: no `Node`, no `get_tree`, no `Engine`, `Time` or `OS` calls, no `randf`/`randi`/`randomize`. A lint script enforces it; don't disable it.
- The sim runs on a fixed 30 Hz tick and owns all game state. Render and UI only read state snapshots and events.
- Player actions reach the sim only as commands (`build`, `upgrade`, `sell`, `launchWave`), never by mutating state directly.
- All randomness goes through the seeded PRNG in `godot/sim/rng.gd` (mulberry32 on 32-bit integers masked with `& 0xFFFFFFFF`). The same seed plus the same commands must replay identically, and must match the TypeScript fixtures.
- All balance numbers (cost, damage, range, rate, hp, speed, rewards, wave scaling) live in `godot/content`. Logic files contain no magic numbers.
- Game speed (1×/2×/3×) means more sim ticks per frame, never a bigger tick.
- For exact parity with TypeScript use only `+ - * /`, `sqrt`, `floor`, `min`, `max`, `abs`; use `floor(x + 0.5)` where JavaScript's `Math.round` was used; avoid trig and `round`.

### Domain-driven design

- `godot/sim` is the domain. Split it into bounded contexts by game concept (for example map, waves, combat, economy), one folder each, with a small public entry class. Contexts talk through commands, events and snapshots, not by reaching into each other's internals.
- Use the ubiquitous language from the lore table in names, types and tests (Scamp, Ballista, Frost Spire, Heartstone, wave, gold). No synonyms for the same concept.
- Model state as plain data and pure functions. Value objects are immutable; the sim state is the single aggregate root that only commands change.
- Domain code never depends on infrastructure. `render`, `ui`, storage and the browser are adapters that read snapshots and send commands.

## Rendering and performance

- Target: 60 fps with 80 foes on a mid-range phone. Budget: under 120 draw calls, about 150k triangles, DPR capped at 2. The web export uses the Compatibility renderer (WebGL2) and the single-threaded build.
- One `MultiMeshInstance3D` per foe type. Don't create a node per foe.
- Camera: perspective, about 55° pitch, about 35° FOV, landscape framing (the board is drawn turned so the road runs left to right; the sim is untouched, one script converts sim cells to world positions); pinch zoom and pan are clamped so grid cells stay at least 40 px wide, except that the whole board must always fit.
- Models come from glTF/GLB, preferably the owner's Blender models (`assets-src/blender/`), with CC0 packs as placeholders; keep a simple fallback mesh for any unit whose file is missing. Use part animation; skeletons only for bosses.
- Reuse meshes and materials, free nodes you remove, and avoid allocating objects every frame.

## UI

- The HUD is built from Godot `Control` nodes with one Theme resource that mirrors the Claude Design tokens. Never hard-code colours in scenes or scripts.
- The game is landscape only (owner decision). A phone held upright shows a "turn your phone" prompt (in the web export's HTML shell) and the game pauses. Every action is reachable by the thumbs holding the phone, with tap targets of at least 44 px.
- Respect reduced motion where the platform reports it: no screen shake and reduced particle effects.
- Start audio only after the first tap (browsers block it before).

## Testing

- Every sim module gets GUT tests: map generation (road valid, routes valid, reproducible from its seed), wave composition, damage and armor, economy, and a full-run replay from a seed. Compare against `fixtures/` produced by the TypeScript sim; a mismatch is a bug in the GDScript.
- Fix the seed in tests; never depend on timing.
- **TDD where possible.** For `godot/sim` and `godot/content`, write the failing test first, make it pass, then refactor. A bug fix starts with a test that reproduces it. Render and UI code don't need test-first, but logic extracted from them (camera clamping, grid picking, formatting) does.
- Test the domain through its public commands and snapshots, not internals, so refactors don't break tests.
- The TypeScript Vitest suite keeps running until the code moves to `legacy/`.

## Code style

- GDScript with static typing everywhere (`var x: int`, typed arrays, typed returns). Prefer plain data and small functions over deep class hierarchies.
- **Code style: the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), enforced by tools, not by review.** `gdformat` formats and `gdlint` checks (gdtoolkit, pinned version, config in `godot/.gdlintrc`). CI fails on unformatted or unlinted code. Don't hand-format and don't disable a rule to get around it.
  - Naming: `snake_case` for files, functions and variables; `PascalCase` for classes and nodes; `CONSTANT_CASE` for constants and enum members.
  - Comments explain why, not what. Use `##` doc comments on public APIs.
- TypeScript code (until it moves to `legacy/`) keeps the Google TypeScript Style Guide with Prettier and ESLint as before.
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
  - **Standard** (`sonnet`, the agent's default): most PRs, including pure-logic sim modules (`godot/sim`, and `src/sim` while it exists) (map generation, combat, economy, waves). They still need tests first, and a sim PR that touches seeds, randomness or the tick loop is deep.
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
- Assets: only GLB (meshopt-compressed where it helps) in `godot/assets/`; sources go in `assets-src/` (Git LFS). Record every third-party asset in `assets/CREDITS.md` with its source and licence. Use CC0 assets only unless asked otherwise. Original models made by the owner are credited as such.
- Before drawing final reference sheets, shortlist CC0 packs and list the gaps in `docs/art/GAPS.md`. Sheets follow what the packs can supply; gaps are kitbashed from pack parts or built from primitives. Check each pack's licence file; if it is not clearly CC0, don't use it.

## CI/CD and releases

- CI runs on every pull request and push to `main`: pinned Godot and export templates (cached), `gdformat --check`, `gdlint`, the sim purity lint, GUT (including the fixtures), the web export with a download-size budget, and the Playwright smoke test on the export. Until the TypeScript game moves to `legacy/`, its checks (`pnpm lint`, `pnpm test`, `pnpm build`, Playwright) run too. A red CI blocks merging.
- CD: every push to `main` deploys the web export to GitHub Pages.
- Releases: pushing a version tag (`vMAJOR.MINOR.PATCH`, semantic versioning) runs the release workflow. It re-runs the checks, exports, and creates a GitHub Release with generated notes from the Conventional Commits and the build attached.
- Keep workflows in `.github/workflows/`. Pin action versions and never commit secrets.

## Tickets

Work is tracked in the GitHub Project "Project Slag" (codename for Scrapline): <https://github.com/users/juanpalopez/projects/4> (owner `juanpalopez`, project number 4). The board is the source of truth for progress. Every ticket follows this format:

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

Use the lore names in code-facing content and the UI:

| Prototype | Remake |
| --- | --- |
| scout / walker / tank / boss | Scamp / Raider / Ironclad / Warlord |
| laser / rocket / emp / tesla | Ballista / Catapult / Frost Spire / Storm Spire |
