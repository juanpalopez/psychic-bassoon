# Scrapline

Medieval tower defense for mobile browsers: 3D low-poly remake of a 2D canvas prototype. Three.js + TypeScript + Vite, deployed to GitHub Pages.

- Plan and roadmap: `docs/PLAN.md` (phases 0–5, each closed by a gate)
- Lore and naming: `docs/PLAN.md` → Lore (Greyhold Keep, the Hollow King, Castellan Quell)
- Original prototype (rules and balance reference): `prototype/scrapline.html`

> Paths named in this file that do not exist yet are created in the phase that needs them: `src/sim/rng.ts` (Phase 1), `src/render/models/`, `src/ui/tokens.css` and `docs/art/` (Phase 2), `assets/CREDITS.md` and `assets-src/` (with the first third-party asset).

## Commands

```bash
pnpm install
pnpm dev          # Vite dev server; add --host to test on a phone over LAN
pnpm build        # static build to dist/
pnpm test         # Vitest (simulation)
pnpm test:e2e     # Playwright smoke test
pnpm lint         # Prettier check + ESLint + tsc --noEmit
pnpm format       # Prettier --write (run before committing)
```

## Working rules

- **Work one phase at a time.** Implement only the current phase from `docs/PLAN.md`, then stop and report whether its gate passes. Don't start the next phase or add features from later phases.
- **Port before inventing.** Until Phase 2's gate passes, gameplay must match the prototype: same rules, same numbers. Read `prototype/scrapline.html` instead of guessing.
- **Keep `main` deployable.** Run `pnpm lint && pnpm test && pnpm build` before every commit.

## Architecture

```
src/
  sim/       pure TypeScript game logic: grid, mapgen, waves, towers, enemies, economy
  render/    Three.js scene, camera, instanced meshes, effects
  ui/        DOM HUD, panels, overlays
  content/   data only: tower/enemy defs, wave tables, lore strings
  main.ts    wires sim + render + ui
```

- `src/sim` must never import from `render`, `ui`, `three` or the DOM. ESLint enforces this; don't disable the rule.
- The sim runs on a fixed 30 Hz tick and owns all game state. Render and UI only read state snapshots and events.
- Player actions reach the sim only as commands (`build`, `upgrade`, `sell`, `launchWave`), never by mutating state directly.
- All randomness goes through the seeded PRNG in `src/sim/rng.ts`. Never call `Math.random()` in the sim. The same seed plus the same commands must replay identically.
- All balance numbers (cost, damage, range, rate, hp, speed, rewards, wave scaling) live in `src/content`. Logic files contain no magic numbers.
- Game speed (1×/2×/3×) means more sim ticks per frame, never a bigger tick.

### Domain-driven design

- `src/sim` is the domain. Split it into bounded contexts by game concept (for example map, waves, combat, economy), one folder each, with a small public `index.ts`. Contexts talk through commands, events and snapshots, not by reaching into each other's internals.
- Use the ubiquitous language from the lore table in names, types and tests (Scamp, Ballista, Frost Spire, Heartstone, wave, gold). No synonyms for the same concept.
- Model state as plain data and pure functions. Value objects are immutable; the sim state is the single aggregate root that only commands change.
- Domain code never depends on infrastructure. `render`, `ui`, storage and the browser are adapters that read snapshots and send commands.

## Rendering and performance

- Target: 60 fps with 80 foes on a mid-range Android phone. Budget: under 120 draw calls, about 150k triangles, DPR capped at 2.
- One `InstancedMesh` per foe type. Don't create a mesh per enemy.
- Camera: perspective, about 55° pitch, about 35° FOV, landscape framing (the board is drawn turned so the road runs left to right; the sim is untouched, `src/render/space.ts` is the one place that knows); pinch zoom and pan are clamped so grid cells stay at least 40 px wide, except that the whole board must always fit: on a small landscape screen the 40 px limit yields to the fitted view.
- Models in two stages. Phase 2 greybox: foes and towers are built procedurally from primitives in `src/render/models/` (one file per unit), following the rough silhouette sheets in `docs/art/`. Phase 3 onward: CC0 GLB models (recoloured, kitbashed) replace the primitives one unit at a time; keep each unit's primitive builder as the fallback for any gap the packs don't cover. Use rigid-part animation; no skinning except for bosses.
- Keep a unit's model behind one interface (`src/render/models/<unit>.ts`) so swapping primitives for a GLB never touches sim, UI or instancing code.
- Reuse geometries and materials, dispose of anything removed, and avoid allocating objects inside the frame loop.

