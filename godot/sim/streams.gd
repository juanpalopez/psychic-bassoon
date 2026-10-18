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
## Render-only scenery around the board; never affects the game.
const SCENERY := 100
