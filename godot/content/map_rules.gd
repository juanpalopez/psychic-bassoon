## Board size and map-generation numbers, ported from the TypeScript content
## (`web-three-final:src/content/rules.ts`). Data only: the sim reads these, never hard-codes.
extends RefCounted

## The board the game builds, in cells: the 32 by 20 valley (owner, 2026-10-18, #320). The
## camera pans across it.
const GRID_COLS := 32
const GRID_ROWS := 20
## The ported generator's original board, which the frozen fixtures pin.
const LEGACY_COLS := 9
const LEGACY_ROWS := 13
## The board before the valley: 16 columns by 11 rows, landscape (a road crosses the long side).
## The GDD said 22 by 16, but that showed too many cells at a readable unit size (owner,
## 2026-10-14, #255). Its tests keep it pinned with the classic road shape below.
const LANDSCAPE_COLS := 16
const LANDSCAPE_ROWS := 11
## Whether the game's road grows a detour. The owner chose one road and one spawn
## (2026-10-12); the fixtures' maps all have a detour, so they ask for one.
const GAME_DETOUR := false
## Whether the game's board also grows a second road from another edge that joins the main
## road (owner, 2026-10-16). Waves use it from `SECOND_SOURCE_AFTER_WAVE` on.
const GAME_SECOND_SOURCE := true
## The second road (the feeder) is at least this many cells long before it reaches the main
## road, joins the main road at least this many cells from its start and from the Heartstone,
## and leaves the rows this close to the spawn edge and the Heartstone edge free.
const FEEDER_MIN_CELLS := 3
const FEEDER_JOIN_MARGIN := 6
const FEEDER_ROW_MARGIN := 2
## The feeder stays this far (in steps along the grid) from every main-road cell but the join.
const FEEDER_CLEARANCE := 2
## The second road joins the main road no further along than this share of its length (percent),
## so its foes still pass most of the towers instead of skipping most of the road.
const FEEDER_JOIN_MAX_PERCENT := 65

## Give up and retry when the path is shorter than rows + this many cells.
const MIN_EXTRA_CELLS := 16
const MAX_ATTEMPTS := 300
## Each straight run down the board is this many cells, plus 0..variance-1 more.
const MIN_RUN_DOWN := 2
const RUN_DOWN_VARIANCE := 2
## A sideways turn moves at least this many columns.
const MIN_TURN_COLUMNS := 3
## The path starts at least this many columns in from either edge.
const START_MARGIN := 1
## A straight run this long (cells, corners included) can grow a detour beside
## it; the two joins must be at least two cells apart.
const DETOUR_MIN_RUN := 5
## The detour runs this many cells beside the main road.
const DETOUR_OFFSET := 2

## The valley shape: a board at least `VALLEY_MIN_COLS` wide (the 32 by 20 game board) draws a
## road with longer straight runs and shorter sideways turns than the classic shape above, so
## it winds through the valley instead of sweeping from edge to edge on every turn, and it gets
## more sockets. Smaller boards (the 16 by 11, the fixtures' 9 by 13) keep the classic numbers.
const VALLEY_MIN_COLS := 24
const VALLEY_MIN_RUN_DOWN := 3
const VALLEY_RUN_DOWN_VARIANCE := 3
const VALLEY_MIN_TURN_COLUMNS := 3
const VALLEY_MAX_TURN_COLUMNS := 8
const VALLEY_MIN_EXTRA_CELLS := 24
const VALLEY_SOCKET_MIN := 24
const VALLEY_SOCKET_MAX := 30

## Spawn point sits this far above the top row, in cells.
const SPAWN_OFFSET := 0.45
## A cell's centre is at col + this.
const CELL_CENTRE := 0.5

## Curved routes (#321): on the valley board the line foes walk rounds each corner of the grid
## path with a quadratic Bezier whose control point is the corner cell's centre. Its legs run
## `CURVE_LEG` cells back along the road and on along it (to the centres of the cells either
## side), or `CURVE_LEG_TIGHT` (to the corner cell's edges) when a neighbouring cell is a corner
## too, so the curves of an S-bend or a U-turn meet instead of overlapping. Legs above 1 would
## leave the road's cells. A curve gets one point per `CURVE_POINT_SPACING` cells of its legs.
const CURVE_LEG := 1.0
const CURVE_LEG_TIGHT := 0.5
const CURVE_POINT_SPACING := 0.125

