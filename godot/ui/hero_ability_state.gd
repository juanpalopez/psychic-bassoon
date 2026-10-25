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


## The button's state for `hero` (null when the board has none).
static func of(hero: Hero) -> HeroAbilityState:
	var state := HeroAbilityState.new()
	if hero == null:
		return state
	state.visible = true
	if not hero.alive:
		state.text = FALLEN_WORD
	elif hero.ability_cooldown > RULES.TIMER_EPSILON:
		state.text = "%s %ds" % [WORD, int(ceil(hero.ability_cooldown))]
	else:
		state.enabled = true
	return state
