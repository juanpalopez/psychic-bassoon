## The hero the player moves (#275): it walks a cell path over walkable ground.
class_name Hero
extends RefCounted

## A hero id from `content/heroes.gd`.
var type: String = ""
var hp: float = 0.0
var max_hp: float = 0.0
## Cells per second.
var speed: float = 0.0
## The cell it stands in, or last stood in while walking to the next.
var cell := Vector2i.ZERO
## Where it is, in cells (a cell's centre is its column and row plus a half).
var x: float = 0.0
var y: float = 0.0
## The cells still to walk, in order, each to its centre; empty when it stands.
var path: Array[Vector2i] = []
