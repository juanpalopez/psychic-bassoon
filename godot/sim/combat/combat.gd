## What happens between the foes and the Heartstone each tick: foes walk their
## routes, a foe that gets to the end leaks and takes Heartstone health, and the
## game ends when the health is gone. Towers fire after the foes have moved.
class_name Combat
extends RefCounted

const RULES := preload("res://content/game_rules.gd")


## Runs the foes' part of one tick.
static func step(game: GameState) -> void:
	Specs.tick_cooldowns(game)
	ShamanAura.step(game)
	Zones.step(game)
	_move_foes(game)
	Barracks.step(game)
	TowerFire.step(game)
	Status.step_bleed(game)
	TowerFire.release_fallen_locks(game)
	_remove_the_fallen(game)
	if game.heartstone_health <= 0 and not game.over:
		game.over = true
		var event := GameEvent.of(GameEvent.Kind.GAME_OVER)
		event.wave = game.wave
		game.events.append(event)


## Drops foes that are no longer alive; leaves the array alone when nobody is.
static func _remove_the_fallen(game: GameState) -> void:
	var any_fallen := false
	for foe in game.foes:
		if not foe.alive:
			any_fallen = true
			break
	if not any_fallen:
		return
	var alive: Array[Foe] = []
	for foe in game.foes:
		if foe.alive:
			alive.append(foe)
	game.foes = alive


static func _move_foes(game: GameState) -> void:
	for foe in game.foes:
		# a foe that fell earlier (a hit between ticks) must not walk or leak
		if not foe.alive:
			continue
		var held := foe.engaged_guard_id != -1
		var frozen := foe.freeze_timer > RULES.TIMER_EPSILON
		var slowed := foe.slow_timer > RULES.TIMER_EPSILON
		var walk := foe.speed * (1.0 + foe.speed_buff)
		if slowed:
			walk *= 1.0 - foe.slow
		# a held or frozen foe does not walk, but a slow on it keeps running out
		if not held and not frozen:
			foe.distance += walk * Game.TICK_SECONDS
		if slowed:
			foe.slow_timer -= Game.TICK_SECONDS
			# the slow ends with its last slowed step, not a tick later
			if foe.slow_timer <= RULES.TIMER_EPSILON:
				foe.slow = 0.0
				foe.slow_timer = 0.0
		if frozen:
			foe.freeze_timer -= Game.TICK_SECONDS
			if foe.freeze_timer <= RULES.TIMER_EPSILON:
				foe.freeze_timer = 0.0
		if held:
			continue
		var route := (game.air_routes if foe.flying else game.routes)[foe.route]
		if foe.distance >= route.total:
			foe.alive = false
			game.heartstone_health = maxi(0, game.heartstone_health - foe.leak)
			var event := GameEvent.of(GameEvent.Kind.FOE_LEAKED)
			event.foe_id = foe.id
			event.foe_type = foe.type
			# the foe's own leak, even if the health was already gone this tick
			event.leak = foe.leak
			game.events.append(event)
			continue
		var at := route.position_at(foe.distance)
		foe.x = at.x
		foe.y = at.y
