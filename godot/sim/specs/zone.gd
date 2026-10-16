## An area an ability opened that keeps acting for a while: an Ink Vortex pulls foes towards
## its centre. Plain data; `Zones.step` runs it.
class_name Zone
extends RefCounted

var id: int = 0
var kind: String = ""
var tower_id: int = 0
## The centre on the board, in cells, the route of the foe it opened on and where it sits
## along the main road.
var x: float = 0.0
var y: float = 0.0
var route: int = 0
var distance: float = 0.0
var radius: float = 0.0
## Cells a second a foe is pulled along its road.
var pull: float = 0.0
## Seconds left.
var timer: float = 0.0
