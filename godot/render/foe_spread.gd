## A small fixed offset per foe so a crowd on the road centre line reads as separate
## foes. Render only: the sim's positions stay the truth for range, hits and picking.
##
## The offset depends only on the foe's id and its heading (an integer hash, no random
## stream), so it never jitters and blends with the walk interpolation. Walkers spread
## across the road within `LANE` and a little along it; flyers spread wider and also
## vary in height.
class_name FoeSpread
extends RefCounted

## Most a walker is moved across the road, in cells (the tape is 0.84 wide).
const LANE := 0.23
## Extra sideways jitter inside a lane, so lanes are not a visible grid.
const JITTER := 0.01
## Most a foe is moved along its heading, in cells.
const STAGGER := 0.15
## A flyer spreads wider across and varies in height (cells).
const AIR_LANE := 0.35
const AIR_HEIGHT := 0.4
## Lanes ids cycle through; the stride keeps consecutive ids several lanes apart.
const LANES := 7
const LANE_STRIDE := 3
const SALT_JITTER := 11
const SALT_ALONG := 12
const SALT_HEIGHT := 13


## The world offset (x, height, z) of foe `id` walking along `heading` (a vector in
## world x/z; zero length falls back to +x, along the road).
static func offset(id: int, heading: Vector2, flying: bool = false) -> Vector3:
	var along_dir := heading.normalized() if heading.length_squared() > 1e-9 else Vector2.RIGHT
	var across_dir := Vector2(-along_dir.y, along_dir.x)
	var lane := float(posmod(id * LANE_STRIDE, LANES)) / float(LANES - 1) * 2.0 - 1.0
	var jitter := (CellHash.of(id, 0, 0, SALT_JITTER) - 0.5) * 2.0 * JITTER
	var along := (CellHash.of(id, 0, 0, SALT_ALONG) - 0.5) * 2.0 * STAGGER
	var width := AIR_LANE if flying else LANE
	var sideways := lane * width + jitter
	var planar := across_dir * sideways + along_dir * along
	var height := CellHash.of(id, 0, 0, SALT_HEIGHT) * AIR_HEIGHT if flying else 0.0
	return Vector3(planar.x, height, planar.y)
