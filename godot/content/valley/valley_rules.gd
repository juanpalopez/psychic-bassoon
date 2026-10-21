## Numbers for the sectioned valley (#381, `docs/lessons/2026-10-20-sectioned-valley.md`): how
## the 32 by 20 board is cut into the six sections and where the road passes between them.
## Each section's own numbers live in its own file beside this one.
extends RefCounted

## The sections in road order, with the names the lore and the UI use (display names only).
const SECTION_NAMES: Array[String] = [
	"Outer March",
	"Broken Ridge",
	"Bluewater Crossing",
	"Sunken Meadow",
	"Ancient Fold",
	"Heartkeep Approach",
]
## Each section is a strip of columns across the whole board height. These widths add up to the
## board's 32 columns; the seed moves each boundary between two sections by up to
## `BOUNDARY_JITTER` columns, and no strip is ever narrower than its `MIN_WIDTHS` entry (the
## crossing keeps 6 columns: the river takes one, and each bank needs room for a 2x2 block).
const BASE_WIDTHS: Array[int] = [5, 4, 7, 6, 5, 5]
const BOUNDARY_JITTER := 1
const MIN_WIDTHS: Array[int] = [4, 4, 6, 5, 4, 4]
## The road crosses from one section to the next on a gate row, kept `GATE_MARGIN` rows in from
## the top and bottom edges (room for a socket block on both sides, and for the Heartstone),
## and two gates in a row are at most `GATE_MAX_STEP` rows apart.
const GATE_MARGIN := 3
const GATE_MAX_STEP := 6
## A section's random stream is `Streams.VALLEY_SECTION + id * SECTION_STREAM_STRIDE + attempt`,
## so a section drawn again (a new attempt) never moves another section. Fewer attempts than
## the stride, always.
const SECTION_STREAM_STRIDE := 100
const MAX_SECTION_ATTEMPTS := 20

## Socket blocks (2x2) sit at least one empty column from the right edge of their strip, so two
## blocks in neighbouring strips keep the gap `SOCKET_BLOCK_GAP` asks for.
const STRIP_RIGHT_MARGIN := 1
## A bend of the road is covered when a socket block's centre is within this many cells of it.
const BEND_COVER_REACH := 3.5
## The straight stand-in sections (before a real section replaces one) keep this many blocks.
const STUB_SOCKET_MIN := 2
const STUB_SOCKET_MAX := 4

## High-ground sockets stay scarce: at most this share (percent) of all sockets, and each has a
## low-ground socket within this many cells (centre to centre) to fall back on.
const HIGH_MAX_PERCENT := 20
const HIGH_ALTERNATIVE_REACH := 6.0
