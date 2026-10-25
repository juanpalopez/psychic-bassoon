## The numbers of the off-screen arrows and the minimap.
extends RefCounted

## A foe this close to the Heartstone along its route (in cells) gets an edge arrow when it is
## off screen.
const FOE_NEAR_HEARTSTONE := 8.0
## Edge arrows for foes at once: the ones nearest the Heartstone.
const MAX_FOE_ARROWS := 3
## The arrow's size: its tip to its base, and its width, in canvas pixels.
const ARROW_LENGTH := 36.0
const ARROW_WIDTH := 28.0
const ARROW_EDGE_WIDTH := 2.0
## Pulse: the arrow's size swings by this share, this many times a second.
const PULSE_SHARE := 0.2
const PULSE_HERTZ := 1.5
## The minimap fits in this box (canvas pixels), keeping the board's shape.
const MINIMAP_MAX := Vector2(240.0, 150.0)
## Dot sizes and line width on the minimap, in canvas pixels.
const MINIMAP_FOE_DOT := 5.0
const MINIMAP_HERO_DOT := 8.0
const MINIMAP_ROAD_WIDTH := 4.0
const MINIMAP_VIEW_WIDTH := 2.0
const MINIMAP_VIEW_RADIUS := 8.0
## Seconds between two redraws of the minimap.
const MINIMAP_REFRESH := 0.1
const MINIMAP_RING_POINTS := 16
