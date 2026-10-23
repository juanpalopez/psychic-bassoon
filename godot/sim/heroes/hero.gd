## The hero the player moves (#275): it walks a cell path over walkable ground and fights foes
## hand to hand like a guard (#451).
class_name Hero
extends Fighter

## A hero id from `content/heroes.gd`.
var type: String = ""
## Cells per second.
var speed: float = 0.0
## The cell it stands in, or last stood in while walking to the next.
var cell := Vector2i.ZERO
## Where it is, in cells (a cell's centre is its column and row plus a half).
var x: float = 0.0
var y: float = 0.0
## The cells still to walk, in order, each to its centre; empty when it stands.
var path: Array[Vector2i] = []
## The foe it broke off from that keeps striking while the hero stays in its reach, or -1.
var chaser_id: int = -1
