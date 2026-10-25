## The generated board: the foes' routes and the grid they sit on.
class_name GameMap
extends RefCounted

## `PLOT` cells accept a tower; `ROAD` cells carry the foes.
enum Tile { PLOT, ROAD }
## What covers a cell of the terrain layer (#322): open meadow (the road, the sockets and the
## river are always meadow), forest, rocks on the high terraces, or dirt beside the road.
enum Region { MEADOW, FOREST, ROCKS, DIRT }

const RULES := preload("res://content/map_rules.gd")
const ROAD := preload("res://content/valley/road_rules.gd")
## What `socket_anchor_at` returns for a cell that is in no socket.
const NO_SOCKET := Vector2i(-1, -1)


## Where the road crosses the river (#322): one road cell on the river, spanned by a bridge.
class Bridge:
	extends RefCounted
	## The road cell the bridge spans.
	var cell := Vector2i.ZERO
	## True when the road runs left to right across the bridge (the river flows down it).
	var horizontal: bool = true
	## The bridge's index in `path` (the main road), or -1 only when it is on the second road's
	## own cells (the feeder, before it joins the main road).
	var path_index: int = -1
	## The route whose own cells the bridge spans (0 is the main road). `path_index` counts cells
	## of that route; a bridge on a fork's branch names the branch's route (#481). A feeder
	## bridge reads 0 as well, with its `path_index` of -1.
	var route: int = 0
	## True when a section built the bridge on its branch road, the fork's second lane (#481):
	## the stitcher gives it the branch's `route`.
	var on_branch: bool = false


## Where a route leaves the main road and where it rejoins it, a fork of the road (#481). The
## branch's route is `path[0..fork_index]` + its own cells + `path[merge_index..]`.
class Fork:
	extends RefCounted
	## The branch's index in `GameMap.routes`.
	var route: int = 0
	## The index in `path` of the last cell the branch shares with the main road before it leaves.
	var fork_index: int = 0
	## The index in `path` of the first cell it shares with the main road after it rejoins.
	var merge_index: int = 0
	## How many cells the branch has of its own, between the fork and the merge.
	var branch_length: int = 0


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
## Per spawn source, the indices of the routes a foe of that source may walk; it picks one with a
## draw from the route stream when there are several (#481). Empty means one source per route:
## every board without a fork.
var sources: Array[PackedInt32Array] = []
## The forks of the main road, one per branch route (empty on every board that has none).
var forks: Array[Fork] = []
## For each route, the `RoadCurve` foes walk, or null to round its grid path's corners (the old
## boards, and any route a section gave no spline for, #404). Empty when no route has one.
var route_curves: Array = []
## How wide the road is drawn and walked, in cells: the layout valley's wide band (#430, its
## cells are `Tile.ROAD`), 0.9 on every older board. Foes still walk the centre line.
var road_width: float = ROAD.OLD_WIDTH_CELLS
## How wide a band, in cells, a tower's reach counts as the road's: a ground foe on the centre
## line is in reach up to half of it further than the reach in `TowerFire.reach_of` (option B of
## #446, the wide road's rule). Its own field, not `road_width`, which is 0.9 on every older board
## and must not move their reach. 0 (no band) on every board until the stitcher sets it.
var reach_band: float = 0.0
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
## The terrain layer (#322), one `PackedByteArray` per row: each cell's terrace, from 0 (the
## valley floor, where the road and the river run) up to `TERRAIN_LEVELS - 1`. The sockets are
## placed first and the terrain adapts to them: each socket block stands on its own elevation
## level (0 to 2), even beside the road. Every other cell within one cell of a road is at most
## `TERRAIN_ROADSIDE_MAX`, and a cell beside a block on level L (but the road and the river) is
## at least L - 1 (no higher than the bank height beside the road). On the classic boards it
## equals `elevation`.
var heights: Array[PackedByteArray] = []
## One `PackedByteArray` of `Region` values per row.
var regions: Array[PackedByteArray] = []
## The river's cells from the top edge to the bottom edge, each one step down, left or right
## from the one before (it never flows back up); empty when the map has no river. It crosses a
## road only on a bridge, head on: the two cells before and after a bridge are in line with it,
## so it steps down across a road running left to right and sideways across one running up or
## down. It keeps off the sockets, the inside cell of every road turn and the Heartstone.
var river: Array[Vector2i] = []
## The bridges where the road crosses the river, in the river's order (empty without a river,
## at least one with one).
var bridges: Array[Bridge] = []
## One `PackedByteArray` per row: 1 where a hero can stand, 0 on water, cliff and rock (#381).
## Empty on the boards before the sectioned valley, where every cell is walkable.
var walkable: Array[PackedByteArray] = []
## The cells of bridges only a hero uses (the sectioned valley's second crossing).
var hero_bridges: Array[Vector2i] = []


## How many places foes come from: the sources, or one per route when none are listed.
func source_count() -> int:
	return sources.size() if not sources.is_empty() else routes.size()


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


## How much further than its reach a tower hits a ground foe on the centre line: half the reach
## band (0.0 without one, so adding it changes no bit of a reach).
func reach_margin() -> float:
	return reach_band / 2.0


## True when the cell is on the board.
func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < rows


## True when the cell is in a socket block (any of its cells, not only the anchor).
func is_socket_cell(cell: Vector2i) -> bool:
	return socket_anchor_at(cell) != NO_SOCKET


## The terrace of a cell from the terrain layer (0 off the board, or before the layer is built).
func height_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= heights.size() or cell.x < 0 or cell.x >= heights[cell.y].size():
		return 0
	return heights[cell.y][cell.x]


## The `Region` of a cell (`MEADOW` off the board, or before the layer is built).
func region_at(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= regions.size() or cell.x < 0 or cell.x >= regions[cell.y].size():
		return Region.MEADOW
	return regions[cell.y][cell.x]


## True when a hero can stand on the cell (every cell of the board, before the sectioned valley).
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	return walkable.is_empty() or walkable[cell.y][cell.x] == 1
