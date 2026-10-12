# Fixtures: the frozen reference for the ported core

> **Status (2026-10-12):** the game design is `docs/GDD.md`, and parity with the TypeScript prototype is no longer the goal for new content. `prng.json`, `maps.json` and `routes.json` stay as regression tests for the ported core (PRNG, road generator, routes). They are **frozen: never regenerate them and add no new cases.** The TypeScript sim that wrote them was removed in Phase 4 step 8 (it stays in the git tag `web-three-final`). New regression data after the combat port is GDScript replay goldens, written by the GDScript sim (see `godot/tests/goldens/`).

The GDScript ported core must reproduce every value here **exactly**. Do not edit these files by hand. `SHA256SUMS` lists the hash of each file; `pnpm check:fixtures` (and CI) fails when a listed file changes or goes missing, or when another JSON file appears in this folder.

Format rules (so Godot's `JSON.parse`, which reads every number as a float, can compare them with `==`): all integers here are below 2^53; fingerprints are hex strings; floats are written with the shortest text that round-trips, so parsing them gives the same double; there are no `NaN` or `-0` values.

| File | Content |
| --- | --- |
| `prng.json` | per seed: 16 `nextFloat`, 16 `nextInt(6)`, 8 `nextRange(0.8, 3.2)`, and the `deriveRng` state for streams 0, 1, 2 and 100 |
| `maps.json` | 120 seeds: main `path`, all `routes` (cells as `[col, row]`), and `tiles` (one string per row, `#` road, `.` plot) |
| `routes.json` | the first 12 map seeds: per route the point coordinates, cumulative distances and total as float bits, and 24 `positionAt` samples as `[along, x, y]` bits (including one before the start and one past the end) |

## Exact floats

Godot's JSON parser (and `String.to_float`) can misround the last bit of a
decimal float, so the port never compares parsed floats with `==`. Every
fixture that holds floats also carries a `bits` copy of the same shape in which
each number (integers too) is the 16 hex digits of its IEEE-754 bits (big-endian); strings and booleans are kept:

| File | Plain data | Bits copy |
| --- | --- | --- |
| `prng.json` | `floats`, `ranges` | `floatBits` for `floats`; `ranges` have no bits: recompute them from the `floatBits` draws (`min + float * (max - min)`) and compare bits |
| `routes.json` | (bits only) | all values |

Decode a bits string with `PackedByteArray.decode_double` (see `_from_bits` in
`godot/tests/sim/test_rng.gd`) and compare the bits of the result.

## Notes for the port

- **Float parsing.** Godot's `JSON.parse` is not guaranteed to round the last bit. `prng.json` carries `floatBits` (the IEEE-754 bits of each float as 16 hex digits); the first Phase 4 test must parse the decimal text and check the bits equal these. If it does not, compare floats through their bits instead.
- **Paths.** The fixtures live outside the Godot project; read them in GUT with `ProjectSettings.globalize_path("res://../fixtures/maps.json")`.
- **Line endings.** `.gitattributes` keeps the files LF on every platform.
