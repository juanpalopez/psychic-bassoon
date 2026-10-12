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
var alive: bool = true
## Seconds until it is raised again after a fall.
var respawn_timer: float = 0.0
## The foe it holds (its id), or -1.
var foe_id: int = -1
