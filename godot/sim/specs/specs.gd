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
		"fortified_feast":
			used = _fortified_feast(game, tower, active)
		"boiling_broth":
			used = _boiling_broth(game, tower, active)
		"shield_wall":
			used = _shield_wall(game, tower, active)
		"precision_snipe":
			used = _precision_snipe(game, tower, active)
		"squadron":
			used = _squadron(game, tower, active)
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
		var reach := TowerFire.reach_to(game, tower, foe)
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


## High Recon: the share added to a tower's reach by an Aviary next to it (the strongest applies; an
## Aviary does not widen its own reach). "Next to" is within the passive's `gap` cells of its block.
static func recon_bonus(game: GameState, tower: Tower) -> float:
	var best := 0.0
	var here := Vector2.ZERO
	var placed := false
	for other in game.towers:
		# this runs for every reach: most towers have no spec, so skip them first
		if other == tower or other.spec == "":
			continue
		var passive := passive_of(other)
		if passive.get("kind", "") != "recon" or float(passive.bonus) <= best:
			continue
		if not placed:
			here = game.map.socket_centre(Vector2i(tower.col, tower.row))
			placed = true
		var there := game.map.socket_centre(Vector2i(other.col, other.row))
		if adjacent(here, there, float(game.map.footprint), float(passive.gap)):
			best = float(passive.bonus)
	return best


## Whether two blocks of `footprint` cells, with these centres, lie within `gap` cells of each other
## on both axes (diagonal neighbours count; a block just past the gap on one axis does not).
static func adjacent(a: Vector2, b: Vector2, footprint: float, gap: float) -> bool:
	var reach := footprint + gap
	return absf(a.x - b.x) <= reach and absf(a.y - b.y) <= reach


## A guard's armor: its own, multiplied while a Shield Wall of its tent runs.
static func guard_armor(guard: Guard, tent: Tower) -> float:
	var armor := float(guard.armor)
	if guard.wall_timer > 0.0 and tent != null:
		var spec := SPECS.find(tent.type, tent.spec)
		if not spec.is_empty() and spec.active.kind == "shield_wall":
			armor *= float(spec.active.armor_mult)
	return armor


## A blow on a guard: the Fortified Feast shield soaks what it can first. Returns what is left
## for the guard's hp.
static func guard_absorb(guard: Guard, blow: float) -> float:
	if guard.shield_hp <= 0.0:
		return blow
	var soaked := minf(guard.shield_hp, blow)
	guard.shield_hp -= soaked
	return blow - soaked


## Corrugated Plating: a blow that landed on a guard comes back as true damage to the attacker.
static func guard_hurt(game: GameState, tent: Tower, foe: Foe, blow: float) -> void:
	var passive := passive_of(tent) if tent != null else {}
	if passive.get("kind", "") == "plating":
		Damage.apply(game, foe, blow * float(passive.share), Damage.Kind.TRUE)


## Paper Cuts: a foe a guard struck is slowed a step more, up to a few steps, for a while.
static func guard_struck(_game: GameState, tent: Tower, foe: Foe) -> void:
	var passive := passive_of(tent) if tent != null else {}
	if passive.get("kind", "") != "paper_cuts" or not foe.alive:
		return
	foe.cut_stacks = mini(foe.cut_stacks + 1, int(passive.max_stacks))
	foe.cut_slow = float(passive.slow)
	foe.cut_timer = float(passive.seconds)


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
	for foe in TowerFire.foes_within_reach(game, centre.x, centre.y, reach):
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
	# the bolt runs to the far edge of the band, where a ground foe is still in reach
	var end := TowerFire.ground_reach_of(game, tower)
	event.x2 = centre.x + dir_x * end
	event.y2 = centre.y + dir_y * end
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
	for foe in TowerFire.foes_within_reach(game, centre.x, centre.y, reach):
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


