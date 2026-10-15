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
## The support foe: from this wave on a wave holds one Ink Shaman in place of a rolled foe,
## and one more for every `SHAMAN_EVERY_WAVES` waves after that.
const SUPPORT_FOE := "inkShaman"
const SHAMAN_FROM_WAVE := 7
const SHAMAN_EVERY_WAVES := 5
## The flying foe: from this wave on a share of the rolled foes (at least `MOTH_MIN`, `MOTH_PERCENT`
## of the wave) are Razor Moths, spread through the wave between the Ink Shamans.
const AIR_FOE := "razorMoth"
const MOTH_FROM_WAVE := 9
const MOTH_PERCENT := 12
const MOTH_MIN := 2
## A goblin swarm wave every this many waves.
const SWARM_EVERY := 5
## A swarm has this many times the foes of a normal wave of its number.
const SWARM_COUNT_MULTIPLIER := 1.5
## In a swarm the orc threshold is the normal one (below) lowered by this much, so a
## swarm has more orcs than the waves around it at every point of the run.
const SWARM_ORC_THRESHOLD_DROP := 0.1
## Swarm goblins have this many times the hp and pay this share of the reward: they
## are many and frail, so without this a bigger swarm only feeds the player.
const SWARM_HP_MULTIPLIER := 2.0
const SWARM_REWARD_MULTIPLIER := 0.5
## Foes in wave w: round((BASE_COUNT + w * COUNT_PER_WAVE) * WAVE_SIZE_MULTIPLIER). The
## multiplier made waves 40% bigger when they were cut into groups (2026-10-13, #240).
const BASE_COUNT := 6.0
const COUNT_PER_WAVE := 1.4
const WAVE_SIZE_MULTIPLIER := 1.4

## A wave's foes walk in groups of these sizes (Fibonacci), each group's size drawn from
## the waves stream. From wave GROUP_CAP_FROM_WAVE[i] on, a group may have up to
## GROUP_CAP[i] foes. Inside a group each foe follows GROUP_SPACING seconds behind the
## one before; after a group comes a pause of max(GROUP_PAUSE_MIN, GROUP_PAUSE_BASE - w *
## GROUP_PAUSE_PER_WAVE) seconds.
const GROUP_SIZES: Array[int] = [1, 2, 3, 5, 8, 13, 21]
const GROUP_CAP_FROM_WAVE: Array[int] = [1, 4, 8, 13]
const GROUP_CAP: Array[int] = [5, 8, 13, 21]
const GROUP_SPACING := 0.14
const GROUP_PAUSE_BASE := 2.4
const GROUP_PAUSE_PER_WAVE := 0.05
const GROUP_PAUSE_MIN := 1.0
## Seconds before the first foe of a wave.
const FIRST_SPAWN_DELAY := 0.2

## Base gap in seconds: max(GAP_MIN, GAP_BASE - w * GAP_PER_WAVE).
const GAP_BASE := 0.95
const GAP_PER_WAVE := 0.025
const GAP_MIN := 0.32
## The base gap now only sets the boss escort's pause (rolled foes pause by group, see
## GROUP_SPACING), as a multiple of it.
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
## Every foe's reward is also multiplied by REWARD_MULTIPLIER: waves are bigger and walk
## in groups, so each kill pays less to keep the economy in step.
const REWARD_MULTIPLIER := 0.9
## Reward multiplier: 1 + REWARD_PER_WAVE * (w - 1).
const REWARD_PER_WAVE := 0.04
## A foe's blows grow with the wave: 1 + ATTACK_PER_WAVE * (w - 1).
const ATTACK_PER_WAVE := 0.03
## An extra armor point every this many waves.
const ARMOR_EVERY_WAVES := 12
