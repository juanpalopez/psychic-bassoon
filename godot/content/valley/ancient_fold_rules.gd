## Numbers for section E, Ancient Fold (#388): the later-wave feeder merge and the ruins.
extends RefCounted

## Socket blocks the section keeps, as (least, most).
const SOCKET_MIN := 4
const SOCKET_MAX := 5
## At least this many socket blocks have their centre within `MERGE_COVER_REACH` cells of the
## cell where the feeder joins the main road, so the merge needs coverage (owner, 2026-10-16).
## `FEEDER_JOIN_MAX_PERCENT` does not apply: the valley joins late, in E (decision 2026-10-20).
const NO_JOIN := Vector2i(-1, -1)
const MERGE_COVER_MIN := 4
## Wider than a tower reach: in strips of 4 or 5 columns 4.5 fails on most seeds.
const MERGE_COVER_REACH := 8.0
## The feeder stays this many columns in from the strip's sides (the neighbours' roads are there).
const FEEDER_SIDE_MARGIN := 1
## The road winds through `LEGS_MIN` to `LEGS_MAX` extra legs on rows at least `MID_ROW_MARGIN`
## from the board's top and bottom; up to `ROAD_DRAWS` roads, `FEEDERS_TRIED` feeders each.
const LEGS_MIN := 0
const LEGS_MAX := 3
const MID_ROW_MARGIN := 3
const ROAD_DRAWS := 400
const FEEDERS_TRIED := 6
## Ruins: up to `RUIN_COUNT` solid 2x2 rock blocks, this far from the roads and from the join.
const RUIN_SIZE := 2
const RUIN_COUNT := 2
const RUIN_ROAD_GAP := 2
const RUIN_JOIN_GAP := 4
const RUIN_HEIGHT := 1
