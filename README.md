# Scrapline

A medieval tower defense for mobile browsers. You are Castellan Quell, last warden of Greyhold Keep, and the Hollow King, a dead monarch who still issues edicts, is sending his warband down the King's Road to claim the Heartstone as tithe. Place Ballistae, Catapults, Frost Spires and Storm Spires along a procedurally generated road and hold the line.

It is a 3D low-poly remake of a 2D canvas prototype, built with **Godot 4** (GDScript). It plays in landscape on a phone, in the browser first and as a native iOS app later. The earlier Three.js and TypeScript game is retired; its last build is the tag [`web-three-final`](https://github.com/juanpalopez/psychic-bassoon/tree/web-three-final).

- **Play (latest `main`):** https://juanpalopez.github.io/psychic-bassoon/ (for now a Godot stub scene, not the game)
- **Plan and roadmap:** [`docs/PLAN.md`](docs/PLAN.md) (phases 0–8, each closed by a gate)
- **Project board:** https://github.com/users/juanpalopez/projects/4 (codename _Project Slag_)

> **Status:** Phase 4 (simulation port to GDScript). The PRNG, map generation with routes, and the game state, commands and 30 Hz tick are ported and tested. Foes, combat and waves are next. The game is not playable yet; the live page is a stub that proves the web export runs on a phone.

## Getting started

### Prerequisites

- [Godot](https://godotengine.org/) with the exact version in `.godot-version` (the web export templates must match it)
- [Node.js](https://nodejs.org/) 22 or newer and [pnpm](https://pnpm.io/) 10 (`corepack enable`), for the TypeScript oracle, the fixtures and the smoke test
- [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0 (`pip install gdtoolkit==4.5.0`) for `gdformat` and `gdlint`

### Install

```bash
git clone https://github.com/juanpalopez/psychic-bassoon.git
cd psychic-bassoon
pnpm install
godot --headless --path godot --import   # once, so class_name scripts resolve
```

### Run

```bash
godot --path godot                                                   # open or run the project
mkdir -p build/web && godot --headless --path godot --export-release "Web" ../build/web/index.html
cp godot/web/manifest.webmanifest build/web/
pnpm serve                                                           # serve the export on your LAN, port 8080
```

Open the "Network" address on a phone on the same Wi-Fi. The TypeScript simulation can still be watched headless; it prints the seeded map, plays a scripted build order and logs each wave:

```bash
pnpm sim -- --seed 42               # 10 waves from seed 42
pnpm sim -- --seed 7 --waves 25     # more waves
```

### Test

```bash
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gexit     # GUT tests for the GDScript sim
pnpm test                # Vitest: the TypeScript oracle, the fixtures and the repo's scripts
pnpm exec playwright install chromium   # once
pnpm test:e2e:godot      # Playwright smoke test against build/web
```

### Lint and format

```bash
(cd godot && gdformat sim content tests main.gd && gdlint sim content tests main.gd)   # not addons/
pnpm lint                # Prettier, ESLint and TypeScript type checks
pnpm format              # Prettier --write
pnpm check:sim-purity    # the GDScript sim must stay free of the scene tree and random numbers
pnpm check:assets        # godot/assets against assets/CREDITS.md
pnpm check:godot-size    # download size of build/web
pnpm fixtures            # regenerate fixtures/ from the TypeScript sim (only after a TypeScript sim fix)
```

Before every commit run the checks for what you touched; CI runs all of them.

## Project structure

```
godot/
  sim/       pure GDScript game logic: map, routes, game state, commands, tick
  content/   data only: tower and map numbers (foes and waves arrive with their ports)
  render/    scenes and scripts (Phase 5)
  ui/        HUD scenes and the Theme (Phase 5)
  web/       the custom HTML shell and manifest for the web export
  tests/     GUT tests
src/         the TypeScript simulation and content: the oracle for the port
fixtures/    JSON exported from the TypeScript sim: what the GDScript sim must reproduce
scripts/     fixtures export, sim CLI, CI checks (purity, assets, size)
e2e-godot/   Playwright smoke test of the web export
assets-src/  Blender sources and raw packs
docs/        plan, review checklist, art references
prototype/   the original 2D prototype (rules and balance reference)
```

A few rules shape the code. The full list is in [`CLAUDE.md`](CLAUDE.md).

- `godot/sim` is pure and deterministic: no scene tree, no engine singletons, no `randf`/`randi`; all randomness goes through the seeded PRNG, and results equal the TypeScript fixtures exactly.
- The sim runs at a fixed 30 Hz tick and owns all state. Render and UI only read snapshots. Player actions reach the sim as commands (`build`, `upgrade`, `sell`, `launchWave`).
- All balance numbers live in `godot/content`, not in logic.
- The HUD is built from Godot `Control` nodes, and every action is reachable by the thumbs holding the phone sideways (landscape only).

## Contributing

Work is planned in phases and tracked as tickets on the [project board](https://github.com/users/juanpalopez/projects/4). Pick a ticket from the current phase, and don't start features from a later one.

1. **Branch** from `main` (for example `feat/sim-seeded-prng`). For work that builds on an unmerged change, use [`gh stack`](https://github.com/github/gh-stack) and one PR per ticket.
2. **Write the test first** for anything in `godot/sim` or `godot/content` (TDD), with a fixed seed. GDScript follows the [official style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html), enforced by `gdformat` and `gdlint`; the TypeScript tools keep the Google style with Prettier and ESLint.
3. **Commit** with [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, for example `feat(sim): add seeded PRNG`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`. Scopes: `sim`, `render`, `ui`, `content`, `assets`, `docs`, `ci`, `build`, `deps`.
4. **Open a PR** with a conforming title, fill in the template, and reference the ticket (`Closes #N`, or `Refs #N` if part of it can only be checked after merge). Ticket titles use `[Phase N] …`; PR titles use the Conventional Commit format.
5. **Review:** every PR gets an adversarial review scaled to its risk. See [`docs/REVIEW-CHECKLIST.md`](docs/REVIEW-CHECKLIST.md). Fix blockers and majors, or reply with a reason.
6. **Merge** with squash once `ci` and `PR checks` pass.

### CI/CD

- `PR checks`: Conventional Commit titles and commits, and a ticket-reference warning.
- `CI`: workflow lint, `pnpm lint`, `pnpm test`, the asset check, then the Godot job (format, lint, sim purity, GUT, web export, download budget, smoke test), on every pull request and push to `main`.
- `Deploy`: after `CI` passes on `main`, the Godot export is published to GitHub Pages at the site root.
- `Release`: pushing a `vMAJOR.MINOR.PATCH` tag (on `main`) runs the checks and creates a GitHub Release with the Godot export attached.

### Assets

[CC0](https://creativecommons.org/publicdomain/zero/1.0/) packs, the owner's own models and Meshy-generated models, compressed to GLB in `godot/assets/`, with the source and licence recorded in `assets/CREDITS.md`.

## License

[MIT](LICENSE) for the code. Art keeps each source's terms (CC0 for packs; Meshy plan terms for generated models).
