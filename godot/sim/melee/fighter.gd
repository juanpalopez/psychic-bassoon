## One who fights foes hand to hand: a guard of a Guard Tent, and later the hero. It holds one
## foe at a time; how it moves and which foe it may take are its own (see `Melee`).
class_name Fighter
extends RefCounted

## Unique among the game's ids; a held foe names it in `engaged_guard_id`.
var id: int = 0
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
var alive: bool = true
## Seconds until it returns after a fall.
var respawn_timer: float = 0.0
## The foe it holds (its id), or -1.
var foe_id: int = -1
