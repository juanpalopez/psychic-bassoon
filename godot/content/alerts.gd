## The words and timings of the Messenger Crow's alerts.
extends RefCounted

const WAVE_COMING := "Wave %d is coming"
const BOSS_COMING := "A boss comes with wave %d!"
const WAVE_CLEARED := "Wave %d cleared: +%d Buttons"
## Seconds the crow takes to fly from the edge to the middle (and the middle to the far
## edge), and to hold its scroll in the middle.
const CROW_FLY_SECONDS := 0.9
const CROW_HOLD_SECONDS := 2.2
## Messages waiting for the crow beyond the one it carries; older ones are dropped.
const CROW_MAX_QUEUE := 4
