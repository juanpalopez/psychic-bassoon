## The diorama props' look in one place: the sizes of the road bed and the bridges, and the
## colours baked into the vertex colours of the generated props (docs/art/STYLE.md, the starting
## palette). The road bed's own colours are `source_color` uniforms in
## `render/paper/road_bed.gdshader`, since that shader paints it. Render-only numbers: none of
## them changes the game.
class_name DioramaLooks
extends RefCounted

## The road bed, in cells. A bed is `ROAD_WIDTH` wide, its edges wander by up to `ROAD_WOBBLE`
## either way (a worn edge, still inside the road cells), and it sits `ROAD_LIFT` above the
## terrain top with a paper lip `LIP_HEIGHT` above it along each edge, so it reads as a bed sunk
## between its lips. The lip's crest is `LIP_CREST` in from the outer edge and it falls to the
## bed over `LIP_WIDTH`; the outer edge meets the ground `EDGE_LIFT` above the terrain top.
const ROAD_WIDTH := 0.9
const ROAD_WOBBLE := 0.025
## How far along the road the wobble changes its mind, in cells.
const ROAD_WOBBLE_LENGTH := 1.3
const ROAD_LIFT := 0.012
const LIP_HEIGHT := 0.018
const LIP_CREST := 0.03
const LIP_WIDTH := 0.09
const EDGE_LIFT := 0.002
## Drawing only: the route's polyline is rounded by this many corner-cutting passes (Chaikin),
## then thinned to points at most `ROAD_STEP` apart where it runs straight, and no further than
## `ROAD_BEND_DEGREES` off line where it bends.
const ROAD_SMOOTH_PASSES := 4
const ROAD_STEP := 0.75
const ROAD_BEND_DEGREES := 6.0
## A road carries on this many cells past the board edge it enters from, into the haze.
const ROAD_RUN_OUT := 14.0
## A point of a later route this close to an earlier route's line is on that road already (the
## second route runs on the main road after the join).
const JOIN_EPSILON := 0.02
## A later route's bed lies this much lower than the main road's, so the two never z-fight
## where they meet.
const JOIN_DROP := 0.003
## The round flagstone yard under the Heartstone: its radius in cells (inside the 2x2 block), or,
## when part of the block stands on a higher terrace, the round end of the road in its last cell.
const HEART_YARD_RADIUS := 0.92
const HEART_CAP_RADIUS := 0.47
const HEART_YARD_SEGMENTS := 20

## The bridges: a deck `BRIDGE_SPAN` cells long centred on the bridge cell (its ends rest on the
## banks), of `PLANKS` planks `DECK_WIDTH` across, `DECK_LIFT` above the road bed and sagging by
## `DECK_SAG` in the middle. The road bed stops `BRIDGE_BED_GAP` short of the deck's ends.
const BRIDGE_SPAN := 1.7
const BRIDGE_BED_GAP := 0.2
const PLANKS := 10
const DECK_WIDTH := 0.96
const PLANK_THICKNESS := 0.035
const PLANK_FILL := 0.82
const DECK_LIFT := 0.035
const DECK_SAG := 0.03
## Posts at the four corners, standing `POST_HEIGHT` above the deck, `POST_OUT` across from the
## middle; a hand rope runs between each side's posts, sagging `ROPE_SAG`, with `HANGERS` thin
## ropes down to the deck's edge.
const POST_SIZE := 0.075
const POST_HEIGHT := 0.46
const POST_OUT := 0.53
const ROPE_THICKNESS := 0.026
const ROPE_SAG := 0.1
const ROPE_SEGMENTS := 6
const HANGERS := 4
const HANGER_THICKNESS := 0.014
## Under a deck more than `TRESTLE_MIN_DROP` above the ground at the bridge cell (a gorge), two
## trestle bents stand at these shares of the span, with legs `TRESTLE_OUT` across from the middle.
const TRESTLE_MIN_DROP := 0.3
const TRESTLE_AT: Array[float] = [0.32, 0.68]
const TRESTLE_OUT := 0.36
const TRESTLE_SIZE := 0.07

## Planks, posts and rope (STYLE.md: planks #b88a55, rope #8a6a45).
const PLANK_COLOUR := Color("b88a55")
const POST_COLOUR := Color("8f6a40")
const ROPE_COLOUR := Color("8a6a45")
const TRESTLE_COLOUR := Color("9c7647")
## How far a plank's tone may stray from the plank colour (a share either way).
const PLANK_TONE := 0.1
