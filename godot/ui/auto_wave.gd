## Auto start: when the player switches it on, each cleared wave is followed by the next
## after a short countdown, with no tap. It only says when; the scene sends the command.
## It never calls a wave while foes are on the board, so the early-call bonus stays a choice.
class_name AutoWave
extends RefCounted

const RULES := preload("res://content/game_rules.gd")

var enabled := false

# seconds of game time until the next wave; below zero while nothing counts down
var _left := -1.0
# the countdown ran out and the launch is on its way: no new countdown until the wave starts
var _fired := false


## Moves the countdown on by `delta` seconds of game time (0 while paused). True on the
## call where the countdown runs out: the next wave should start now.
func advance(game: GameState, delta: float) -> bool:
	if not enabled or not between_waves(game):
		_left = -1.0
		_fired = false
		return false
	if _fired:
		return false
	if _left < 0.0:
		_left = RULES.AUTO_WAVE_SECONDS
	_left -= delta
	if _left > 0.0:
		return false
	_left = -1.0
	_fired = true
	return true


## Whether a wave was cleared and another is still to come. Wave 1 always waits for the
## player, so a new run never starts by itself.
static func between_waves(game: GameState) -> bool:
	return (
		game.wave > 0
		and not game.running
		and not game.over
		and not game.won
		and game.spawners.is_empty()
		and game.wave < RULES.WIN_WAVE
	)


## Stops a running countdown (the player started the wave, or a new run began); the next
## call to `advance` between waves starts a fresh one.
func cancel() -> void:
	_left = -1.0
	_fired = false


## The player started the wave by hand: drop the countdown, and hold off until that wave is
## under way, so a tap and the countdown never send two launches.
func launched_by_player() -> void:
	_left = -1.0
	_fired = true


func counting() -> bool:
	return _left >= 0.0


## Whole seconds left, rounded up, for the button's countdown.
func seconds_left() -> int:
	return int(ceil(_left)) if counting() else 0
