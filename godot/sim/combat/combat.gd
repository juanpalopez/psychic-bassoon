## What happens between the foes and the kingdom each tick: foes walk their
## routes, a foe that gets to the end leaks and takes kingdom health, and the
## game ends when the health is gone. Towers fire after the foes have moved.
class_name Combat
extends RefCounted


## Runs the foes' part of one tick.
static func step(game: GameState) -> void:
	_move_foes(game)
	TowerFire.step(game)
	_remove_the_fallen(game)
	if game.kingdom_health <= 0 and not game.over:
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
		if foe.slow_timer > 0.0:
			foe.slow_timer -= Game.TICK_SECONDS
		else:
			foe.slow = 0.0
		foe.distance += foe.speed * (1.0 - foe.slow) * Game.TICK_SECONDS
		var route := game.routes[foe.route]
		if foe.distance >= route.total:
			foe.alive = false
			game.kingdom_health = maxi(0, game.kingdom_health - foe.leak)
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
