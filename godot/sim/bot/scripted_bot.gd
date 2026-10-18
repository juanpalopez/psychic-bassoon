## A deterministic player for balance runs. It only sends commands through
## `Game.submit`, never touches the state, and never sends one the sim would
## reject.
##
## It builds, in turn, the towers of its profile on the sockets that reach the
## most road (counted with a Spool Guard's reach and the socket's elevation
## bonus, from the block's centre; ties go to reading order), saving up when it
## cannot pay. Once every socket has a tower, or it has `MAX_TOWERS` of them (the valley has
## twice the sockets a player can fill), it upgrades, the lowest level and then the cheapest
## first, and builds again only when every tower is at the top. It launches the next wave when none is running (and,
## if its profile says so, early when few foes are left). One build or upgrade
## per tick, so it never spends the same Buttons twice. A Kitchen Mess Tent goes on the
## free socket whose aura reaches the most guards (none before a Guard Tent stands);
## when no socket suits the next tower of its order it builds the next one instead.
class_name ScriptedBot
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const PROFILES := preload("res://content/bot_profiles.gd")
const SCOUT_TOWER := "spoolGuard"

var _profile: Dictionary
var _map: GameMap = null
var _ranked: Array[Vector2i] = []


func _init(profile: Dictionary) -> void:
	_profile = profile


## Sends this tick's commands. Call it before `Game.tick`.
func act(game: GameState) -> void:
	if game.over or game.won:
		return
	_rank_sockets(game)
	_spend(game)
	_call_wave(game)


func _spend(game: GameState) -> void:
	var order: Array = _profile.build_order
	var free := _best_free_socket(game)
	var upgrade := _cheapest_upgrade(game)
	var room: bool = game.towers.size() < int(_profile.get("max_towers", PROFILES.MAX_TOWERS))
	if free != GameMap.NO_SOCKET and not order.is_empty() and (room or upgrade == null):
		var next := _next_build(game, order)
		var type: String = next.type
		var spot: Vector2i = next.socket
		var cost: int = TOWERS.DEFS[type].cost[0]
		# save up for the next tower rather than upgrading past it
		if game.buttons >= cost:
			Game.submit(game, Command.build(type, spot.x, spot.y))
		return
	if upgrade != null and game.buttons >= _next_cost(upgrade):
		Game.submit(game, Command.upgrade(upgrade.id))


## The tower of the order to build next and where: the one its turn names, or the
## first after it that has a socket to go on (a Spool Guard when none has).
func _next_build(game: GameState, order: Array) -> Dictionary:
	for k in order.size():
		var type: String = order[(game.towers.size() + k) % order.size()]
		var spot := _socket_for(game, type)
		if spot != GameMap.NO_SOCKET:
			return {"type": type, "socket": spot}
	return {"type": SCOUT_TOWER, "socket": _best_free_socket(game)}


## Where a tower of `type` goes: the free socket that reaches the most road, or for
## a support tower the one whose aura reaches the most guards (nearest first).
func _socket_for(game: GameState, type: String) -> Vector2i:
	if not TOWERS.DEFS[type].get("support", false):
		return _best_free_socket(game)
	var reach_base: float = TOWERS.DEFS[type].range[0]
	var best := GameMap.NO_SOCKET
	var best_covered := 0
	var best_distance := INF
	for anchor in _ranked:
		if _is_taken(game, anchor):
			continue
		var centre := game.map.socket_centre(anchor)
		var reach := reach_base * game.map.range_multiplier(anchor)
		var covered := 0
		var distance := 0.0
		for guard in game.guards:
			var at := game.routes[0].position_at(guard.post)
			var gap := centre.distance_to(Vector2(at.x, at.y))
			if gap <= reach:
				covered += 1
				distance += gap
		if (
			covered > best_covered
			or (covered == best_covered and covered > 0 and distance < best_distance)
		):
			best = anchor
			best_covered = covered
			best_distance = distance
	return best


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
		if not _is_taken(game, anchor):
			return anchor
	return GameMap.NO_SOCKET


func _is_taken(game: GameState, anchor: Vector2i) -> bool:
	for tower in game.towers:
		if tower.col == anchor.x and tower.row == anchor.y:
			return true
	return false


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
