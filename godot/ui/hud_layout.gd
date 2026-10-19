## The HUD's grid, in canvas pixels (1280x720, widened on wide phones): every control sits in a
## corner row that is `ROW` tall, `EDGE` from the screen's edges, `GAP` from its neighbours.
## Anything that floats over the world (the build menu, cards) keeps clear of the rows.
class_name HudLayout
extends RefCounted

## Distance from a row to the screen edge (all four sides).
const EDGE := 14.0
## Height of a HUD row and of every control in it: 48 pt on an 844x390 phone.
const ROW := 88.0
## Space between two controls in a row, and between a row and what floats beside it.
const GAP := 12.0
## The top row and the gap under it: where floating pieces may start.
const TOP_CLEAR := EDGE + ROW + GAP
## The bottom row and the gap above it: where floating pieces must stop.
const BOTTOM_CLEAR := EDGE + ROW + GAP
