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
		GameEvent.RejectReason.NOT_ENOUGH_BUTTONS:
			return "Not enough Buttons"
		GameEvent.RejectReason.MAX_LEVEL:
			return "Already at the top level"
		GameEvent.RejectReason.NO_SUCH_TOWER:
			return "No such tower"
		GameEvent.RejectReason.WAVE_IN_PROGRESS:
			return "A wave is still coming"
		GameEvent.RejectReason.GAME_WON:
			return "You already won"
		GameEvent.RejectReason.FINAL_WAVE:
			return "That was the final wave"
	return "That did not work"
