## The generated board: the foes' routes and the grid they sit on.
class_name GameMap
extends RefCounted

## `PLOT` cells accept a tower; `ROAD` cells carry the foes.
enum Tile { PLOT, ROAD }

var seed: int = 0
## The main road in walking order, from the spawn row to the Heartstone.
var path: Array[Vector2i] = []
## Every route from the spawn to the Heartstone. `routes[0]` equals `path`;
## a second one leaves the main road, runs beside it and rejoins it. Each item
## is an `Array[Vector2i]`.
var routes: Array = []
## One `PackedByteArray` of `Tile` values per row.
var tiles: Array[PackedByteArray] = []
