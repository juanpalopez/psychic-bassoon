## The words the Messenger Crow carries for a game event; "" when the event is not worth a
## scroll.
class_name CrowAlerts
extends RefCounted

const ALERTS := preload("res://content/alerts.gd")
const WAVES := preload("res://content/waves.gd")


static func text_for(event: GameEvent) -> String:
	if event.kind == GameEvent.Kind.WAVE_LAUNCHED:
		if event.wave % WAVES.BOSS_EVERY == 0:
			return ALERTS.BOSS_COMING % event.wave
		return ALERTS.WAVE_COMING % event.wave
	if event.kind == GameEvent.Kind.WAVE_CLEARED:
		return ALERTS.WAVE_CLEARED % [event.wave, event.bonus]
	return ""
