## Holds back what a shot does to a foe until the drawn shot lands. The sim takes the health
## off (and removes a killed foe) the tick a tower fires, but the drawn dart or pellet takes a
## few stop-motion frames to get there. So a foe keeps showing the health it had, and a killed
## foe stays standing where it fell (with the Golem's goblins still inside it), until the shot
## that hit it lands. Hurt that has no drawn flight (beams, guards, zones, bleeding) shows at
## once. Main tells it about every tick (`before_tick`, then the tick's events, then
## `after_tick`) and every frame (`advance`, then `observe`). It only reads the game.
class_name HitHold
extends RefCounted

const FOES := preload("res://content/foes.gd")
## The shots on their way to each held foe, as [lands_at, hurt, tick]: `hurt` is the health
## it shows lost when it lands.
var _pending := {}
## The health a held foe shows: what it showed when it was first held, less the hurt of the
## shots that have landed since.
var _base := {}
## The held foes themselves, by id, so a killed one can still be drawn.
var _held_foes := {}
## The health each drawn foe shows this frame.
var _shown := {}
## Killed foes left standing until their shot lands, by id.
var _ghosts := {}
## Held foes the sim has killed: each one's kill shows when its last shot lands.
var _killed := {}
## Foes that split out of a killed foe still standing (the Golem's goblins), hidden until it
## falls: piece id to the id of the foe it came out of.
var _pieces := {}
## Each foe's health, and the foe, at the start of this tick: a shot held only the foes it
## hurt.
var _before_hp := {}
var _before_foes := {}
var _killed_this_tick: Array[int] = []
var _live := {}
var _drawn: Array[Foe] = []
var _clock := 0.0
var _tick := 0
var _landed_kills := 0


## Forgets everything (a new game starts: ids are used again).
func reset() -> void:
	_pending.clear()
	_base.clear()
	_held_foes.clear()
	_shown.clear()
	_ghosts.clear()
	_killed.clear()
	_pieces.clear()
	_before_hp.clear()
	_before_foes.clear()
	_killed_this_tick.clear()
	_live.clear()
	_drawn.clear()
	_clock = 0.0
	_tick = 0
	_landed_kills = 0


## Notes every foe's health before a tick runs.
func before_tick(game: GameState) -> void:
	_tick += 1
	_before_hp.clear()
	_before_foes.clear()
	_killed_this_tick.clear()
	for foe in game.foes:
		_before_hp[foe.id] = foe.hp
		_before_foes[foe.id] = foe


## A tower fired `event` (TOWER_FIRED) this tick, and its drawn shot lands `seconds` of game
## time from now. Holds the foes it hurt: its target, and for a blast every foe within the
## splash that lost health this tick (not one it could not reach, nor one that just leaked).
func hold(event: GameEvent, seconds: float) -> void:
	var lands_at := _clock + seconds
	if event.splash <= 0.0:
		_hold_if_hurt(event.foe_id, lands_at)
		return
	var limit := event.splash * event.splash
	for id: int in _before_foes:
		var foe: Foe = _before_foes[id]
		var dx := foe.x - event.x
		var dy := foe.y - event.y
		if id == event.foe_id or dx * dx + dy * dy <= limit:
			_hold_if_hurt(id, lands_at)


## The sim killed foe `id` (FOE_KILLED). Returns true when a shot to it is still on its way,
## so the kill shows (and sounds) when that shot lands rather than now.
func hold_kill(id: int) -> bool:
	if not _pending.has(id):
		return false
	_killed[id] = true
	_killed_this_tick.append(id)
	return true


## Foe `id` left the board without being killed (it reached the Heartstone): nothing of it
## is held any more.
func release(id: int) -> void:
	_drop(id)


## After a tick's events: the foes that split out of a killed foe still standing stay hidden
## inside it until it falls.
func after_tick(game: GameState) -> void:
	if _killed_this_tick.is_empty():
		return
	for foe in game.foes:
		if _before_hp.has(foe.id):
			continue
		for parent_id in _killed_this_tick:
			if _is_piece_of(foe, _held_foes[parent_id]):
				_pieces[foe.id] = parent_id
				break


