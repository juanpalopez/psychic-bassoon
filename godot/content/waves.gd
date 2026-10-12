## Wave composition and per-wave scaling, from the prototype's numbers
## (`web-three-final:src/content/waves.ts`) adapted to the GDD's three ground foes. Data only.
extends RefCounted

## The foes a wave is made of: the filler, the heavy foe (also the boss escort)
## and the boss (see `content/foes.gd`).
const FILLER_FOE := "scrapGoblin"
const HEAVY_FOE := "corrugatedOrc"
const BOSS_FOE := "cardboardGolem"

## A boss wave every this many waves (it wins over a swarm wave).
const BOSS_EVERY := 10
## A goblin swarm wave every this many waves.
const SWARM_EVERY := 5
## Foes in wave w: round(BASE_COUNT + w * COUNT_PER_WAVE).
const BASE_COUNT := 6.0
const COUNT_PER_WAVE := 1.4
## Seconds before the first foe of a wave.
const FIRST_SPAWN_DELAY := 0.2

## Base gap in seconds: max(GAP_MIN, GAP_BASE - w * GAP_PER_WAVE).
const GAP_BASE := 0.95
const GAP_PER_WAVE := 0.025
const GAP_MIN := 0.32
## The pause after a foe, as a multiple of the base gap.
const GAP_GOBLIN := 0.6
const GAP_GOBLIN_SWARM := 0.45
const GAP_ORC := 1.4
const GAP_BOSS_ESCORT := 2.0
## The pause in seconds after the Golem.
const GOLEM_GAP := 1.0

## From this wave on, a roll above the threshold makes an orc. The threshold is
## ORC_BASE_THRESHOLD minus w * ORC_THRESHOLD_PER_WAVE (at most ORC_THRESHOLD_CAP).
const ORC_FROM_WAVE := 4
const ORC_BASE_THRESHOLD := 0.82
const ORC_THRESHOLD_PER_WAVE := 0.01
const ORC_THRESHOLD_CAP := 0.2

## hp multiplier: 1 + HP_LINEAR * (w - 1) + HP_QUADRATIC * (w - 1)^2. The quadratic
## term was 0.014 in the prototype; 0.04 is the interim balance (`docs/BALANCE.md`).
const HP_LINEAR := 0.2
const HP_QUADRATIC := 0.04
## Speed multiplier: 1 + min(SPEED_CAP, w * SPEED_PER_WAVE).
const SPEED_PER_WAVE := 0.006
const SPEED_CAP := 0.25
## Reward multiplier: 1 + REWARD_PER_WAVE * (w - 1).
const REWARD_PER_WAVE := 0.04
## An extra armor point every this many waves.
const ARMOR_EVERY_WAVES := 12
