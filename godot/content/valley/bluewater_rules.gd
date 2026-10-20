## Numbers for section C, Bluewater Crossing (#386): where the river runs, how the road meets it
## and where the hero's bridge goes. Shared valley numbers stay in `valley_rules.gd`.
extends RefCounted

## The river keeps this many columns in from the strip's left edge (room for the road and a
## bank) and this many from its right edge (the road's exit column).
const RIVER_LEFT_OFFSET := 2
const RIVER_RIGHT_OFFSET := 1
## In a strip this narrow (or narrower) the river keeps one more column from the left edge, so
## the near bank holds a road run and a two-column socket block beside it.
const NARROW_STRIP := 5
const NARROW_LEFT_EXTRA := 1
## Chance (percent) that the river steps one column sideways once, and how many rows it keeps
## clear of the bridges and of the top and bottom edges when it does.
const RIVER_JOG_PERCENT := 60
const RIVER_JOG_CLEARANCE := 2
## The road's bridge row is one of the rows within this many of the best score (the sum of its
## distances from the entry row and the exit row), so both banks keep long runs of road for sockets.
const BRIDGE_ROW_SLACK := 2
## The hero's bridge is at least this many rows from the road's bridge, and the cells that lead
## onto it stay free of socket blocks for this many cells on both banks.
const HERO_BRIDGE_MIN_ROW_GAP := 5
const HERO_APPROACH_KEEP := 2
## The socket blocks: the fewest and the most.
const SOCKET_MIN := 4
const SOCKET_MAX := 5
## A block this close to the river (cells) is tagged as a bank socket.
const BANK_REACH := 1
## Ground this far from the road (Chebyshev) and from the river rises one terrace, off the
## sockets, so the banks read as the valley floor and the sides as a slope.
const SLOPE_ROAD_GAP := 3
const SLOPE_RIVER_GAP := 2
