## Economy and combat constants ported from the 2D prototype, as in the
## TypeScript content (`src/content/rules.ts`). Data only.
extends RefCounted

## Fixed simulation rate. Game speed adds ticks, never a bigger tick.
const TICK_RATE := 30
## A slow frame is clamped to this many seconds before it is simulated.
const MAX_FRAME_SECONDS := 0.05
## Fastest game speed the player can pick (1x, 2x, 3x).
const MAX_GAME_SPEED := 3
const START_GOLD := 180
const START_LIVES := 20
const TOWER_LEVELS := 3
## Share of gold invested that a sale returns.
const SELL_REFUND := 0.7
## Armor never cuts a hit below this share of its damage.
const MIN_DAMAGE_FRACTION := 0.25
## Calling a wave early pays `EARLY_CALL_BASE + wave * EARLY_CALL_PER_WAVE`.
const EARLY_CALL_BASE := 10
const EARLY_CALL_PER_WAVE := 2
## Clearing a wave pays `WAVE_CLEAR_BASE + wave * WAVE_CLEAR_PER_WAVE`.
const WAVE_CLEAR_BASE := 15
const WAVE_CLEAR_PER_WAVE := 2
## Seconds a Frost Spire slow lasts after the last pulse.
const FROST_SLOW_SECONDS := 1.4
## Catapult shell speed, cells per second.
const ROCKET_SPEED := 5.5
## Storm Spire: reach to the next target and damage kept per jump.
const ARC_CHAIN_RADIUS := 1.6
const ARC_CHAIN_FALLOFF := 0.8
