## The melee context: a `Fighter` holds one foe, and they trade blows each tick until one falls
## or the foe is released. A held foe does not walk (see `Combat`). Which foe a fighter may take,
## the armor and shields that cut a blow, and what a blow sets off are left to the caller. No
## random numbers are used.
class_name Melee
extends RefCounted

const RULES := preload("res://content/game_rules.gd")


## The living foe `fighter` holds, or null.
static func held_foe(game: GameState, fighter: Fighter) -> Foe:
	if fighter.foe_id == -1:
		return null
	for foe in game.foes:
		if foe.id == fighter.foe_id:
			if foe.alive:
				return foe
			break
	return null


## `fighter` takes `foe`: both strike at once.
static func hold(fighter: Fighter, foe: Foe) -> void:
	foe.engaged_guard_id = fighter.id
	foe.attack_cooldown = 0.0
	fighter.foe_id = foe.id
	fighter.cooldown = 0.0


## `foe` walks on and `fighter` holds nothing.
static func release(foe: Foe, fighter: Fighter) -> void:
	foe.engaged_guard_id = -1
	fighter.foe_id = -1


## One tick of the fighter's blows: when its cooldown runs out it hits `foe` (physical damage)
## and waits its interval, shortened by `speed_bonus` (a share more blows). Returns whether it hit.
static func strike(game: GameState, fighter: Fighter, foe: Foe, speed_bonus: float) -> bool:
	fighter.cooldown -= Game.TICK_SECONDS
	if fighter.cooldown <= RULES.TIMER_EPSILON:
		fighter.cooldown += fighter.interval / (1.0 + speed_bonus)
		Damage.apply(game, foe, fighter.damage, Damage.Kind.PHYSICAL)
		return true
	return false


## One tick of a held foe's blows. Returns whether it strikes now. A frozen foe's cooldown stands
## still, so its next blow waits for the ice to go.
static func foe_strikes(foe: Foe) -> bool:
	if foe.freeze_timer <= RULES.TIMER_EPSILON:
		foe.attack_cooldown -= Game.TICK_SECONDS
	if foe.attack_cooldown <= RULES.TIMER_EPSILON and foe.alive:
		foe.attack_cooldown += foe.attack_interval
		return true
	return false


## A foe's blow against `armor`, never below a share of its damage.
static func blow(foe: Foe, armor: float) -> float:
	return maxf(foe.attack_damage * RULES.MIN_DAMAGE_FRACTION, foe.attack_damage - armor)


## Whether a blind foe's blow misses: each blow adds its blind share to a tally and a whole tally
## is a miss, so the misses are exactly the share and no random number is drawn.
static func blind_miss(foe: Foe) -> bool:
	if foe.blind <= 0.0:
		return false
	foe.miss_tally += foe.blind
	if foe.miss_tally >= 1.0 - RULES.TIMER_EPSILON:
		foe.miss_tally -= 1.0
		return true
	return false


## `fighter` falls: it lets `foe` (if it holds one) go and returns after `respawn` seconds.
static func fall(fighter: Fighter, foe: Foe, respawn: float) -> void:
	if foe != null:
		release(foe, fighter)
	fighter.foe_id = -1
	fighter.alive = false
	fighter.hp = 0.0
	fighter.respawn_timer = respawn


## One tick of a fallen fighter's wait. Returns true on the tick it is back, at full hp; where it
## comes back is the caller's.
static func wait_to_return(fighter: Fighter) -> bool:
	fighter.respawn_timer -= Game.TICK_SECONDS
	if fighter.respawn_timer > RULES.TIMER_EPSILON:
		return false
	fighter.alive = true
	fighter.hp = fighter.max_hp
	fighter.respawn_timer = 0.0
	return true
