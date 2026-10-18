## Holds back what a shot does to a foe until the drawn shot lands. The sim takes the health
## off (and removes a killed foe) the tick a tower fires, but the drawn dart or pellet takes a
## few stop-motion frames to get there. So a foe keeps showing the health it had, and a killed
## foe stays standing where it fell, until the shot that hit it lands. Hurt that has no
## drawn flight (beams, guards, zones, bleeding) shows at once. It only reads the game.
class_name HitHold
extends RefCounted

## The shots on their way to each held foe, oldest first, as [lands_at, health_after].
var _pending := {}
## The health a held foe shows until its next shot lands.
var _base := {}
## The health each drawn foe shows this frame.
var _shown := {}
## The foes seen at the last frame, by id, so a foe killed this tick can still be found;
## `_seen` is the spare dictionary it is swapped with, so no frame allocates.
var _known := {}
var _seen := {}
## Killed foes left standing until their shot lands, by id.
var _ghosts := {}
## Held foes the sim has killed: their kill shows when their last shot lands.
var _killed := {}
var _drawn: Array[Foe] = []
var _clock := 0.0
var _landed_kills := 0


## Forgets everything (a new game starts: ids are used again).
func reset() -> void:
	_pending.clear()
	_base.clear()
	_shown.clear()
	_known.clear()
	_seen.clear()
	_ghosts.clear()
	_killed.clear()
	_drawn.clear()
	_clock = 0.0
	_landed_kills = 0


## A tower fired `event` (TOWER_FIRED) this tick, and its drawn shot lands `seconds` of game
## time from now. Holds its target and, for a blast, every foe within its splash of where
## the target stood.
func hold(game: GameState, event: GameEvent, seconds: float) -> void:
	var lands_at := _clock + seconds
	_hold_one(game, event.foe_id, lands_at)
	if event.splash <= 0.0:
		return
	var limit := event.splash * event.splash
	for foe in game.foes:
		if foe.id != event.foe_id and _within(foe, event, limit):
			_hold_one(game, foe.id, lands_at)
	for id: int in _known:
		var foe: Foe = _known[id]
		if id != event.foe_id and not _is_live(game, id) and _within(foe, event, limit):
			_hold_one(game, id, lands_at)


## The sim killed foe `id` (FOE_KILLED). Returns true when a shot to it is still on its way,
## so the kill shows (and sounds) when that shot lands rather than now.
func hold_kill(id: int) -> bool:
	if not _pending.has(id):
		return false
	_killed[id] = true
	return true


## Foe `id` left the board without being killed (it reached the Heartstone): nothing of it
## is held any more.
func release(id: int) -> void:
	_pending.erase(id)
	_base.erase(id)
	_ghosts.erase(id)
	_killed.erase(id)


## Moves the clock on by `seconds` of game time and lands the shots that have arrived.
func advance(seconds: float) -> void:
	_clock += seconds
	for id: int in _pending.keys():
		var shots: Array = _pending[id]
		while not shots.is_empty() and float(shots[0][0]) <= _clock + 1e-6:
			_base[id] = float(shots[0][1])
			shots.pop_front()
		if not shots.is_empty():
			continue
		_pending.erase(id)
		_base.erase(id)
		_ghosts.erase(id)
		if _killed.has(id):
			_killed.erase(id)
			_landed_kills += 1


## Reads the foes of this frame: what each shows, and which killed foes still stand.
func observe(game: GameState) -> void:
	_seen.clear()
	for foe in game.foes:
		_seen[foe.id] = foe
	for id: int in _known:
		if not _seen.has(id) and _pending.has(id):
			_ghosts[id] = _known[id]
	var spare := _known
	_known = _seen
	_seen = spare
	_shown.clear()
	for foe in game.foes:
		_shown[foe.id] = _base[foe.id] if _pending.has(foe.id) else foe.hp
	for id: int in _ghosts:
		_shown[id] = _base.get(id, 0.0)


## The foes to draw this frame: the game's, and the killed ones still standing.
func drawn_foes(game: GameState) -> Array[Foe]:
	if _ghosts.is_empty():
		return game.foes
	_drawn.assign(game.foes)
	for id: int in _ghosts:
		_drawn.append(_ghosts[id])
	return _drawn


## The health `foe` shows this frame.
func shown_hp(foe: Foe) -> float:
	return _shown.get(foe.id, foe.hp)


## Whether `foe` is a killed foe still standing until its shot lands.
func is_ghost(id: int) -> bool:
	return _ghosts.has(id)


## Whether a shot to foe `id` is still on its way.
func is_held(id: int) -> bool:
	return _pending.has(id)


## How many held kills landed since the last call (each one's snap plays now).
func take_landed_kills() -> int:
	var landed := _landed_kills
	_landed_kills = 0
	return landed


func _hold_one(game: GameState, id: int, lands_at: float) -> void:
	var foe := _find(game, id)
	if foe == null:
		return
	if not _pending.has(id):
		_pending[id] = []
		_base[id] = _shown.get(id, foe.max_hp)
	var after := foe.hp if foe.alive and _is_live(game, id) else 0.0
	(_pending[id] as Array).append([lands_at, after])


func _find(game: GameState, id: int) -> Foe:
	for foe in game.foes:
		if foe.id == id:
			return foe
	return _known.get(id, null)


func _is_live(game: GameState, id: int) -> bool:
	for foe in game.foes:
		if foe.id == id:
			return true
	return false


static func _within(foe: Foe, event: GameEvent, limit: float) -> bool:
	var dx := foe.x - event.x
	var dy := foe.y - event.y
	return dx * dx + dy * dy <= limit
