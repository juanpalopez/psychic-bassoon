## A wave releasing its foes over time.
class_name Spawner
extends RefCounted

## The foes still to come, in order.
var queue: Array[SpawnOrder] = []
## Seconds until the next release.
var timer: float = 0.0
var wave: int = 0
