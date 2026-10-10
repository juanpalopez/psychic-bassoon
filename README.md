# Scrapline

A medieval tower defense for mobile browsers. You are Castellan Quell, last warden of Greyhold Keep, and the Hollow King, a dead monarch who still issues edicts, is sending his warband down the King's Road to claim the Heartstone as tithe. Place Ballistae, Catapults, Frost Spires and Storm Spires along a procedurally generated road and hold the line.

It is a 3D low-poly remake of a 2D canvas prototype, and it plays in landscape on a phone. It is moving from Three.js and TypeScript to the Godot engine (see `docs/PLAN.md`); the TypeScript web build is still the live version and the reference for the port.

- **Play (latest `main`):** https://juanpalopez.github.io/psychic-bassoon/
- **Plan and roadmap:** [`docs/PLAN.md`](docs/PLAN.md) (phases 0–5, each closed by a gate)
- **Project board:** https://github.com/users/juanpalopez/projects/4 (codename _Project Slag_)

> **Status:** Phase 0 (repo and pipeline). The page shows an empty 3D scene. The game rules arrive in Phase 1 and the playable greybox in Phase 2.

## Getting started

### Prerequisites

- [Node.js](https://nodejs.org/) 22 or newer (`.nvmrc` pins 22; with nvm run `nvm use`)
- [pnpm](https://pnpm.io/) 10. The exact version is in `package.json` (`packageManager`), so the easiest way is Corepack, which ships with Node: `corepack enable`

### Install

```bash
git clone https://github.com/juanpalopez/psychic-bassoon.git
cd psychic-bassoon
pnpm install
```

### Run

```bash
pnpm dev                 # Vite dev server at http://localhost:5173
pnpm dev --host          # also reachable on your LAN, to test on a phone
pnpm build               # type check and static build into dist/
pnpm preview             # serve dist/ locally
```

Until the 3D game lands (Phase 2) the simulation can be watched headless. It prints the seeded map, plays a scripted build order and logs each wave:

```bash
pnpm sim -- --seed 42               # 10 waves from seed 42
pnpm sim -- --seed 7 --waves 25     # more waves
pnpm sim -- --seed 42 --speed 3     # same output: speed only adds ticks per frame
```

The same seed always prints the same text.

To test on a phone, run `pnpm dev --host` and open the "Network" URL Vite prints, on the same Wi-Fi.

### Test

```bash
pnpm test                # unit tests (Vitest) for the simulation
pnpm test:watch          # unit tests in watch mode
pnpm exec playwright install chromium   # once, to download the browser
pnpm test:e2e            # Playwright smoke test (builds and serves the app)
```

### Lint and format

```bash
pnpm lint                # Prettier check, ESLint, and TypeScript type checks
pnpm format              # fix formatting with Prettier
pnpm lint:fix            # apply ESLint auto-fixes
pnpm check:size          # bundle size budget (run after pnpm build)
```

Before every commit run `pnpm format && pnpm lint && pnpm test && pnpm build`. CI runs the same checks.

## Project structure

```
src/
  sim/       pure TypeScript game logic: grid, mapgen, waves, towers, enemies, economy
  render/    Three.js scene, camera, instanced meshes, effects
  ui/        DOM HUD, panels, overlays
  content/   data only: tower and enemy definitions, wave tables, lore strings
  main.ts    wires sim, render and ui together
e2e/         Playwright smoke test
scripts/     build tooling (bundle size check)
docs/        review checklist, design notes
```

A few rules shape the code. The full list is in [`CLAUDE.md`](CLAUDE.md).

- `src/sim` is pure and deterministic: it never imports `render`, `ui`, `three` or the DOM, and all randomness goes through a seeded PRNG. The same seed plus the same commands replays identically.
- The sim runs at a fixed 30 Hz tick and owns all state. Render and UI only read snapshots. Player actions reach the sim as commands (`build`, `upgrade`, `sell`, `launchWave`).
- All balance numbers live in `src/content`, not in logic.
- The HUD is DOM, not canvas, and every action is reachable by the thumbs holding the phone sideways (landscape only).

## Contributing

Work is planned in phases and tracked as tickets on the [project board](https://github.com/users/juanpalopez/projects/4). Pick a ticket from the current phase, and don't start features from a later one.

1. **Branch** from `main` (for example `feat/sim-seeded-prng`). For work that builds on an unmerged change, use [`gh stack`](https://github.com/github/gh-stack) and one PR per ticket.
2. **Write the test first** for anything in `src/sim` or `src/content` (TDD), with a fixed seed. Keep the code in the [Google TypeScript style](https://google.github.io/styleguide/tsguide.html); Prettier and ESLint enforce it.
3. **Commit** with [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, for example `feat(sim): add seeded PRNG`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Scopes: `sim`, `render`, `ui`, `content`, `assets`, `docs`, `ci`, `build`, `deps`.
4. **Open a PR** with a conforming title, fill in the template, and reference the ticket (`Closes #N`, or `Refs #N` if part of it can only be checked after merge). Ticket titles use `[Phase N] …`; PR titles use the Conventional Commit format.
5. **Review:** every PR gets an adversarial review scaled to its risk. See [`docs/REVIEW-CHECKLIST.md`](docs/REVIEW-CHECKLIST.md). Fix blockers and majors, or reply with a reason.
6. **Merge** with squash once `ci` and `PR checks` pass.

### CI/CD

- `PR checks`: Conventional Commit titles and commits, and a ticket-reference warning.
- `CI`: install, lint, unit tests, build, bundle size budget and the smoke test, on every pull request and push to `main`.
- `Deploy`: after `CI` passes on `main`, the build is published to GitHub Pages.
- `Release`: pushing a `vMAJOR.MINOR.PATCH` tag (on `main`) runs the checks and creates a GitHub Release with the build attached.

### Assets

Only [CC0](https://creativecommons.org/publicdomain/zero/1.0/) assets, compressed to GLB in `public/assets/`, with the source and licence recorded in `assets/CREDITS.md` (created with the first asset).

## License

[MIT](LICENSE) for the code. Art keeps each pack's CC0 terms.
