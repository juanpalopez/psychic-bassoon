## Advances the game by one rendered frame: real time at a speed becomes a
## whole number of fixed ticks. Ported from `web-three-final:src/sim/game/frame.ts`.
class_name Frame
extends RefCounted


## Runs the ticks the clock allows and returns how many ran. `before_tick`
## and `after_tick` (optional) are called with the game around every tick;
## `until_tick` (-1 for none) is a tick the game never runs past.
static func step(
	game: GameState,
	clock: Clock,
	elapsed_seconds: float,
	speed: int,
	before_tick: Callable = Callable(),
	after_tick: Callable = Callable(),
	until_tick: int = -1
) -> int:
	var ticks := clock.advance(elapsed_seconds, speed)
	var ran := 0
	while (
		ran < ticks
		and not game.over
		and not game.won
		and (until_tick < 0 or game.tick_count < until_tick)
	):
		if before_tick.is_valid():
			before_tick.call(game)
		Game.tick(game)
		if after_tick.is_valid():
			after_tick.call(game)
		ran += 1
	return ran
