## The words for a command the sim turned down.
class_name RejectText
extends RefCounted


static func of(reason: GameEvent.RejectReason) -> String:
	match reason:
		GameEvent.RejectReason.GAME_OVER:
			return "The game is over"
		GameEvent.RejectReason.NOT_A_SOCKET:
			return "Build on a socket"
		GameEvent.RejectReason.UNKNOWN_TOWER:
			return "Unknown tower"
		GameEvent.RejectReason.OCCUPIED:
			return "That plot is taken"
		GameEvent.RejectReason.NOT_ENOUGH_GOLD:
			return "Not enough gold"
		GameEvent.RejectReason.MAX_LEVEL:
			return "Already at the top level"
		GameEvent.RejectReason.NO_SUCH_TOWER:
			return "No such tower"
		GameEvent.RejectReason.WAVE_IN_PROGRESS:
			return "A wave is still coming"
	return "That did not work"
