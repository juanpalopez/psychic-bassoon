## One random stream per subsystem, so a change in one never shifts another.
## Never reorder or reuse a number: it would change every saved seed.
class_name Streams
extends RefCounted

const MAP := 0
const WAVES := 1
## Which route each foe takes when the map has more than one.
const ROUTES := 2
## Where the sockets go and how high they stand. Its own stream, so adding
## sockets never moves the road (the road fixtures stay valid).
const SOCKETS := 3
## Where the second road (the feeder) leaves the board and joins the main road. Its own
## stream, so adding it never moves the main road or the sockets' draws.
const SECOND_SOURCE := 4
## The valley's terrain layer: terrace heights, regions and the river (#322). Its own stream,
## drawn after the road and the sockets are placed, so it never moves either of them.
const TERRAIN := 5
## The valley plan (#381): where the six sections' strips and gates go.
const VALLEY_PLAN := 6
## The 2D valley layout (#407): the regions' borders, gates, spines and the river.
const VALLEY_LAYOUT := 7
## The fork of the layout valley's road (#481): how far apart its two lanes' bridges are. Its own
## stream, so the fork never moves the rest of the layout's draws.
const VALLEY_FORK := 8
## The first of the valley sections' streams: `VALLEY_SECTION + id * stride + attempt`, see
## `ValleyPlan.section_rng`.
const VALLEY_SECTION := 1000
## Like `VALLEY_SECTION`, for the sections of the 2D layout (`ValleyLayout.rng_for`).
const VALLEY_LAYOUT_SECTION := 2000
## Render-only scenery around the board; never affects the game.
const SCENERY := 100