## UI

- The HUD is a DOM overlay. Never draw text or menus in the canvas.
- The game is landscape only (owner decision). A phone held upright shows a "turn your phone" prompt and pauses. Every action is reachable by the thumbs holding the phone, with tap targets of at least 44 px.
- Colours come from the CSS tokens in `src/ui/tokens.css`, which mirror the Claude Design system. Never hard-code colours in components.
- Respect `prefers-reduced-motion`: no screen shake and reduced particle effects.
- Start audio only after the first tap.

## Testing

- Every sim module gets Vitest tests: map generation (path valid, never self-adjacent, reproducible from its seed), wave composition, damage and armor, economy, and a full-run replay from a seed.
- Fix the seed in tests; never depend on timing.
- **TDD where possible.** For `src/sim` and `src/content`, write the failing test first, make it pass, then refactor. A bug fix starts with a test that reproduces it. Render and UI code don't need test-first, but logic extracted from them (camera clamping, grid picking, formatting) does.
- Test the domain through its public commands and snapshots, not internals, so refactors don't break tests.

## Code style

- TypeScript strict mode, no `any`. Prefer plain functions and data over class hierarchies.
- **Code style: the [Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html), enforced by tools, not by review.** Prettier formats (`.prettierrc.json`: 2 spaces, single quotes, no bracket spacing, 80 columns, `es5` trailing commas, no parens around a single arrow parameter). ESLint (typescript-eslint `strict` and `stylistic`) enforces the rest. Run `pnpm format` before committing; `pnpm lint` fails on unformatted code, and so does `ci`. Don't hand-format and don't disable a rule to get around it.
  - Naming: `UpperCamelCase` for types, classes and interfaces; `lowerCamelCase` for variables, functions, parameters and properties; `CONSTANT_CASE` for module-level constants and enum members. No `I` prefix on interfaces.
  - Named exports only (no `export default`), except tool config files such as `vite.config.ts`.
  - Always `===`, always braces for multi-line blocks, `const` by default, never `var`.
  - Comments explain why, not what. Use JSDoc (`/** … */`) on exported APIs.
  - We don't use `gts` itself: it pins ESLint 9 and we run ESLint 10. We follow its style with Prettier and ESLint directly.
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
  - **Standard** (`sonnet`, the agent's default): most PRs, including pure-logic `src/sim` modules (map generation, combat, economy, waves). They still need tests first, and a sim PR that touches seeds, randomness or the tick loop is deep.
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
- Assets: only compressed GLB in `public/assets/`; sources go in `assets-src/` (Git LFS). Record every third-party asset in `assets/CREDITS.md` with its source and licence. Use CC0 assets only unless asked otherwise.
- Before drawing final reference sheets, shortlist CC0 packs and list the gaps in `docs/art/GAPS.md`. Sheets follow what the packs can supply; gaps are kitbashed from pack parts or built from primitives. Check each pack's licence file; if it is not clearly CC0, don't use it.

## CI/CD and releases

- CI runs on every pull request and push to `main`: `pnpm lint`, `pnpm test`, `pnpm build`, and the Playwright smoke test. A red CI blocks merging.
- CD: every push to `main` deploys `dist/` to GitHub Pages.
- Releases: pushing a version tag (`vMAJOR.MINOR.PATCH`, semantic versioning) runs the release workflow. It re-runs the checks, builds, and creates a GitHub Release with generated notes from the Conventional Commits and the built `dist/` attached.
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
