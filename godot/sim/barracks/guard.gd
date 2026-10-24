## A guard of a Guard Tent: it stands at a post on the route and holds one foe.
class_name Guard
extends Fighter

## The tower (a Guard Tent) it belongs to.
var tent_id: int = 0
## The route it stands on (0 is the main road, or a branch of a fork).
var route: int = 0
## Where it stands, in cells walked along `routes[route]`.
var post: float = 0.0
## Bonuses from a Kitchen Mess Tent whose aura holds the guard's post, set each tick:
## a share more blows, and hp a second more regeneration.
var speed_bonus: float = 0.0
var regen_bonus: float = 0.0
## Seconds left of a Shield Wall: the guard's armor is multiplied while it runs.
var wall_timer: float = 0.0
## The hp of the level before any Hardtack bonus, the share the aura adds now, and a Fortified
## Feast shield (hp it soaks) with the seconds it has left.
var base_max_hp: float = 0.0
var hp_bonus: float = 0.0
var shield_hp: float = 0.0
var shield_timer: float = 0.0
