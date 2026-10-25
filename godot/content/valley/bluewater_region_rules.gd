## Numbers for region 2, Bluewater Crossing, on the 2D layout (#409, epic #404): where the road
## meets the river, the hero's own bridge, and the socket blocks on the banks.
extends RefCounted

## The road runs level for this many cells on each side of the wet stretch, so the approaches are
## straight (the bridge template and its reach past the river: `layout_rules.gd`).
const APPROACH_STRAIGHT := 2
## The forked crossing's two bridges are at least this many rows apart (the layout's
## `FORK_ROW_GAP`). Without the fork the hero's bridge is this many rows from the road's bridge,
## and this many rows clear of the region's top and bottom edges.
const HERO_BRIDGE_MIN_ROW_GAP := 4
const HERO_BRIDGE_EDGE := 1
## Cells beside the hero's bridge that stay free of socket blocks, on both banks.
const HERO_APPROACH_KEEP := 2
## The socket blocks: the fewest and the most. With the fork (#516) one more of each than the one
## road had (4 to 5): the lower lane and its bridge need blocks of their own.
const SOCKET_MIN := 5
const SOCKET_MAX := 6
## A block this close to the river (cells) is tagged as a bank socket.
const BANK_REACH := 1
## How often the blocks are drawn again when a draw misses the count or the west bank.
const PLACE_TRIES := 12