## Sockets: the pre-etched circular sites where towers can be built (the GDD
## replaces free building). A map gets this many, chosen among the cells that
## are not road but lie within `SOCKET_REACH` cells of it (Chebyshev distance),
## and no two sockets are closer than `SOCKET_SPACING` (Manhattan distance).
const SOCKET_MIN := 12
const SOCKET_MAX := 15
## Single-cell sockets (the 9 by 13 board of the frozen sockets golden) keep the old upper bound.
const SOCKET_MAX_SINGLE_CELL := 22
const SOCKET_REACH := 2
const SOCKET_SPACING := 2
## A socket is a square block of this many cells on a side: the GDD says 2
## (`GAME_SOCKET_FOOTPRINT`); the frozen sockets golden is the old single cell.
const SOCKET_FOOTPRINT_LEGACY := 1
const SOCKET_FOOTPRINT := 2
const GAME_SOCKET_FOOTPRINT := 2
## Blocks of 2 or more cells leave this many empty cells between each other.
const SOCKET_BLOCK_GAP := 1
## A 2x2 block must have at least this many road cells within
## `SOCKET_COVERAGE_REACH` cells of its centre (a level 1 Spool Guard's reach, the
## shortest of the towers), so a tower there has a stretch of road to shoot at, not
## a corner, and its centre must be within `SOCKET_BLOCK_TOUCH_DISTANCE` of a road
## cell's centre. A block's centre sits on a cell corner, so the nearest a road
## cell can be is 1.58 cells (the block touches the road along an edge) and the
## next is 2.12 (a diagonal corner only): 1.6 keeps the first and rejects the
## second, which a road with a detour can otherwise satisfy through three corners.
## Single-cell sockets keep the looser `SOCKET_REACH` rule.
const SOCKET_MIN_ROAD_COVERAGE := 3
const SOCKET_COVERAGE_REACH := 2.3
const SOCKET_BLOCK_TOUCH_DISTANCE := 1.6

## Elevation levels: 0 the cutting mat, 1 a glued cardboard rise, 2 tiered
## cliffs. Roads and plain ground are level 0; a socket gets a level by weight.
const ELEVATION_LEVELS := 3
const ELEVATION_WEIGHTS: Array[int] = [6, 3, 1]
## Range multiplier bonus by level: a tower on level 2 reaches 15% further.
const ELEVATION_RANGE_BONUS: Array[float] = [0.0, 0.0, 0.15]

## The terrain layer of the valley (#322), drawn from its own stream after the road and the
## sockets. Terraces 0 (the valley floor, where the road runs) to `TERRAIN_LEVELS - 1`; the
## cells beside a road stay at most `TERRAIN_ROADSIDE_MAX`, and each socket block stands on its
## own elevation level. The heights come from a smooth field with a random value every
## `TERRAIN_NOISE_CELL` cells, mixed with a rise away from the road that reaches its top
## `TERRAIN_VALLEY_REACH` cells out and makes up `TERRAIN_VALLEY_WEIGHT` of the height (the
## valley); lone pits and spikes are smoothed over at most `TERRAIN_SMOOTH_PASSES` times.
const TERRAIN_LEVELS := 5
const TERRAIN_ROADSIDE_MAX := 1
const TERRAIN_NOISE_CELL := 5
const TERRAIN_VALLEY_REACH := 6
const TERRAIN_VALLEY_WEIGHT := 0.5
const TERRAIN_SMOOTH_PASSES := 8
## Regions, from a second smooth field `n` in [0, 1): rocks on terraces of `ROCKS_MIN_LEVEL`
## or higher where `n < ROCKS_BELOW`; forest at least `FOREST_ROAD_GAP` cells from the road
## where `n > FOREST_ABOVE`; dirt within `DIRT_ROAD_GAP` cells of the road where `n < DIRT_BELOW`;
## meadow elsewhere (and always on the road, the sockets and the river).
const ROCKS_MIN_LEVEL := 3
const ROCKS_BELOW := 0.35
const FOREST_ROAD_GAP := 2
const FOREST_ABOVE := 0.55
const DIRT_ROAD_GAP := 1
const DIRT_BELOW := 0.4
## The river flows from the top edge to the bottom edge and crosses the road only on bridges,
## each straight across a straight stretch of road one cell wide, meeting it head on. It keeps
## at least `RIVER_EDGE_MARGIN` columns in from the left and right edges, `RIVER_SPAWN_GAP`
## cells (Manhattan) from every spawn, and off the sockets, the inside cells of the road's turns
## and the Heartstone. Its course is the cheapest one: each cell costs `RIVER_STEP_COST`, plus
## `RIVER_HIGH_GROUND_COST` times the height field (it seeks low ground), plus
## `RIVER_ROADSIDE_COST` beside the road (it keeps away from the road), and each bridge costs
## `RIVER_BRIDGE_COST` more (it crosses as few times as it can). A course that crowds one of
## its bridges, or walls in a raised socket block, is searched again without that bridge or
## those cells, at most `RIVER_SEARCH_PASSES` times.
const RIVER_EDGE_MARGIN := 1
const RIVER_SPAWN_GAP := 3
const RIVER_STEP_COST := 1.0
const RIVER_HIGH_GROUND_COST := 3.0
const RIVER_ROADSIDE_COST := 4.0
const RIVER_BRIDGE_COST := 20.0
const RIVER_SEARCH_PASSES := 6
