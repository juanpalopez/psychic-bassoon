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
## Render-only scenery around the board; never affects the game.
const SCENERY := 100
