## The Guard Tents' guards: they stand on the route near their tent, each holds
## one blockable foe that walks up to it, and fight it blow for blow. A held foe
## does not walk (see `Combat`); towers keep shooting it. A fallen guard is raised
## again at its post after a while. No random numbers are used.
class_name Barracks
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const RULES := preload("res://content/game_rules.gd")


## Raises the guards of a freshly built Guard Tent at their post.
static func raise_guards(game: GameState, tent: Tower) -> void:
	var def: Dictionary = TOWERS.DEFS[tent.type]
	var count: int = def.guard_count
	var middle := post_for(game, tent)
	for i in count:
		var guard := Guard.new()
		guard.id = game.next_id
		game.next_id += 1
		guard.tent_id = tent.id
		guard.radius = def.guard_radius
		var offset: float = (float(i) - float(count - 1) / 2.0) * float(def.guard_spacing)
		guard.post = clampf(middle + offset, 0.0, game.routes[0].total)
		_set_level(guard, def, tent.level)
		guard.hp = guard.max_hp
		game.guards.append(guard)
		_announce(game, GameEvent.Kind.GUARD_RAISED, guard)


## A tent went up a level: its guards get the level's numbers, and the hp the
## level adds.
static func level_up(game: GameState, tent: Tower) -> void:
	var def: Dictionary = TOWERS.DEFS[tent.type]
	for guard in game.guards:
		if guard.tent_id != tent.id:
			continue
		var before := guard.max_hp
		_set_level(guard, def, tent.level)
		if guard.alive:
			guard.hp = minf(guard.max_hp, guard.hp + guard.max_hp - before)


## A tent was sold: its guards go, and the foes they held walk on.
static func release_guards(game: GameState, tent: Tower) -> void:
	var kept: Array[Guard] = []
	for guard in game.guards:
		if guard.tent_id == tent.id:
			for foe in game.foes:
				if foe.engaged_guard_id == guard.id:
					foe.engaged_guard_id = -1
		else:
			kept.append(guard)
	game.guards = kept


## The distance along the main route of the road point nearest the tent's block
## (the one nearer the Heartstone on an exact tie; ties are common where the road
## bends around a block). The points are `GUARD_POST_STEP` apart and found by
## index, not by adding, so which of two tied points wins never depends on rounding.
## The tent's `range` is the reach shown to the player; a socket is always within
## the block touch distance of the road (`MapRules`), so the nearest point is in reach.
static func post_for(game: GameState, tent: Tower) -> float:
	var route := game.routes[0]
	var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
	var best := 0.0
	var best_distance := INF
	for i in int(floor(route.total / RULES.GUARD_POST_STEP)) + 1:
		var along := float(i) * RULES.GUARD_POST_STEP
		var at := route.position_at(along)
		var dx := at.x - centre.x
		var dy := at.y - centre.y
		var squared := dx * dx + dy * dy
		if squared <= best_distance:
			best_distance = squared
			best = along
	return best


## One tick of every guard: raise, heal, take a foe, fight.
static func step(game: GameState) -> void:
	if game.guards.is_empty():
		return
	_apply_auras(game)
	for guard in game.guards:
		if guard.shield_timer > 0.0:
			guard.shield_timer = maxf(0.0, guard.shield_timer - Game.TICK_SECONDS)
			if guard.shield_timer <= RULES.TIMER_EPSILON:
				guard.shield_timer = 0.0
				guard.shield_hp = 0.0
		if guard.wall_timer > 0.0:
			guard.wall_timer = maxf(0.0, guard.wall_timer - Game.TICK_SECONDS)
			if guard.wall_timer <= RULES.TIMER_EPSILON:
				guard.wall_timer = 0.0
		var tent := _tent_of(game, guard)
		var def: Dictionary = TOWERS.DEFS[tent.type]
		if not guard.alive:
			_wait_to_return(game, guard)
			continue
		var held := Melee.held_foe(game, guard)
		if held == null:
			guard.foe_id = -1
			guard.hp = minf(
				guard.max_hp,
				guard.hp + (float(def.regen[tent.level]) + guard.regen_bonus) * Game.TICK_SECONDS
			)
			held = _take_a_foe(game, guard)
		if held != null:
			_fight(game, guard, held)


## Gives each guard the bonus of the strongest Kitchen Mess Tent whose aura holds the
## guard's post (a distance from the middle of the tent's block, raised by its
## socket's elevation like a tower's reach). Auras do not add up.
static func _apply_auras(game: GameState) -> void:
	var tents: Array[Tower] = []
	for tower in game.towers:
		if TOWERS.DEFS[tower.type].get("support", false):
			tents.append(tower)
	for guard in game.guards:
		guard.speed_bonus = 0.0
		guard.regen_bonus = 0.0
		var toughness := 0.0
		var rush := 0.0
		if not tents.is_empty():
			var held := _aura_bonuses(game, guard, tents)
			toughness = held[0]
			rush = held[1]
		guard.speed_bonus += rush
		_set_toughness(guard, toughness)


