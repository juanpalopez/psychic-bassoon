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
