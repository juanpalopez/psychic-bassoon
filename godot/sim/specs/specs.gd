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
		"flash_freeze":
			used = _flash_freeze(game, tower, active)
		"ink_vortex":
			used = _ink_vortex(game, tower, active)
		"confetti_burst":
			used = _confetti_burst(game, tower, active)
		"pva_deluge":
			used = _pva_deluge(game, tower, active)
	if not used:
		return Game.reject(game, command, GameEvent.RejectReason.NO_TARGET)
	tower.ability_cooldown = float(active.cooldown)


## Counts every ability cooldown down by a tick.
static func tick_cooldowns(game: GameState) -> void:
	for tower in game.towers:
		if tower.ability_cooldown > 0.0:
			tower.ability_cooldown = maxf(0.0, tower.ability_cooldown - Game.TICK_SECONDS)


## The tower's spec passive, or an empty dictionary without a spec.
static func passive_of(tower: Tower) -> Dictionary:
	if tower.spec == "":
		return {}
	return SPECS.find(tower.type, tower.spec).passive


## The share of a foe's armor that this tower's shots ignore (0 without the passive).
static func armor_ignore(tower: Tower) -> float:
	var passive := passive_of(tower)
	return float(passive.share) if passive.get("kind", "") == "armor_ignore" else 0.0


## Frostbite: the share added to physical damage dealt to a foe that is slowed or frozen while it
## stands inside the reach of a Cryo-Origami Spire. The strongest bonus applies; they do not add up.
static func frostbite_bonus(game: GameState, foe: Foe) -> float:
	var slowed := foe.slow_timer > RULES.TIMER_EPSILON or foe.freeze_timer > RULES.TIMER_EPSILON
	if not slowed:
		return 0.0
	var best := 0.0
	for tower in game.towers:
		var passive := passive_of(tower)
		if passive.get("kind", "") != "frostbite" or float(passive.bonus) <= best:
			continue
		var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
		var reach := TowerFire.reach_of(game, tower)
		var dx := foe.x - centre.x
		var dy := foe.y - centre.y
		if dx * dx + dy * dy <= reach * reach:
			best = float(passive.bonus)
	return best


## Shrapnel Spread: the share added to a shell's blast radius (0 without the passive).
static func splash_bonus(tower: Tower) -> float:
	var passive := passive_of(tower)
	return float(passive.bonus) if passive.get("kind", "") == "splash_bonus" else 0.0


## Lingering Residue: a shell of this tower leaves a pool where it lands, as wide as the blast.
static func leave_residue(game: GameState, tower: Tower, at: Foe, radius: float) -> void:
	var passive := passive_of(tower)
	if passive.get("kind", "") != "residue":
		return
	Zones.open_pool(game, tower, at, radius, float(passive.slow), float(passive.seconds))


## The share added to a tower's damage of this kind against this foe (Frostbite hits physical only).
static func damage_bonus(game: GameState, foe: Foe, kind: Damage.Kind) -> float:
	return frostbite_bonus(game, foe) if kind == Damage.Kind.PHYSICAL else 0.0


## Corrosive Light: a beam that burns a foe strips a share of its armor each second, up to a cap.
static func corrode(tower: Tower, foe: Foe) -> void:
	var passive := passive_of(tower)
	if passive.get("kind", "") != "corrode":
		return
	foe.armor_strip = minf(
		float(passive.max), foe.armor_strip + float(passive.per_second) * Game.TICK_SECONDS
	)


## Heavy Skewer: a bolt from the tower through its target, as far as the tower
## reaches. Returns false when there is no target to aim at. Only the `max_hits` foes
## nearest the tower are hit, so the target itself can be missed when that many stand nearer.
static func _skewer(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var to_x := target.x - centre.x
	var to_y := target.y - centre.y
	var length := sqrt(to_x * to_x + to_y * to_y)
	if length < RULES.DISTANCE_EPSILON:
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
		Damage.apply(game, foe, float(active.damage), kind, ignore, damage_bonus(game, foe, kind))
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


## Flash Freeze: every foe in reach the tower can hit freezes for the active's seconds. Returns
## false when no foe is in reach.
static func _flash_freeze(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var reach := TowerFire.reach_of(game, tower)
	var def: Dictionary = TOWERS.DEFS[tower.type]
	for foe in TowerFire.foes_within(game, centre.x, centre.y, reach):
		if TowerFire.can_hit(def, foe):
			foe.freeze_timer = maxf(foe.freeze_timer, float(active.seconds))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = centre.x
	event.y = centre.y
	event.splash = reach
	game.events.append(event)
	return true


## Ink Vortex: opens a well at the tower's best ground target on the main road. Returns false when
## there is none.
static func _ink_vortex(game: GameState, tower: Tower, active: Dictionary) -> bool:
	# the well sits on the road, so a flying foe is never its centre; a foe still on the
	# second road's feeder has no place on the main road yet
	var target := TowerFire.target_for(game, tower, true)
	if target == null or Barracks.main_distance(game, target) < 0.0:
		return false
	Zones.open_vortex(
		game, tower, target, float(active.radius), float(active.pull), float(active.seconds)
	)
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.splash = float(active.radius)
	game.events.append(event)
	return true


## Confetti Burst: a shell at the target that hurts and blinds every foe in its blast.
static func _confetti_burst(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	var def: Dictionary = TOWERS.DEFS[tower.type]
	var kind := Damage.kind_named(def.damage_type)
	var ignore := armor_ignore(tower)
	for foe in TowerFire.foes_within(game, target.x, target.y, float(active.radius)):
		if not TowerFire.can_hit(def, foe):
			continue
		Damage.apply(game, foe, float(active.damage), kind, ignore, damage_bonus(game, foe, kind))
		if foe.alive:
			Status.apply_blind(foe, float(active.blind), float(active.seconds))
	_announce(game, tower, target, float(active.radius))
	return true


## PVA Deluge: every foe in the area around the target is slowed hard for a while.
static func _pva_deluge(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	var def: Dictionary = TOWERS.DEFS[tower.type]
	for foe in TowerFire.foes_within(game, target.x, target.y, float(active.radius)):
		if TowerFire.can_hit(def, foe):
			Status.apply_slow(foe, float(active.slow), float(active.seconds))
	_announce(game, tower, target, float(active.radius))
	return true


static func _announce(game: GameState, tower: Tower, target: Foe, radius: float) -> void:
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.splash = radius
	game.events.append(event)
