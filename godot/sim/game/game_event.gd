## What happened during the last tick, for render and UI to react to.
class_name GameEvent
extends RefCounted

## The order of both enums is load-bearing once events are serialised: add new
## members at the end, and map to the TypeScript strings at the snapshot edge.
enum Kind { TOWER_BUILT, TOWER_UPGRADED, TOWER_SOLD, WAVE_LAUNCHED, COMMAND_REJECTED }

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
}

var kind: Kind = Kind.TOWER_BUILT
var tower_id: int = 0
## TOWER_UPGRADED: the new level (0 is level 1).
var level: int = 0
## TOWER_SOLD: Buttons paid back.
var refund: int = 0
## WAVE_LAUNCHED: the wave number, and the Buttons paid for calling it early.
var wave: int = 0
var early_bonus: int = 0
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
