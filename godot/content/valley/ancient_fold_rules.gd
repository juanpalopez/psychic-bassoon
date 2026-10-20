## Numbers for section E, Ancient Fold (#388): the later-wave feeder merge and the ruins.
extends RefCounted

## Socket blocks the section keeps, as (least, most).
const SOCKET_MIN := 4
const SOCKET_MAX := 5
## At least this many socket blocks have their centre within `MERGE_COVER_REACH` cells of the
## cell where the feeder joins the main road, so the merge needs coverage (owner, 2026-10-16).
const MERGE_COVER_MIN := 4
const MERGE_COVER_REACH := 8.0
## The feeder stays this many columns in from the strip's sides (the neighbours' roads are there).
const FEEDER_SIDE_MARGIN := 1
## The road winds through `LEGS_MIN` to `LEGS_MAX` extra legs on rows at least `MID_ROW_MARGIN`
## from the board's top and bottom; the section draws up to `ROAD_TRIES` roads and tries
## `FEEDERS_TRIED` feeders on each before it gives the draw up.
const LEGS_MIN := 0
const LEGS_MAX := 3
const MID_ROW_MARGIN := 3
const ROAD_TRIES := 400
const FEEDERS_TRIED := 6
## Ruins are solid 2x2 blocks of rock on a low foundation. They keep this many steps from the
## road and the feeder, and this many from the join; there are `RUIN_COUNT` of
## them at most.
const RUIN_SIZE := 2
const RUIN_COUNT := 2
const RUIN_ROAD_GAP := 2
const RUIN_JOIN_GAP := 4
const RUIN_HEIGHT := 1
