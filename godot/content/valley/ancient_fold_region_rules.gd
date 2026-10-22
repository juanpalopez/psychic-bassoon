## Numbers for the Ancient Fold region (#411, epic #404): the later-wave feeder that enters at
## the board's top right corner and runs diagonally to the main road, and the ruins around it.
extends RefCounted

## Socket blocks the region keeps, as (least, most).
const SOCKET_MIN := 3
const SOCKET_MAX := 5
## At least this many socket blocks have their centre within `MERGE_COVER_REACH` cells of the
## road cell where the feeder joins (tight: 4.5 centre to centre), so the merge has coverage.
## Three, not four: four tight blocks (a gap of one cell between them) do not fit beside a road.
## `FEEDER_JOIN_MAX_PERCENT` does not apply: the valley joins late, in this region.
const MERGE_COVER_MIN := 3
const MERGE_COVER_REACH := 4.5
## The feeder starts within this many steps of the board's top right corner cell.
const START_REACH := 3
## The feeder spans at least this many cells across and down, so it is a diagonal.
const FEEDER_MIN_SPAN := 3
## Its middle waypoint bows off the straight line by this many half cells (min, span).
const BOW_MIN := 1
const BOW_SPAN := 3
## The road's waypoints between the entry and the exit, as tenths of the way across (x) and down
## (y): the first one (min, span) and the second one (min, span). Few and wide, no lanes.
const BEND_X := Vector2i(4, 5)
const BEND_Y := Vector2i(1, 4)
const LOW_Y := Vector2i(5, 4)
## The first waypoint lifts off the entry row by up to `LIFT_MAX` cells and the second sits up to
## `INSET_MAX` cells west of the exit column, so the road bows and has room for blocks.
const LIFT_MAX := 3
const INSET_MAX := 3
## The join lies in the first part of the road (percent of its length), where the feeder comes
## from the north east without crossing the road.
const JOIN_SHARE := 70
## Tries: roads drawn, and joins tried on each.
const ROAD_DRAWS := 10
const FEEDERS_TRIED := 20
## The join is no nearer than this many cells to either end of the road.
const JOIN_ENDS := 3
## Ruins: up to `RUIN_COUNT` solid 2x2 rock blocks, this far from the roads and from the join.
const RUIN_SIZE := 2
const RUIN_COUNT := 2
const RUIN_ROAD_GAP := 2
const RUIN_JOIN_GAP := 4
const RUIN_HEIGHT := 1
