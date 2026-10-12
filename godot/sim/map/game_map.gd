## The generated board: the foes' routes and the grid they sit on.
class_name GameMap
extends RefCounted

## `PLOT` cells accept a tower; `ROAD` cells carry the foes.
enum Tile { PLOT, ROAD }

const RULES := preload("res://content/map_rules.gd")

var seed: int = 0
## Board size in cells.
var cols: int = 0
var rows: int = 0
## The main road in walking order, from the spawn row to the Heartstone.
var path: Array[Vector2i] = []
## Every route from the spawn to the Heartstone. `routes[0]` equals `path`;
## a second one leaves the main road, runs beside it and rejoins it. Each item
## is an `Array[Vector2i]`.
var routes: Array = []
## One `PackedByteArray` of `Tile` values per row.
var tiles: Array[PackedByteArray] = []
## The cells where a tower can be built, in reading order (row, then column).
var sockets: Array[Vector2i] = []
## One `PackedByteArray` of elevation levels (0 to 2) per row. Roads and plain
## ground are level 0; only sockets stand higher.
var elevation: Array[PackedByteArray] = []


## True when a tower can be built on the cell.
func is_socket(cell: Vector2i) -> bool:
	return sockets.has(cell)


## The elevation level of a cell (0 off the board).
func elevation_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= elevation.size() or cell.x < 0 or cell.x >= elevation[cell.y].size():
		return 0
	return elevation[cell.y][cell.x]


## How much further a tower on this cell reaches: 1.0, or 1.15 on level 2.
func range_multiplier(cell: Vector2i) -> float:
	# off the sockets the level is 0, which has no bonus
	return 1.0 + RULES.ELEVATION_RANGE_BONUS[elevation_at(cell)]
