## The words the Messenger Crow carries for a game event.
extends GutTest

const WAVES := preload("res://content/waves.gd")


func _event(kind: GameEvent.Kind, wave: int) -> GameEvent:
	var event := GameEvent.of(kind)
	event.wave = wave
	return event


func test_a_launched_wave_is_announced_by_its_number() -> void:
	assert_eq(CrowAlerts.text_for(_event(GameEvent.Kind.WAVE_LAUNCHED, 3)), "Wave 3 is coming")


func test_a_boss_wave_is_named_as_one() -> void:
	var text := CrowAlerts.text_for(_event(GameEvent.Kind.WAVE_LAUNCHED, WAVES.BOSS_EVERY))
	assert_eq(text, "A boss comes with wave %d!" % WAVES.BOSS_EVERY)


func test_a_cleared_wave_reports_the_buttons_paid() -> void:
	var event := _event(GameEvent.Kind.WAVE_CLEARED, 4)
	event.bonus = 19
	assert_eq(CrowAlerts.text_for(event), "Wave 4 cleared: +19 Buttons")


func test_other_events_carry_no_message() -> void:
	for kind in [GameEvent.Kind.FOE_KILLED, GameEvent.Kind.TOWER_BUILT, GameEvent.Kind.FOE_LEAKED]:
		assert_eq(CrowAlerts.text_for(GameEvent.of(kind)), "", str(kind))
