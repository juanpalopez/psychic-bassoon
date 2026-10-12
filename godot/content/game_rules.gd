## Economy and combat constants ported from the 2D prototype, as in the
## TypeScript content (`web-three-final:src/content/rules.ts`). Data only.
extends RefCounted

## Fixed simulation rate. Game speed adds ticks, never a bigger tick.
const TICK_RATE := 30
## A slow frame is clamped to this many seconds before it is simulated.
const MAX_FRAME_SECONDS := 0.05
## Fastest game speed the player can pick (1x, 2x, 3x).
const MAX_GAME_SPEED := 3
const START_BUTTONS := 180
const START_HEARTSTONE_HEALTH := 20
const TOWER_LEVELS := 3
## Share of the Buttons invested that a sale returns.
const SELL_REFUND := 0.7
## A timer (a tower's cooldown, a slow) this close to zero counts as run out:
## 1/3 s minus ten 1/30 s ticks is not exactly 0 in floating point, and would cost
## a whole tick.
const TIMER_EPSILON := 1e-9
## Armor never cuts a hit below this share of its damage.
const MIN_DAMAGE_FRACTION := 0.25
## Calling a wave early pays `EARLY_CALL_BASE + wave * EARLY_CALL_PER_WAVE`.
const EARLY_CALL_BASE := 10
const EARLY_CALL_PER_WAVE := 2
## Clearing a wave pays `WAVE_CLEAR_BASE + wave * WAVE_CLEAR_PER_WAVE`.
const WAVE_CLEAR_BASE := 15
const WAVE_CLEAR_PER_WAVE := 2
