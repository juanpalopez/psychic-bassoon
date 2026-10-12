## How a hit hurts a foe. Physical damage is cut by the foe's armor, magic by its
## resist and true damage by neither; a hit never drops below a share of its
## damage. A foe that reaches 0 hp falls: it pays its reward once and is
## reported in a FOE_KILLED event. It uses no random numbers.
class_name Damage
extends RefCounted

enum Kind { PHYSICAL, MAGIC, TRUE }

const RULES := preload("res://content/game_rules.gd")
## The content names the kinds as strings.
const NAMES := {"physical": Kind.PHYSICAL, "magic": Kind.MAGIC, "true": Kind.TRUE}


## The kind a content name stands for. An unknown name is a content bug.
static func kind_named(name: String) -> Kind:
	if not NAMES.has(name):
		push_error("unknown damage type %s" % name)
		return Kind.PHYSICAL
	return NAMES[name]


## What `amount` of damage of `kind` comes to against `foe`'s defences.
static func after_defence(foe: Foe, amount: float, kind: Kind) -> float:
	# written so that NaN counts as no damage
	if not (amount > 0.0):
		return 0.0
	match kind:
		Kind.PHYSICAL:
			return maxf(amount * RULES.MIN_DAMAGE_FRACTION, amount - float(foe.armor))
		Kind.MAGIC:
			return maxf(amount * RULES.MIN_DAMAGE_FRACTION, amount - float(foe.resist))
	return amount


## Hurts `foe` and returns the hp it lost (never more than it had). A foe that
## has already fallen takes nothing.
static func apply(game: GameState, foe: Foe, amount: float, kind: Kind) -> float:
	return _hurt(game, foe, after_defence(foe, amount, kind))


## A beam's share of a tick: the defence is taken off the damage per second, as
## it would be off a shot, and only then is the result spread over `seconds`. A
## flat armor or resist taken off each tiny tick would eat the whole beam.
static func apply_beam(
	game: GameState, foe: Foe, damage_per_second: float, kind: Kind, seconds: float
) -> float:
	return _hurt(game, foe, after_defence(foe, damage_per_second, kind) * seconds)


static func _hurt(game: GameState, foe: Foe, amount: float) -> float:
	if not foe.alive:
		return 0.0
	var dealt := minf(amount, foe.hp)
	foe.hp -= dealt
	if foe.hp <= 0.0:
		foe.alive = false
		game.buttons += foe.reward
		var event := GameEvent.of(GameEvent.Kind.FOE_KILLED)
		event.foe_id = foe.id
		event.foe_type = foe.type
		event.reward = foe.reward
		event.x = foe.x
		event.y = foe.y
		game.events.append(event)
	return dealt
