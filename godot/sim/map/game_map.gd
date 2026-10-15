## The generated board: the foes' routes and the grid they sit on.
class_name GameMap
extends RefCounted

## `PLOT` cells accept a tower; `ROAD` cells carry the foes.
enum Tile { PLOT, ROAD }

const RULES := preload("res://content/map_rules.gd")
## What `socket_anchor_at` returns for a cell that is in no socket.
const NO_SOCKET := Vector2i(-1, -1)

var seed: int = 0
## Board size in cells.
var cols: int = 0
var rows: int = 0
## Cells on a side of a socket's block (1 is a single cell).
var footprint: int = 1
## The Heartstone's footprint: a block of `footprint` cells that holds the last
## cell of the road (just that cell when the footprint is 1). No socket overlaps it.
var heartstone := Rect2i()
## The main road in walking order, from the spawn row to the Heartstone.
var path: Array[Vector2i] = []
## Every route from the spawn to the Heartstone. `routes[0]` equals `path`;
## a second one leaves the main road, runs beside it and rejoins it. Each item
## is an `Array[Vector2i]`.
var routes: Array = []
## With a second spawn source: how many cells of `routes[1]` come before the main road (the
## feeder), and the index in `path` of the cell where it joins. Both are 0 without one.
var feeder_length: int = 0
var join_index: int = 0
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


## The anchor (top-left cell) of the socket block that holds `cell`, or
## `NO_SOCKET` when the cell is in none.
func socket_anchor_at(cell: Vector2i) -> Vector2i:
	for anchor in sockets:
		if (
			cell.x >= anchor.x
			and cell.x < anchor.x + footprint
			and cell.y >= anchor.y
			and cell.y < anchor.y + footprint
		):
			return anchor
	return NO_SOCKET


## The middle of the socket block anchored at `anchor`, in cell units: half a
## cell in for a single cell, a whole cell in for a 2x2 block.
func socket_centre(anchor: Vector2i) -> Vector2:
	var half := float(footprint) / 2.0
	return Vector2(float(anchor.x) + half, float(anchor.y) + half)


## The elevation level of a cell (0 off the board).
func elevation_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= elevation.size() or cell.x < 0 or cell.x >= elevation[cell.y].size():
		return 0
	return elevation[cell.y][cell.x]


## How much further a tower on this cell reaches: 1.0, or 1.15 on level 2.
func range_multiplier(cell: Vector2i) -> float:
	# off the sockets the level is 0, which has no bonus
	return 1.0 + RULES.ELEVATION_RANGE_BONUS[elevation_at(cell)]
