# Scrapline

Robot tower defense for mobile browsers: 3D low-poly remake of a 2D canvas prototype. Three.js + TypeScript + Vite, deployed to GitHub Pages.

- Plan and roadmap: `docs/PLAN.md` (phases 0–5, each closed by a gate)
- Lore and naming: `docs/PLAN.md` → Lore (Foundry Nine, FOREMAN, Engineer Quell)
- Original prototype (rules and balance reference): `prototype/scrapline.html`

## Commands

```bash
pnpm install
pnpm dev          # Vite dev server; add --host to test on a phone over LAN
pnpm build        # static build to dist/
pnpm test         # Vitest (simulation)
pnpm test:e2e     # Playwright smoke test
pnpm lint         # ESLint + tsc --noEmit
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
- Use the ubiquitous language from the lore table in names, types and tests (Skitter, Welder, Quench Coil, Core, wave, quota). No synonyms for the same concept.
- Model state as plain data and pure functions. Value objects are immutable; the sim state is the single aggregate root that only commands change.
- Domain code never depends on infrastructure. `render`, `ui`, storage and the browser are adapters that read snapshots and send commands.

## Rendering and performance

- Target: 60 fps with 80 robots on a mid-range Android phone. Budget: under 120 draw calls, about 150k triangles, DPR capped at 2.
- One `InstancedMesh` per robot type. Don't create a mesh per enemy.
- Camera: perspective, about 55° pitch, about 35° FOV, portrait framing; pinch zoom and pan are clamped so grid cells stay at least 40 px wide.
- Models in two stages. Phase 2 greybox: robots and towers are built procedurally from primitives in `src/render/models/` (one file per unit), following the rough silhouette sheets in `docs/art/`. Phase 3 onward: CC0 GLB models (recoloured, kitbashed) replace the primitives one unit at a time; keep each unit's primitive builder as the fallback for any gap the packs don't cover. Use rigid-part animation; no skinning except for bosses.
- Keep a unit's model behind one interface (`src/render/models/<unit>.ts`) so swapping primitives for a GLB never touches sim, UI or instancing code.
- Reuse geometries and materials, dispose of anything removed, and avoid allocating objects inside the frame loop.

## UI

- The HUD is a DOM overlay. Never draw text or menus in the canvas.
- Every action is one-thumb in portrait, with tap targets of at least 44 px.
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
- Small focused commits in the Conventional Commits format: `type(scope): summary`, for example `feat(sim): add seeded PRNG` or `fix(render): dispose removed meshes`.
  - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Mark breaking changes with `!` and a `BREAKING CHANGE:` footer.
  - Scopes (optional): `sim`, `render`, `ui`, `content`, `assets`, `docs`, `ci`, `build`, `deps`.
  - Summary is imperative, lowercase, no trailing period, at most 72 characters.
  - Release notes are generated from these messages, so write them for a reader of the changelog.
- Pull requests: the title follows the same format (PRs are squash-merged, so the title becomes the commit). Fill in the PR template and reference the ticket (`Closes #N`). The `PR checks` workflow rejects non-conforming titles and commits.

### Reviews

- Every PR gets an adversarial review by a Claude agent before it merges. Use the project agent `adversarial-reviewer` (`.claude/agents/adversarial-reviewer.md`), launched as a fresh subagent so it does not share the author's context. Never self-review inline.
- Give it the PR number, the base branch and the ticket number. For a stack, review each PR against its own diff.
- It hunts for bugs, regressions, mismatches with the ticket's "Done when" list, violations of this file, weak tests, inconsistencies, and CI/CD or security problems. It is read-only and returns a report.
- Post the report on the PR as a comment headed `Adversarial review (Claude)`.
- Fix every `blocker` and `major` finding, or reply on the PR with the reason for declining. Never dismiss a finding without a reason. Re-run the reviewer after fixes that touch the findings.
- A PR with unresolved blockers does not merge. Review is not a substitute for CI: `ci` and `PR checks` must still pass.
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

Work is tracked in the GitHub Project "Project Slag" (codename for Scrapline). Every ticket follows this format:

- **Title:** `[Phase N] Imperative summary`, for example `[Phase 1] Seeded PRNG (mulberry32) with tests`. Epics read `[Phase N] Epic: name`.
- **Labels:** exactly one `phase-N`, one area label (`sim`, `render`, `ui`, `content`, `infra`, `docs`), plus `epic` for epics.
- **Body:** a short description, the plan section it comes from, and a "Done when" list that includes the tests. A gate ticket says which phase gate it closes.
- Add every ticket to the project board. Only create tickets for the current phase and the one after it; later phases stay as roadmap in `docs/PLAN.md`.
- Reference the ticket in commits and PRs (`Closes #N`).

## Naming

Use the lore names in code-facing content and the UI:

| Prototype | Remake |
| --- | --- |
| scout / walker / tank / boss | Skitter / Hauler / Smelter / Overseer |
| laser / rocket / emp / tesla | Welder / Rivet Mortar / Quench Coil / Mainline Arc |
