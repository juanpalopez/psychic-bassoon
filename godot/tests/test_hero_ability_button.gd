## The hero's Blade Whirl button: its state, the command it sends and the words for a refusal.
extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func _hero() -> Hero:
	var hero := Hero.new()
	hero.alive = true
	return hero


func test_no_hero_hides_the_button() -> void:
	assert_false(HeroAbilityState.of(null).visible)


func test_a_ready_hero_enables_it() -> void:
	var state := HeroAbilityState.of(_hero())
	assert_true(state.visible)
	assert_true(state.enabled)
	assert_eq(state.text, "Whirl")


func test_cooling_down_disables_it_and_rounds_the_seconds_up() -> void:
	var hero := _hero()
	hero.ability_cooldown = 6.2
	var state := HeroAbilityState.of(hero)
	assert_true(state.visible)
	assert_false(state.enabled)
	assert_eq(state.text, "Whirl 7s")


func test_a_fallen_hero_disables_it() -> void:
	var hero := _hero()
	hero.alive = false
	var state := HeroAbilityState.of(hero)
	assert_true(state.visible)
	assert_false(state.enabled)
	assert_eq(state.text, "Fallen")


func test_the_reasons_have_words() -> void:
	for reason in [
		GameEvent.RejectReason.HERO_FALLEN,
		GameEvent.RejectReason.ABILITY_COOLING_DOWN,
		GameEvent.RejectReason.NO_TARGET,
	]:
		assert_ne(RejectText.of(reason), "That did not work")


func test_the_button_is_a_tap_target_and_a_press_sends_the_hero_command() -> void:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	main.set_process(false)
	await get_tree().process_frame
	main._start(main.game().seed)
	main._process(0.0)
	var button := main._whirl as HeroAbilityButton
	assert_true(button.visible)
	assert_gte(button.size.x, 44.0)
	assert_gte(button.size.y, 44.0)
	assert_false(button.disabled)
	# no foe is near the Knight yet, so the sim refuses and the message says why
	button.pressed.emit()
	main._process(0.1)
	assert_eq(
		(main.get_node("Hud/Message") as Label).text,
		RejectText.of(GameEvent.RejectReason.NO_TARGET)
	)
	assert_false(button.disabled)


func _main() -> Node:
	var port := SubViewport.new()
	port.size = Vector2i(1280, 720)
	add_child_autofree(port)
	var main := MAIN_SCENE.instantiate()
	port.add_child(main)
	main.set_process(false)
	await get_tree().process_frame
	main._start(main.game().seed)
	main._process(0.0)
	return main


func test_a_paused_game_turns_the_button_off() -> void:
	assert_false(HeroAbilityState.of(_hero(), true).enabled)
	assert_true(HeroAbilityState.of(_hero(), false).enabled)


func test_the_button_hides_when_covered() -> void:
	var button := HeroAbilityButton.new()
	add_child_autofree(button)
	button.show_hero(_hero(), false)
	assert_true(button.visible)
	button.show_hero(_hero(), true)
	assert_false(button.visible)


func test_the_button_follows_the_pause_in_the_game() -> void:
	var main := await _main()
	var button := main._whirl as HeroAbilityButton
	assert_false(button.disabled)
	main._speed.paused = true
	main._process(0.0)
	assert_true(button.disabled)


func test_a_hero_cast_shows_the_toast() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = game.hero.id
	game.events.append(event)
	main._after_tick(game)
	assert_eq((main.get_node("Hud/Message") as Label).text, HeroAbilityState.CAST_MESSAGE)


func test_a_tower_ability_shows_no_whirl_toast() -> void:
	var main := await _main()
	var game: GameState = main.game()
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = game.hero.id + 1000
	game.events.append(event)
	main._after_tick(game)
	assert_ne((main.get_node("Hud/Message") as Label).text, HeroAbilityState.CAST_MESSAGE)


func test_a_world_tap_beside_the_button_is_not_swallowed() -> void:
	var main := await _main()
	var button := main._whirl as HeroAbilityButton
	var rect := button.get_global_rect()
	var beside := Vector2(rect.position.x - 20.0, rect.get_center().y)
	assert_false(rect.has_point(beside))
	main._on_tap(beside)
	main._process(0.0)
	var answered: bool = (
		main.selected_cell() != BoardSpace.NO_CELL
		or (main.get_node("Hud/Message") as Label).visible
	)
	assert_true(answered)


func test_the_edge_arrows_stop_above_the_button() -> void:
	var canvas := Vector2(1280.0, 720.0)
	var room := EdgeIndicators.new().room(canvas)
	assert_lte(room.end.y, HudLayout.ability_rect(canvas).position.y)
	assert_false(room.intersects(HudLayout.ability_rect(canvas)))
