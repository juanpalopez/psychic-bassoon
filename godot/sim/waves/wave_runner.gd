## Runs the waves: a launch queues a wave, each tick releases the foes whose
## time has come, and a wave ends (and pays a bonus) once nothing is left to
## fight.
class_name WaveRunner
extends RefCounted

const RULES := preload("res://content/game_rules.gd")
const WAVES := preload("res://content/waves.gd")


## Queues the current wave (`game.wave`) for spawning. Called by the launch
## command; it draws the wave's foes from the waves stream.
static func start(game: GameState) -> void:
	var spawner := Spawner.new()
	spawner.queue = WaveBuilder.build(game.wave, game.rng)
	spawner.timer = WAVES.FIRST_SPAWN_DELAY
	spawner.wave = game.wave
	game.spawners.append(spawner)


## Releases queued foes as their timers run out.
static func step_spawners(game: GameState) -> void:
	for spawner in game.spawners:
		spawner.timer -= Game.TICK_SECONDS
		while spawner.timer <= 0.0 and not spawner.queue.is_empty():
			var order: SpawnOrder = spawner.queue.pop_front()
			FoeSpawner.spawn(game, order.type, spawner.wave)
			spawner.timer += order.gap
	var finished := false
	for spawner in game.spawners:
		if spawner.queue.is_empty():
			finished = true
			break
	if not finished:
		return
	var remaining: Array[Spawner] = []
	for spawner in game.spawners:
		if not spawner.queue.is_empty():
			remaining.append(spawner)
	game.spawners = remaining


## Ends the wave and pays the clear bonus once nothing is left to fight.
static func settle(game: GameState) -> void:
	if not game.running or not game.spawners.is_empty() or not game.foes.is_empty():
		return
	game.running = false
	var bonus: int = RULES.WAVE_CLEAR_BASE + game.wave * RULES.WAVE_CLEAR_PER_WAVE
	game.buttons += bonus
	var event := GameEvent.of(GameEvent.Kind.WAVE_CLEARED)
	event.wave = game.wave
	event.bonus = bonus
	game.events.append(event)
