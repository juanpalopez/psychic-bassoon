## Tier 4: choosing a specialisation and using its active ability. A spec is
## chosen once, at the top level, for Buttons; its passive is read where it applies
## (`armor_ignore` in a shot) and its active runs on a command, then cools down.
## Uses no random numbers: a skewer hits the foes nearest the tower first.
class_name Specs
extends RefCounted

const TOWERS := preload("res://content/towers.gd")
const SPECS := preload("res://content/specs.gd")
const RULES := preload("res://content/game_rules.gd")


## CHOOSE_SPEC: the tower takes the spec for its cost; the cost counts as invested.
static func choose(game: GameState, command: Command) -> void:
	var tower := Game.find_tower(game, command.tower_id)
	if tower == null:
		return Game.reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	if tower.level + 1 < TOWERS.DEFS[tower.type].cost.size():
		return Game.reject(game, command, GameEvent.RejectReason.NOT_AT_TOP_LEVEL)
	if tower.spec != "":
		return Game.reject(game, command, GameEvent.RejectReason.SPEC_ALREADY_CHOSEN)
	var spec := SPECS.find(tower.type, command.spec)
	if spec.is_empty():
		return Game.reject(game, command, GameEvent.RejectReason.UNKNOWN_SPEC)
	var cost: int = spec.cost
	if game.buttons < cost:
		return Game.reject(game, command, GameEvent.RejectReason.NOT_ENOUGH_BUTTONS)
	game.buttons -= cost
	tower.invested += cost
	tower.spec = command.spec
	tower.ability_cooldown = 0.0
	var event := GameEvent.of(GameEvent.Kind.SPEC_CHOSEN)
	event.tower_id = tower.id
	event.spec = tower.spec
	game.events.append(event)


## ACTIVATE_ABILITY: runs the spec's active on its own target. Nothing is spent
## and the cooldown does not start when it is refused.
static func activate(game: GameState, command: Command) -> void:
	var tower := Game.find_tower(game, command.tower_id)
	if tower == null:
		return Game.reject(game, command, GameEvent.RejectReason.NO_SUCH_TOWER)
	if tower.spec == "":
		return Game.reject(game, command, GameEvent.RejectReason.NO_SPEC)
	if tower.ability_cooldown > RULES.TIMER_EPSILON:
		return Game.reject(game, command, GameEvent.RejectReason.ABILITY_COOLING_DOWN)
	var active: Dictionary = SPECS.find(tower.type, tower.spec).active
	var used := false
	match active.kind:
		"skewer":
			used = _skewer(game, tower, active)
	if not used:
		return Game.reject(game, command, GameEvent.RejectReason.NO_TARGET)
	tower.ability_cooldown = float(active.cooldown)


## Counts every ability cooldown down by a tick.
static func tick_cooldowns(game: GameState) -> void:
	for tower in game.towers:
		if tower.ability_cooldown > 0.0:
			tower.ability_cooldown = maxf(0.0, tower.ability_cooldown - Game.TICK_SECONDS)


## The share of a foe's armor that this tower's shots ignore (0 without the passive).
static func armor_ignore(tower: Tower) -> float:
	if tower.spec == "":
		return 0.0
	var passive: Dictionary = SPECS.find(tower.type, tower.spec).passive
	return float(passive.share) if passive.kind == "armor_ignore" else 0.0


## Heavy Skewer: a bolt from the tower through its target, as far as the tower
## reaches. Returns false when there is no target to aim at.
static func _skewer(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var to_x := target.x - centre.x
	var to_y := target.y - centre.y
	var length := sqrt(to_x * to_x + to_y * to_y)
	if length < RULES.TIMER_EPSILON:
		return false
	var dir_x := to_x / length
	var dir_y := to_y / length
	var reach := TowerFire.reach_of(game, tower)
	var def: Dictionary = TOWERS.DEFS[tower.type]
	# the foes on the line, by how far along it they stand (spawn order breaks a tie)
	var along: Array[float] = []
	var hit: Array[Foe] = []
	for foe in TowerFire.foes_within(game, centre.x, centre.y, reach):
		if not TowerFire.can_hit(def, foe):
			continue
		var rel_x := foe.x - centre.x
		var rel_y := foe.y - centre.y
		var ahead := rel_x * dir_x + rel_y * dir_y
		var aside := absf(rel_x * dir_y - rel_y * dir_x)
		if ahead < 0.0 or aside > float(active.width) + foe.radius:
			continue
		var at := along.size()
		while at > 0 and along[at - 1] > ahead:
			at -= 1
		along.insert(at, ahead)
		hit.insert(at, foe)
	var ignore := armor_ignore(tower)
	var kind := Damage.kind_named(def.damage_type)
	var count := mini(hit.size(), int(active.max_hits))
	for i in count:
		var foe := hit[i]
		Damage.apply(game, foe, float(active.damage), kind, ignore)
		if foe.alive:
			Status.apply_bleed(foe, float(active.bleed_dps), float(active.bleed_seconds))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.x2 = centre.x + dir_x * reach
	event.y2 = centre.y + dir_y * reach
	game.events.append(event)
	return true