## Squadron Launch: the planes take off when a foe is in reach to bomb. Returns false when none is.
static func _squadron(game: GameState, tower: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, tower)
	if target == null:
		return false
	Zones.open_squadron(game, tower, active)
	var centre := game.map.socket_centre(Vector2i(tower.col, tower.row))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tower.id
	event.foe_id = target.id
	event.x = centre.x
	event.y = centre.y
	event.splash = TowerFire.reach_of(game, tower)
	game.events.append(event)
	return true


## Shield Wall: the tent's guards double their armor for a while. Returns false when none stands.
static func _shield_wall(game: GameState, tent: Tower, active: Dictionary) -> bool:
	var any := false
	for guard in game.guards:
		if guard.tent_id == tent.id and guard.alive:
			any = true
	if not any:
		return false
	for guard in game.guards:
		if guard.tent_id == tent.id:
			guard.wall_timer = float(active.seconds)
	var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tent.id
	event.x = centre.x
	event.y = centre.y
	event.splash = TowerFire.reach_of(game, tent)
	game.events.append(event)
	return true


## Precision Snipe: a guard leaps at the ground foe with the most hp in the tent's reach (the
## first to spawn on a tie) for true damage. Returns false without a guard on its feet or a foe.
static func _precision_snipe(game: GameState, tent: Tower, active: Dictionary) -> bool:
	var any := false
	for guard in game.guards:
		if guard.tent_id == tent.id and guard.alive:
			any = true
	if not any:
		return false
	var centre := game.map.socket_centre(Vector2i(tent.col, tent.row))
	var best: Foe = null
	for foe in TowerFire.foes_within_reach(
		game, centre.x, centre.y, TowerFire.reach_of(game, tent)
	):
		if foe.flying:
			continue
		if best == null or foe.hp > best.hp:
			best = foe
	if best == null:
		return false
	Damage.apply(game, best, float(active.damage), Damage.Kind.TRUE)
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = tent.id
	event.foe_id = best.id
	event.x = best.x
	event.y = best.y
	game.events.append(event)
	return true


## The guards on their feet whose post lies inside the Mess Tent's aura.
static func _guards_in_aura(game: GameState, mess: Tower) -> Array[Guard]:
	var found: Array[Guard] = []
	var centre := game.map.socket_centre(Vector2i(mess.col, mess.row))
	var reach := TowerFire.ground_reach_of(game, mess)
	for guard in game.guards:
		if not guard.alive:
			continue
		var at := game.routes[0].position_at(guard.post)
		var dx := at.x - centre.x
		var dy := at.y - centre.y
		if dx * dx + dy * dy <= reach * reach:
			found.append(guard)
	return found


## Fortified Feast: every guard in the aura gets a shield for a while. False without a guard there.
static func _fortified_feast(game: GameState, mess: Tower, active: Dictionary) -> bool:
	var fed := _guards_in_aura(game, mess)
	if fed.is_empty():
		return false
	for guard in fed:
		guard.shield_hp = float(active.shield)
		guard.shield_timer = float(active.seconds)
	var centre := game.map.socket_centre(Vector2i(mess.col, mess.row))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = mess.id
	event.x = centre.x
	event.y = centre.y
	event.splash = TowerFire.reach_of(game, mess)
	game.events.append(event)
	return true


## Boiling Broth Splash: scalding stew on the ground target's place burns and slows every ground
## foe around it. False when no ground foe is in reach.
static func _boiling_broth(game: GameState, mess: Tower, active: Dictionary) -> bool:
	var target := TowerFire.target_for(game, mess, true)
	if target == null:
		return false
	for foe in TowerFire.foes_within(game, target.x, target.y, float(active.radius)):
		if foe.flying:
			continue
		Damage.apply(game, foe, float(active.damage), Damage.Kind.MAGIC)
		if foe.alive:
			Status.apply_slow(foe, float(active.slow), float(active.seconds))
	var event := GameEvent.of(GameEvent.Kind.ABILITY_USED)
	event.tower_id = mess.id
	event.foe_id = target.id
	event.x = target.x
	event.y = target.y
	event.splash = float(active.radius)
	game.events.append(event)
	return true
