## A guard of a Guard Tent: it stands at a post on the route and holds one foe.
class_name Guard
extends RefCounted

var id: int = 0
## The tower (a Guard Tent) it belongs to.
var tent_id: int = 0
var hp: float = 0.0
var max_hp: float = 0.0
var armor: int = 0
## Damage per blow, and seconds between blows.
var damage: float = 0.0
var interval: float = 0.0
## Seconds until its next blow.
var cooldown: float = 0.0
## Body radius, in cells.
var radius: float = 0.0
## Where it stands, in cells walked along `routes[0]`.
var post: float = 0.0
## Bonuses from a Kitchen Mess Tent whose aura holds the guard's post, set each tick:
## a share more blows, and hp a second more regeneration.
var speed_bonus: float = 0.0
var regen_bonus: float = 0.0
var alive: bool = true
## Seconds until it is raised again after a fall.
var respawn_timer: float = 0.0
## The foe it holds (its id), or -1.
var foe_id: int = -1
## Seconds left of a Shield Wall: the guard's armor is multiplied while it runs.
var wall_timer: float = 0.0
## The hp of the level before any Hardtack bonus, the share the aura adds now, and a Fortified
## Feast shield (hp it soaks) with the seconds it has left.
var base_max_hp: float = 0.0
var hp_bonus: float = 0.0
var shield_hp: float = 0.0
var shield_timer: float = 0.0
