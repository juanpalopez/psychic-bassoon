## Board size and map-generation numbers, ported from the TypeScript content
## (`src/content/rules.ts`). Data only: the sim reads these, never hard-codes.
extends RefCounted

## Board size in cells.
const GRID_COLS := 9
const GRID_ROWS := 13

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

## Spawn point sits this far above the top row, in cells.
const SPAWN_OFFSET := 0.45
## A cell's centre is at col + this.
const CELL_CENTRE := 0.5

## Sockets: the pre-etched circular sites where towers can be built (the GDD
## replaces free building). A map gets this many, chosen among the cells that
## are not road but lie within `SOCKET_REACH` cells of it (Chebyshev distance),
## and no two sockets are closer than `SOCKET_SPACING` (Manhattan distance).
const SOCKET_MIN := 12
const SOCKET_MAX := 22
const SOCKET_REACH := 2
const SOCKET_SPACING := 2

## Elevation levels: 0 the cutting mat, 1 a glued cardboard rise, 2 tiered
## cliffs. Roads and plain ground are level 0; a socket gets a level by weight.
const ELEVATION_LEVELS := 3
const ELEVATION_WEIGHTS: Array[int] = [6, 3, 1]
## Range multiplier bonus by level: a tower on level 2 reaches 15% further.
const ELEVATION_RANGE_BONUS: Array[float] = [0.0, 0.0, 0.15]
