## The diorama props' sizes in one place: the road bed and the bridges. Their colours are in the
## diorama's one palette, `TerrainPalette` (render/paper/terrain_palette.gd). Render-only
## numbers: none of them changes the game.
class_name DioramaLooks
extends RefCounted

## The road bed, in cells. A bed is `ROAD_WIDTH` wide, its edges wander by up to `ROAD_WOBBLE`
## either way (a worn edge, still inside the road cells), and it sits `BED_LIFT` above the
## terrain top, under where the foes walk (`TerrainField.ROAD_HEIGHT`), with a paper lip
## `LIP_HEIGHT` above it along each edge, so it reads as a bed sunk between its lips. The lip's
## crest is `LIP_CREST` in from the outer edge and it falls to the bed over `LIP_WIDTH`; the outer
## edge meets the ground `EDGE_LIFT` above the terrain top.
const ROAD_WIDTH := 0.9
const ROAD_WOBBLE := 0.025
## How far along the road the wobble changes its mind, in cells.
const ROAD_WOBBLE_LENGTH := 1.3
const BED_LIFT := 0.006
const LIP_HEIGHT := 0.016
const LIP_CREST := 0.03
const LIP_WIDTH := 0.09
const EDGE_LIFT := 0.002
## Drawing only: the route's polyline is rounded by this many corner-cutting passes (Chaikin),
## then thinned to points at most `ROAD_STEP` apart where it runs straight, and no further than
## `ROAD_BEND_DEGREES` off line where it bends.
const ROAD_SMOOTH_PASSES := 4
const ROAD_STEP := 0.75
const ROAD_BEND_DEGREES := 6.0
## A road carries on this many cells past the board edge it enters from, into the haze: past the
## diorama's own margin (`TerrainField.MARGIN`, the floor it carries the road on), so its end is
## never in view.
const ROAD_RUN_OUT := 36.0
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

## The bridges: a flat deck `BRIDGE_SPAN` cells long centred on the bridge cell (its ends rest on
## the banks, over the road bed's cut ends), of `PLANKS` planks `DECK_WIDTH` across (an odd count,
## so one lies over the cell's middle). Its top is where foes and guards stand on a bridge cell
## (`TerrainField.ROAD_HEIGHT` above the banks), so it does not sag. The road bed stops at the
## bridge cell's edges.
const BRIDGE_SPAN := 1.7
const PLANKS := 11
const DECK_WIDTH := 0.96
const PLANK_THICKNESS := 0.035
const PLANK_FILL := 0.82
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

## How far a plank's tone may stray from the plank colour (a share either way).
const PLANK_TONE := 0.1
