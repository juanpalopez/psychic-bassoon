# Fixtures: the oracle for the Godot port

JSON produced by the TypeScript sim (`pnpm fixtures`). The GDScript sim must
reproduce every value here **exactly** (Phase 4 gate). Do not edit these files
by hand: change the TypeScript sim (only for a bug, see CLAUDE.md), run
`pnpm fixtures`, and commit the result. A Vitest check fails if they are stale.

Format rules (so Godot's `JSON.parse`, which reads every number as a float,
can compare them with `==`): all integers here are below 2^53; fingerprints are
hex strings; floats are written with the shortest text that round-trips, so
parsing them gives the same double; there are no `NaN` or `-0` values.

| File | Content |
| --- | --- |
| `prng.json` | per seed: 16 `nextFloat`, 16 `nextInt(6)`, 8 `nextRange(0.8, 3.2)`, and the `deriveRng` state for streams 0, 1, 2 and 100 |
| `maps.json` | 120 seeds: main `path`, all `routes` (cells as `[col, row]`), and `tiles` (one string per row, `#` road, `.` plot) |
| `waves.json` | 8 seeds, waves 1 to 40: `[foe, gap]` per spawn, drawn in wave order from the waves stream (`deriveRng(seed, 1)`) |
| `scaling.json` | per foe, waves 1 to 60: `[hp, speed, reward, armor]` |
| `damage.json` | hp lost per tower level, foe and wave; the armor floor; the kill rule |
| `replays.json` | 4 seeds, 3 minutes of the scripted bot: the commands as `[tick, command]`, a state snapshot every 600 ticks and at the end, and the TypeScript fingerprint (reference only) |

A replay snapshot lists: `tick`, `gold`, `lives`, `wave`, `running`, `over`,
`towers` as `[id, type, level, col, row, invested, cooldown]`, `enemies` as
`[id, type, route, hp, distance, x, y, slow, slowTimer]`, `shots` as
`[x, y, targetId, damage]`, `spawners` as `[wave, timer, queued]`, the two RNG
states and `nextId`. Replaying the commands in the GDScript sim must give the
same snapshots at the same ticks.

Ids: foes `scamp raider ironclad warlord`; towers `ballista catapult
frostSpire stormSpire`; commands `build`, `upgrade`, `sell`, `launchWave` as in
`src/sim/game/game.ts`.

## Notes for the port

- **Checkpoint timing.** A replay checkpoint at tick N is the state at the *start* of tick N: before the commands logged at tick N are submitted and before tick N runs. Snapshot at the same moment in GDScript.
- **Float parsing.** Godot's `JSON.parse` is not guaranteed to round the last bit. `prng.json` carries `floatBits` (the IEEE-754 bits of each float as 16 hex digits); the first Phase 4 test must parse the decimal text and check the bits equal these. If it does not, compare floats through their bits instead.
- **Damage cases.** `damage.json` has every tower level against every foe at waves 1, 12 and 24, both sides of the armor floor (a hit never drops below 25% of its damage), and the kill rule (reward paid once).
- **Paths.** The fixtures live outside the Godot project; read them in GUT with `ProjectSettings.globalize_path("res://../fixtures/maps.json")`.
- **Line endings.** `.gitattributes` keeps the files LF on every platform.
