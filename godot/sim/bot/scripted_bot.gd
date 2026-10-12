## A deterministic player for balance runs. It only sends commands through
## `Game.submit`, never touches the state, and never sends one the sim would
## reject.
##
## It builds, in turn, the towers of its profile on the sockets that reach the
## most road (counted with a Spool Guard's reach and the socket's elevation
## bonus, from the block's centre; ties go to reading order), saving up when it
## cannot pay. Once every socket has a tower it upgrades, the lowest level and
## then the cheapest first. It launches the next wave when none is running (and,
## if its profile says so, early when few foes are left). One build or upgrade
## per tick, so it never spends the same Buttons twice.
class_name ScriptedBot
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const SCOUT_TOWER := "spoolGuard"

var _profile: Dictionary
var _map: GameMap = null
var _ranked: Array[Vector2i] = []


func _init(profile: Dictionary) -> void:
	_profile = profile


## Sends this tick's commands. Call it before `Game.tick`.
func act(game: GameState) -> void:
	if game.over:
		return
	_rank_sockets(game)
	_spend(game)
	_call_wave(game)


func _spend(game: GameState) -> void:
	var order: Array = _profile.build_order
	var free := _best_free_socket(game)
	if free != GameMap.NO_SOCKET and not order.is_empty():
		var type: String = order[game.towers.size() % order.size()]
		var cost: int = TOWERS.DEFS[type].cost[0]
		# save up for the next tower rather than upgrading past it
		if game.buttons >= cost:
			Game.submit(game, Command.build(type, free.x, free.y))
		return
	var target := _cheapest_upgrade(game)
	if target != null and game.buttons >= _next_cost(target):
		Game.submit(game, Command.upgrade(target.id))


func _call_wave(game: GameState) -> void:
	if not game.spawners.is_empty():
		return
	if not game.running:
		Game.submit(game, Command.launch_wave())
	elif _profile.call_early and game.foes.size() <= int(_profile.early_foes_left):
		Game.submit(game, Command.launch_wave())


## The lowest level tower, then the cheapest next upgrade, then the oldest;
## null when nothing can be upgraded.
func _cheapest_upgrade(game: GameState) -> Tower:
	var best: Tower = null
	for tower in game.towers:
		var cost := _next_cost(tower)
		if cost < 0:
			continue
		if best == null:
			best = tower
		elif tower.level < best.level:
			best = tower
		elif tower.level == best.level and cost < _next_cost(best):
			best = tower
	return best


## What the next upgrade of a tower costs, or -1 at the top level.
func _next_cost(tower: Tower) -> int:
	var costs: Array = TOWERS.DEFS[tower.type].cost
	if tower.level + 1 >= costs.size():
		return -1
	return costs[tower.level + 1]


func _best_free_socket(game: GameState) -> Vector2i:
	for anchor in _ranked:
		var taken := false
		for tower in game.towers:
			if tower.col == anchor.x and tower.row == anchor.y:
				taken = true
				break
		if not taken:
			return anchor
	return GameMap.NO_SOCKET


## Orders the map's sockets by the road they reach, most first; done once per map.
func _rank_sockets(game: GameState) -> void:
	if _map == game.map:
		return
	_map = game.map
	var reach_base: float = TOWERS.DEFS[SCOUT_TOWER].range[0]
	var scores := {}
	for anchor in _map.sockets:
		var centre := _map.socket_centre(anchor)
		var reach := reach_base * _map.range_multiplier(anchor)
		var covered := 0
		for cell in _map.path:
			var road := Vector2(float(cell.x) + 0.5, float(cell.y) + 0.5)
			if centre.distance_to(road) <= reach:
				covered += 1
		scores[anchor] = covered
	_ranked = _map.sockets.duplicate()
	# stable: Array.sort_custom is not, so ties are broken by reading order here
	var index := {}
	for i in _map.sockets.size():
		index[_map.sockets[i]] = i
	_ranked.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			if scores[a] != scores[b]:
				return scores[a] > scores[b]
			return index[a] < index[b]
	)
