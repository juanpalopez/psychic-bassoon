## Numbers for region 2, Bluewater Crossing, on the 2D layout (#409, epic #404): where the road
## meets the river, the hero's own bridge, and the socket blocks on the banks.
extends RefCounted

## The road runs level for this many cells on each side of the wet stretch, and its waypoints sit
## this many cells out from the river, so the approaches are straight.
const APPROACH_STRAIGHT := 2
const APPROACH_REACH := 4
## The road leaves the far bank this many cells below the exit before it reaches it (when the
## rows between allow it, with this many to spare).
const EXIT_LEAD := 3
const EXIT_LEAD_CLEAR := 2
## The hero's bridge is at least this many rows from the road's bridge, and this many rows clear
## of the region's top and bottom edges.
const HERO_BRIDGE_MIN_ROW_GAP := 4
const HERO_BRIDGE_EDGE := 1
## Cells beside the hero's bridge that stay free of socket blocks, on both banks.
const HERO_APPROACH_KEEP := 2
## The socket blocks: the fewest and the most.
const SOCKET_MIN := 4
const SOCKET_MAX := 5
## A block this close to the river (cells) is tagged as a bank socket.
const BANK_REACH := 1
## How often the blocks are drawn again when a draw misses the count or the west bank.
const PLACE_TRIES := 12
