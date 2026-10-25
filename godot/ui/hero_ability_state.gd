## What the hero's ability button shows, from the hero alone (a pure function, so it is tested
## without a scene). The sim stays the judge: a press on an enabled button can still be refused
## (no foe in reach), and the reject text says so.
class_name HeroAbilityState
extends RefCounted

const RULES := preload("res://content/game_rules.gd")
const WORD := "Whirl"
const CAST_MESSAGE := "Blade Whirl!"
const FALLEN_WORD := "Fallen"

var visible := false
var enabled := false
var text := WORD


## Whole seconds of cooldown left (0 when ready), which is all the button shows.
static func seconds_left(hero: Hero) -> int:
	if hero == null or hero.ability_cooldown <= RULES.TIMER_EPSILON:
		return 0
	return int(ceil(hero.ability_cooldown))


## The button's state for `hero` (null when the board has none). While `paused` the button is
## off, so no cast queues behind the pause.
static func of(hero: Hero, paused: bool = false) -> HeroAbilityState:
	var state := HeroAbilityState.new()
	if hero == null:
		return state
	state.visible = true
	if not hero.alive:
		state.text = FALLEN_WORD
	elif seconds_left(hero) > 0:
		state.text = "%s %ds" % [WORD, seconds_left(hero)]
	else:
		state.enabled = not paused
	return state