## Moves the clock on by `seconds` of game time and lands the shots that have arrived, in
## the order they land.
func advance(seconds: float) -> void:
	_clock += seconds
	if _pending.is_empty():
		return
	for id: int in _pending.keys():
		var shots: Array = _pending[id]
		for i in range(shots.size() - 1, -1, -1):
			var shot: Array = shots[i]
			if float(shot[0]) > _clock + 1e-6:
				continue
			_base[id] = float(_base[id]) - float(shot[1])
			shots.remove_at(i)
		if not shots.is_empty():
			continue
		if _killed.has(id):
			_landed_kills += 1
		_drop(id)


## Reads the foes of this frame: what each shows, and which killed foes still stand.
func observe(game: GameState) -> void:
	_live.clear()
	for foe in game.foes:
		_live[foe.id] = true
	for id: int in _pending:
		if not _live.has(id):
			_ghosts[id] = _held_foes[id]
	_shown.clear()
	for foe in game.foes:
		_shown[foe.id] = _base[foe.id] if _pending.has(foe.id) else foe.hp
	for id: int in _ghosts:
		_shown[id] = _base.get(id, 0.0)


## The foes to draw this frame: the game's (less the pieces still inside a standing foe),
## and the killed ones still standing.
func drawn_foes(game: GameState) -> Array[Foe]:
	if _ghosts.is_empty() and _pieces.is_empty():
		return game.foes
	_drawn.clear()
	for foe in game.foes:
		if not _pieces.has(foe.id):
			_drawn.append(foe)
	for id: int in _ghosts:
		# a piece killed while still inside the foe it came out of is never seen
		if not _pieces.has(id):
			_drawn.append(_ghosts[id])
	return _drawn


## The health `foe` shows this frame.
func shown_hp(foe: Foe) -> float:
	return _shown.get(foe.id, foe.hp)


## Whether `id` is a killed foe still standing until its shot lands.
func is_ghost(id: int) -> bool:
	return _ghosts.has(id)


## Whether a shot to foe `id` is still on its way.
func is_held(id: int) -> bool:
	return _pending.has(id)


## Whether foe `id` split out of a killed foe that is still standing.
func is_hidden_piece(id: int) -> bool:
	return _pieces.has(id)


## How many held kills landed since the last call (each one's snap plays now).
func take_landed_kills() -> int:
	var landed := _landed_kills
	_landed_kills = 0
	return landed


func _hold_if_hurt(id: int, lands_at: float) -> void:
	var foe: Foe = _before_foes.get(id)
	if foe == null:
		return
	var before: float = _before_hp[id]
	if foe.hp >= before:
		return
	var hurt := before - (maxf(foe.hp, 0.0) if foe.alive else 0.0)
	if not _pending.has(id):
		_pending[id] = []
		_base[id] = _shown.get(id, before)
		_held_foes[id] = foe
	var shots: Array = _pending[id]
	for shot: Array in shots:
		if int(shot[2]) != _tick:
			continue
		# the hurt of one tick cannot be split between the shots that hit it in that tick:
		# it shows with the one that lands last
		if float(shot[0]) <= lands_at:
			shot[1] = 0.0
		else:
			hurt = 0.0
	shots.append([lands_at, hurt, _tick])


func _drop(id: int) -> void:
	_pending.erase(id)
	_base.erase(id)
	_held_foes.erase(id)
	_ghosts.erase(id)
	_killed.erase(id)
	if _pieces.is_empty():
		return
	for piece: int in _pieces.keys():
		if int(_pieces[piece]) == id:
			_pieces.erase(piece)


## Whether `foe`, new this tick, is one of the pieces `parent` splits into: the right type, on
## its route, where the split puts them (from where it fell back along the road).
static func _is_piece_of(foe: Foe, parent: Foe) -> bool:
	var def: Dictionary = FOES.DEFS.get(parent.type, {})
	if not def.has("splits_into") or foe.type != def.splits_into or foe.route != parent.route:
		return false
	var behind := parent.distance - foe.distance
	var reach := float(def.split_spacing) * float(int(def.split_count) - 1)
	return behind >= -1e-4 and behind <= reach + 1e-4
