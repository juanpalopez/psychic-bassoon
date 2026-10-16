## A foe walking a route. It is removed from the game when `alive` is false.
class_name Foe
extends RefCounted

var id: int = 0
## The wave it came in: its strength, and what it splits into, follow from it.
var wave: int = 0
## A foe id from `content/foes.gd`, such as "scrapGoblin".
var type: String = ""
## Health is a float: a hit is a fraction (armor, a beam tick).
var hp: float = 0.0
var max_hp: float = 0.0
## Cells per second before any slow.
var speed: float = 0.0
## Buttons paid when it is destroyed.
var reward: int = 0
## Cuts physical damage.
var armor: int = 0
## Cuts magic damage.
var resist: int = 0
## Body radius, in cells.
var radius: float = 0.0
## Heartstone health lost when it gets through.
var leak: int = 0
## Index into `GameState.routes` of the route this foe walks.
var route: int = 0
## Cells walked from the spawn point.
var distance: float = 0.0
var x: float = 0.0
var y: float = 0.0
## Share of speed lost, 0 to 1, while `slow_timer` runs.
var slow: float = 0.0
var slow_timer: float = 0.0
var alive: bool = true
## A guard (`GameState.guards`) holding this foe still, or -1. A held foe does not walk.
var engaged_guard_id: int = -1
## Damage per blow and seconds between blows when it fights a guard.
var attack_damage: float = 0.0
var attack_interval: float = 0.0
var attack_cooldown: float = 0.0
## Whether a guard can stop it.
var blockable: bool = true
## A support foe: towers shoot it first, and it has an aura (radius in cells, heal as a share of
## max health a second, share more speed for the foes in it).
var support: bool = false
var aura_radius: float = 0.0
var aura_heal: float = 0.0
var aura_speed: float = 0.0
## A flying foe walks `GameState.air_routes[route]`, a straight line, and ignores guards.
var flying: bool = false
## The share more speed an Ink Shaman's aura gives this foe this tick (0 outside any aura).
var speed_buff: float = 0.0
## Bleed: true damage a second while `bleed_timer` runs.
var bleed_dps: float = 0.0
var bleed_timer: float = 0.0
## Share of its armor stripped away (0 to 1), kept by the foe (Blot Singularity's Corrosive Light).
var armor_strip: float = 0.0
## Seconds left frozen in wax (Flash Freeze): it does not walk and does not strike.
var freeze_timer: float = 0.0
## A heavy foe is not pulled by an Ink Vortex.
var heavy: bool = false
## Share of its melee blows it misses while `blind_timer` runs, and the tally that decides which
## blows miss (each blow adds `blind`; a whole tally is a miss and costs 1).
var blind: float = 0.0
var blind_timer: float = 0.0
var miss_tally: float = 0.0
## Paper Cuts: stacks of a speed cut (each takes `cut_slow` of the pace) and the seconds until they
## wear off.
var cut_stacks: int = 0
var cut_slow: float = 0.0
var cut_timer: float = 0.0
