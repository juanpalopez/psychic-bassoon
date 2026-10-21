## Numbers for section D, Sunken Meadow (#385): one large open walkable meadow the road
## wanders through.
extends RefCounted

const SOCKET_LEAST := 4
const SOCKET_MOST := 5
## The meadow keeps at least this many walkable cells connected to the road's entry (the
## narrowest strip is 5 columns by 20 rows, 100 cells).
const MIN_OPEN_AREA := 85
## The middle leg of the road runs at least this many rows away from the entry and exit rows, so
## the road really wanders instead of hugging a gate row.
const WANDER_MIN_ROWS := 3
## The rows nearest the board's top and bottom edge stay clear of the middle leg.
const WANDER_EDGE_MARGIN := 1
## Roads drawn from the section's stream before the best one is kept.
const ROAD_TRIES := 8