## The strongest Mess Tent aura over a guard's post gives its speed and regeneration (set on the
## guard) and returns the spec bonuses: `[Hardtack hp share, Sugar Rush attack speed share]`.
static func _aura_bonuses(game: GameState, guard: Guard, tents: Array[Tower]) -> Array[float]:
	var toughness := 0.0
	var rush := 0.0
	var at := game.routes[0].position_at(guard.post)
	for tent in tents:
		var def: Dictionary = TOWERS.DEFS[tent.type]
		var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
		var dx := at.x - centre.x
		var dy := at.y - centre.y
		var reach := TowerFire.reach_of(game, tent)
		if dx * dx + dy * dy > reach * reach:
			continue
		guard.speed_bonus = maxf(guard.speed_bonus, float(def.guard_speed_bonus[tent.level]))
		guard.regen_bonus = maxf(guard.regen_bonus, float(def.guard_regen_bonus[tent.level]))
		var passive := Specs.passive_of(tent)
		match passive.get("kind", ""):
			"hardtack":
				toughness = maxf(toughness, float(passive.bonus))
			"sugar_rush":
				rush = maxf(rush, float(passive.bonus))
	return [toughness, rush]


## Hardtack Toughness: the guard's max hp follows the share; added hp comes with it, and when the
## share goes the hp is clamped to the new max (never healed).
static func _set_toughness(guard: Guard, share: float) -> void:
	if share == guard.hp_bonus:
		return
	guard.hp_bonus = share
	var max_hp := guard.base_max_hp * (1.0 + share)
	var added := max_hp - guard.max_hp
	guard.max_hp = max_hp
	if added > 0.0 and guard.alive:
		guard.hp += added
	guard.hp = minf(guard.hp, guard.max_hp)


static func _set_level(guard: Guard, def: Dictionary, level: int) -> void:
	guard.base_max_hp = float(def.guard_hp[level])
	guard.max_hp = guard.base_max_hp * (1.0 + guard.hp_bonus)
	guard.armor = int(def.guard_armor[level])
	guard.damage = float(def.guard_damage[level])
	guard.interval = float(def.guard_interval[level])


static func _tent_of(game: GameState, guard: Guard) -> Tower:
	for tower in game.towers:
		if tower.id == guard.tent_id:
			return tower
	return null


## How far along the main route the foe is, or -1 when it is not on the main road yet: a foe
## of the second route is on it from the join on, `second_offset` further along its own route.
## On the old random detour (`random_lanes`) a foe of another lane is never on the main road.
## The join is tested in main-road terms (the main road's join cell): on curved routes the
## second route's own join point maps a little past it, which would let a foe walk through a
## guard posted between the two.
static func main_distance(game: GameState, foe: Foe) -> float:
	if foe.route == 0:
		return foe.distance
	if game.random_lanes:
		return -1.0
	var along := foe.distance - game.second_offset
	if along < game.routes[0].cell_distance(game.map.join_index):
		return -1.0
	return along


## The blockable, free foe nearest the guard's post that has walked up to it.
static func _take_a_foe(game: GameState, guard: Guard) -> Foe:
	var best: Foe = null
	var best_along := -1.0
	for foe in game.foes:
		if not foe.alive or not foe.blockable or foe.engaged_guard_id != -1:
			continue
		var along := main_distance(game, foe)
		var stop := guard.post - guard.radius - foe.radius
		if along < 0.0 or along < stop or along > guard.post:
			continue
		if best == null or along > best_along:
			best = foe
			best_along = along
	if best == null:
		return null
	Melee.hold(guard, best)
	var event := GameEvent.of(GameEvent.Kind.FOE_ENGAGED)
	event.tower_id = guard.tent_id
	event.guard_id = guard.id
	event.foe_id = best.id
	event.foe_type = best.type
	game.events.append(event)
	return best


static func _fight(game: GameState, guard: Guard, foe: Foe) -> void:
	var tent := _tent_of(game, guard)
	if Melee.strike(game, guard, foe, guard.speed_bonus):
		Specs.guard_struck(game, tent, foe)
	if Melee.foe_strikes(foe):
		var blow := Melee.blow(foe, Specs.guard_armor(guard, tent))
		if not Melee.blind_miss(foe):
			guard.hp -= Specs.guard_absorb(guard, blow)
			Specs.guard_hurt(game, tent, foe, blow)
	# a guard at 0 hp falls even when its blow was answered by a reflection that killed the foe
	if guard.hp <= 0.0:
		var def: Dictionary = TOWERS.DEFS[tent.type]
		Melee.fall(guard, foe, float(def.respawn[tent.level]))
		_announce(game, GameEvent.Kind.GUARD_FELL, guard)
	elif not foe.alive:
		Melee.release(foe, guard)


static func _wait_to_return(game: GameState, guard: Guard) -> void:
	if Melee.wait_to_return(guard):
		_announce(game, GameEvent.Kind.GUARD_RAISED, guard)


static func _announce(game: GameState, kind: GameEvent.Kind, guard: Guard) -> void:
	var event := GameEvent.of(kind)
	event.tower_id = guard.tent_id
	event.guard_id = guard.id
	game.events.append(event)
