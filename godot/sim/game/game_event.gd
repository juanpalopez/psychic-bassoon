## What happened during the last tick, for render and UI to react to.
class_name GameEvent
extends RefCounted

## The order of both enums is load-bearing once events are serialised: add new
## members at the end, and map to the TypeScript strings at the snapshot edge.
enum Kind {
	TOWER_BUILT,
	TOWER_UPGRADED,
	TOWER_SOLD,
	WAVE_LAUNCHED,
	COMMAND_REJECTED,
	WAVE_CLEARED,
	FOE_SPAWNED,
	FOE_LEAKED,
	GAME_OVER,
	FOE_KILLED,
	TOWER_FIRED,
	GAME_WON,
	GUARD_RAISED,
	GUARD_FELL,
	FOE_ENGAGED,
	SPEC_CHOSEN,
	ABILITY_USED,
	ZONE_OPENED,
	ZONE_CLOSED,
}

## Why a command did nothing. A rejection is an event, never an error.
enum RejectReason {
	GAME_OVER,
	NOT_A_SOCKET,
	UNKNOWN_TOWER,
	OCCUPIED,
	NOT_ENOUGH_BUTTONS,
	MAX_LEVEL,
	NO_SUCH_TOWER,
	WAVE_IN_PROGRESS,
	GAME_WON,
	FINAL_WAVE,
	NOT_AT_TOP_LEVEL,
	SPEC_ALREADY_CHOSEN,
	UNKNOWN_SPEC,
	NO_SPEC,
	ABILITY_COOLING_DOWN,
	NO_TARGET,
}

var kind: Kind = Kind.TOWER_BUILT
var tower_id: int = 0
## GUARD_RAISED, GUARD_FELL and FOE_ENGAGED: the guard (`tower_id` is its tent).
var guard_id: int = 0
## TOWER_UPGRADED: the new level (0 is level 1).
var level: int = 0
## TOWER_SOLD: Buttons paid back.
var refund: int = 0
## WAVE_LAUNCHED: the wave number, and the Buttons paid for calling it early.
var wave: int = 0
var early_bonus: int = 0
## WAVE_CLEARED: the Buttons paid for clearing the wave (`wave` is the wave number).
var bonus: int = 0
## FOE_SPAWNED and FOE_LEAKED: which foe, its type, and how much health it took.
var foe_id: int = 0
var foe_type: String = ""
var leak: int = 0
## FOE_KILLED: the foe (`foe_id`, `foe_type`), the Buttons it paid, and where it fell.
var reward: int = 0
## TOWER_FIRED: the tower (`tower_id`), its target (`foe_id`), where the target
## stood (`x`, `y`) and the blast radius in cells (0 for a single-target shot).
var splash: float = 0.0
var x: float = 0.0
var y: float = 0.0
## ABILITY_USED: the tower (`tower_id`), its target (`foe_id`, at `x`, `y`) and where a line
## ability ends (`x2`, `y2`).
var x2: float = 0.0
var y2: float = 0.0
## SPEC_CHOSEN: the spec id.
var spec: String = ""
## ZONE_OPENED and ZONE_CLOSED: which zone ("ink_vortex" or "pool") and its id, to pair the two.
var zone_id: int = 0
var zone_kind: String = ""
## Only FOE_KILLED, TOWER_FIRED and ABILITY_USED set `x` and `y`; they are 0.0 on every other event.
## COMMAND_REJECTED: the command and the reason.
var command: Command = null
var reason: RejectReason = RejectReason.GAME_OVER


static func of(event_kind: Kind) -> GameEvent:
	var event := GameEvent.new()
	event.kind = event_kind
	return event


static func rejected(rejected_command: Command, why: RejectReason) -> GameEvent:
	var event := GameEvent.of(Kind.COMMAND_REJECTED)
	event.command = rejected_command
	event.reason = why
	return event
