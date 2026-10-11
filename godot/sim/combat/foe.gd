## A foe walking a route. It is removed from the game when `alive` is false.
class_name Foe
extends RefCounted

var id: int = 0
## A foe id from `content/foes.gd`, such as "scrapGoblin".
var type: String = ""
var hp: int = 0
var max_hp: int = 0
## Cells per second before any slow.
var speed: float = 0.0
## Buttons paid when it is destroyed.
var reward: int = 0
var armor: int = 0
## Body radius, in cells.
var radius: float = 0.0
## Kingdom health lost when it gets through.
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
