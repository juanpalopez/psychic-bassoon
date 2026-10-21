# Kingdom of the Fold

A premium, painterly low-poly fantasy tower-defense game about a folded-paper kingdom under siege by the Blot's corrupted ink. Defend the Heartkeep across a boundless 32×20 valley using spool ballistae, thimble mortars, prism spires, guard tents, craft magic, and a hero who can move between tactical fronts. The lore begins in a craft room, but the on-screen world is a complete fantasy valley—not a desk or cutting mat.

The game was previously titled **Papercraft Kingdom Defense** (and earlier Scrapline). The repository remains `psychic-bassoon`. The design baseline is in [`docs/GDD.md`](docs/GDD.md), the expanded tower/hero/enemy roster is in [`docs/UNIT_ROSTER.md`](docs/UNIT_ROSTER.md), and the visual direction is in [`docs/art/STYLE.md`](docs/art/STYLE.md).

- **Roster visual reference:** [`docs/art/roster/roster-overview.svg`](docs/art/roster/roster-overview.svg)
- **Folded Valley map concept:** [`docs/art/maps/folded-valley-tactical-concept.svg`](docs/art/maps/folded-valley-tactical-concept.svg)


## Getting started

### Prerequisites

- [Godot](https://godotengine.org/) with the exact version in `.godot-version` (its export templates must match it)
- [Node.js](https://nodejs.org/) 22 or newer and [pnpm](https://pnpm.io/) 10 (`corepack enable`), for the repo's checks and the frozen-fixture check
- [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) 4.5.0 (`pip install gdtoolkit==4.5.0`) for `gdformat` and `gdlint`
- For the iPhone build: a Mac with Xcode 15 or newer, an Apple ID (a free one works; its installs expire after 7 days) and your team id in `PKD_TEAM_ID` or `~/.config/pkd/team_id`

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
mkdir -p build/linux && godot --headless --path godot --export-release "Linux" ../build/linux/papercraft-kingdom-defense.x86_64
scripts/ios-run.sh                                                   # on a Mac: build, install and launch on a connected iPhone
```

The `Windows` and `macOS` presets export the same way (see `CLAUDE.md`, Commands). On the iPhone, trust the developer once in Settings → General → VPN & Device Management; [docs/IPHONE.md](docs/IPHONE.md) walks through the whole setup and the common errors.

### Test

```bash
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gexit     # GUT tests for the GDScript sim
pnpm test                # Vitest: the repo's scripts (checks and tooling)
```

### Lint and format

```bash
(cd godot && find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' | xargs gdformat && find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' | xargs gdlint)
pnpm lint                # Prettier, ESLint and TypeScript type checks (scripts)
pnpm format              # Prettier --write
pnpm check:sim-purity    # the GDScript sim must stay free of the scene tree and random numbers
pnpm check:assets        # godot/assets against assets/CREDITS.md
pnpm check:fixtures      # the frozen fixtures against fixtures/SHA256SUMS
python3 scripts/mutate.py scripts/mutations/barracks.json   # can the tests fail? (survivors are untested rules)
```

Before every commit run the checks for what you touched; CI runs all of them.

## Project structure

```
godot/
  sim/       pure GDScript game logic: map, routes, game state, commands, tick
  content/   data only: tower and map numbers (foes and waves arrive with their ports)
  render/    scenes and scripts (Phase 5)
  ui/        HUD scenes and the Theme (Phase 5)
  tests/     GUT tests
fixtures/    frozen JSON from the retired TypeScript sim (PRNG, maps, routes): what the GDScript sim must reproduce
scripts/     CI checks (purity, render boundary, assets, fixtures, desktop export), the iPhone run script and balance tooling
site/        the static page GitHub Pages serves (it links to the releases list)
assets-src/  Blender sources and raw packs
docs/        plan, review checklist, art references
prototype/   the original 2D prototype (rules and balance reference)
```

A few rules shape the code. The full list is in [`CLAUDE.md`](CLAUDE.md).

- `godot/sim` is pure and deterministic: no scene tree, no engine singletons, no `randf`/`randi`; all randomness goes through the seeded PRNG, and the ported core equals the frozen fixtures exactly.
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
- `CI`: workflow lint, `pnpm lint`, `pnpm test`, the asset check, then the Godot job (format, lint, sim purity, render boundary, GUT, the headless game budget, and a Linux export that must run headless), on every pull request and push to `main`.
- `Deploy`: after `CI` passes on `main`, GitHub Pages serves `site/index.html`, a download page that links to the releases list (pre-releases included).
- `Release`: pushing a `vMAJOR.MINOR.PATCH` tag (on `main`) runs the checks with the Linux, Windows and macOS exports and creates a GitHub Release with the three builds attached.

### Assets

[CC0](https://creativecommons.org/publicdomain/zero/1.0/) packs and the owner's own models, compressed to GLB in `godot/assets/`, with the source and licence recorded in `assets/CREDITS.md`.

## License

[MIT](LICENSE) for the code. Art keeps each source's terms (CC0 for packs; the owner keeps the rights to their own models).
