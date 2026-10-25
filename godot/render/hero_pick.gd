## What a tap means once there is a hero to move (#335): plain maths, so it can be tested. A tap
## on the hero selects it (or lets it go), a tap on walkable ground with the hero selected sends
## it there, and any other tap lets the hero go and carries on as it did before.
class_name HeroPick
extends RefCounted

enum Action { NONE, SELECT, DESELECT, MOVE }


## Whether a tap landed on the hero: within half of the least tap target (`tap_pixels`, 44 pt in
## canvas pixels) of where the hero is drawn, so the hero is a 44 pt target however small it is.
static func hits_hero(tap: Vector2, hero_on_screen: Vector2, tap_pixels: float) -> bool:
	return tap.distance_to(hero_on_screen) <= tap_pixels / 2.0


## What to do with a tap. `on_hero`: the tap hit the hero (false for a fallen one);
## `selected`: the hero is selected; `walkable`: the tapped cell is ground the hero can stand on.
static func resolve(on_hero: bool, selected: bool, walkable: bool) -> Action:
	if on_hero:
		return Action.DESELECT if selected else Action.SELECT
	if not selected:
		return Action.NONE
	return Action.MOVE if walkable else Action.DESELECT
