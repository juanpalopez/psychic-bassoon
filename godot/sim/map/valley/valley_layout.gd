## The valley laid out as six 2D regions and a winding river (#407, epic #404,
## `docs/lessons/2026-10-21-spline-valley.md`). The regions are rectangles that tile the board:
## the Outer March top left, the Sunken Meadow under it, the Bluewater Crossing in the middle
## under the Broken Ridge, the Ancient Fold top right and the Heartkeep Approach under it. The
## road visits them in that order (their ids), crossing from one to the next at a gate, and a
## river runs from the top edge to the bottom edge; only the Crossing's road may touch it.
## It is a `ValleyPlan`, so the stitcher and the checks take it as they take the strips.
class_name ValleyLayout
extends ValleyPlan

## The regions in road order (the same as the slot ids).
enum Region {
	OUTER_MARCH,
	SUNKEN_MEADOW,
	BLUEWATER_CROSSING,
	BROKEN_RIDGE,
	ANCIENT_FOLD,
	HEARTKEEP_APPROACH,
}

const LAYOUT := preload("res://content/valley/layout_rules.gd")
const VALLEY := preload("res://content/valley/valley_rules.gd")
const HALF := 0.5

## The river's centre line (a spline from the top edge to the bottom edge).
var river: RoadCurve = null
## Every cell of the river: the centre line and the cells beside it that make it wide.
var river_cells: Array[Vector2i] = []


## The layout for a seed, or null (with an error) when no draw passes `problems` and stitches with
## the stand-in sections (each retry draws the next layout from the same stream).
static func generate(seed: int, cols: int, rows: int) -> ValleyLayout:
	assert(cols == LAYOUT.COLS and rows == LAYOUT.ROWS, "the layout is made for 32 by 20")
	var rng := Rng.derive(seed, Streams.VALLEY_LAYOUT)
	for attempt in LAYOUT.MAX_ATTEMPTS:
		var layout := _draw(seed, rng)
		if layout.problems().is_empty() and _stitches(layout):
			return layout
	push_error("valley layout seed %d: no draw passes its checks" % seed)
	return null


static func _stitches(layout: ValleyLayout) -> bool:
	var map := ValleyStitcher.build(
		layout.seed, layout.cols, layout.rows, sections(), layout, true
	)
	return map != null


## The six stand-in sections, in road order.
static func sections() -> Array[ValleySection]:
	var out: Array[ValleySection] = []
	for index in Region.size():
		out.append(RegionStraightSection.new())
	return out


func rng_for(id: int, attempt: int) -> Rng:
	var stream := Streams.VALLEY_LAYOUT_SECTION + id * VALLEY.SECTION_STREAM_STRIDE + attempt
	assert(attempt < VALLEY.SECTION_STREAM_STRIDE, "too many attempts")
	return Rng.derive(seed, stream)


## What is wrong with this layout, or nothing: every spine inside its region, no gate or road
## cell on the river except the Crossing's road, which must cross it.
func problems() -> Array[String]:
	var found: Array[String] = []
	var wet := {}
	for cell in river_cells:
		wet[cell] = true
	for slot in slots:
		var cells := RoadSpline.build(slot.spine).cells
		for cell in cells:
			if not slot.rect.has_point(cell):
				found.append("region %d: the spine leaves it at %s" % [slot.id, cell])
				break
		var dry := slot.id != Region.BLUEWATER_CROSSING
		var wades := cells.any(func(cell: Vector2i) -> bool: return wet.has(cell))
		if dry and (wades or wet.has(slot.entry) or wet.has(slot.exit)):
			found.append("region %d: the road touches the river" % slot.id)
		elif not dry and _wet_runs(cells, wet) != 1:
			found.append("region %d: the road must wade the river in exactly one stretch" % slot.id)
		if not dry and (wet.has(slot.entry) or wet.has(slot.exit)):
			found.append("region %d: the gates must be on dry banks" % slot.id)
		found.append_array(_uncoverable(slot, cells))
	return found


## The bends of a region's road that no socket block site is near enough to cover.
static func _uncoverable(slot: Slot, cells: Array[Vector2i]) -> Array[String]:
	var probe := SectionResult.create(slot)
	probe.road = cells
	var blocked: Array[Rect2i] = []
	for cell in slot.river:
		blocked.append(Rect2i(cell, Vector2i.ONE))
	var sites := SectionSockets.candidates(probe, blocked)
	var found: Array[String] = []
	for bend in SectionSockets.bends(cells, slot.bend_run):
		var near := sites.any(
			func(site: Vector2i) -> bool:
				return SectionSockets.centre_gap(site, bend) <= VALLEY.BEND_COVER_REACH
		)
		if not near:
			found.append(
				"region %d: no room for a socket block by the bend at %s" % [slot.id, bend]
			)
	return found


## How many separate stretches of the road are on the river.
static func _wet_runs(cells: Array[Vector2i], wet: Dictionary) -> int:
	var runs := 0
	var inside := false
	for cell in cells:
		if wet.has(cell) and not inside:
			runs += 1
		inside = wet.has(cell)
	return runs


static func _draw(seed: int, rng: Rng) -> ValleyLayout:
	var layout := ValleyLayout.new()
	layout.seed = seed
	layout.cols = LAYOUT.COLS
	layout.rows = LAYOUT.ROWS
	layout.hero_caps = LAYOUT.HERO_CAPS
	layout.bend_run = LAYOUT.BEND_RUN
	var left := _jitter(rng, LAYOUT.LEFT_X)
	var right := _jitter(rng, LAYOUT.RIGHT_X)
	var ys := [
		_jitter(rng, LAYOUT.LEFT_Y), _jitter(rng, LAYOUT.MIDDLE_Y), _jitter(rng, LAYOUT.RIGHT_Y)
	]
	var rects: Array[Rect2i] = [
		Rect2i(0, 0, left, ys[0]),
		Rect2i(0, ys[0], left, LAYOUT.ROWS - ys[0]),
		Rect2i(left, ys[1], right - left, LAYOUT.ROWS - ys[1]),
		Rect2i(left, 0, right - left, ys[1]),
		Rect2i(right, 0, LAYOUT.COLS - right, ys[2]),
		Rect2i(right, ys[2], LAYOUT.COLS - right, LAYOUT.ROWS - ys[2]),
	]
	var inset: int = LAYOUT.GATE_INSET
	var reach: Vector2i = LAYOUT.RIDGE_GATE_REACH
	var spawn: Vector2i = LAYOUT.SPAWN_ROWS
	var end: Vector2i = LAYOUT.END_ROWS
	var entries: Array[Vector2i] = [Vector2i(0, _between(rng, spawn.x, spawn.y))]
	var exits: Array[Vector2i] = []
	# Meadow: under the March, a gate column on their shared border.
	var x := _between(rng, inset, left - 1 - inset)
	exits.append(Vector2i(x, ys[0] - 1))
	entries.append(Vector2i(x, ys[0]))
	# Crossing: right of the Meadow, on a row of the Meadow's lower part.
	var y := _between(rng, ys[0] + inset, LAYOUT.ROWS - 1 - inset)
	exits.append(Vector2i(left - 1, y))
	entries.append(Vector2i(left, y))
	# Ridge: above the Crossing, on the far bank of the river.
	x = _between(rng, right - reach.y, right - reach.x)
	exits.append(Vector2i(x, ys[1]))
	entries.append(Vector2i(x, ys[1] - 1))
	# Fold: right of the Ridge.
	y = _between(rng, inset, mini(ys[1], ys[2]) - 1 - inset)
	exits.append(Vector2i(right - 1, y))
	entries.append(Vector2i(right, y))
	# Heartkeep: under the Fold, then on to the Heartstone at the east edge.
	x = _between(rng, right + inset, LAYOUT.COLS - 1 - inset)
	exits.append(Vector2i(x, ys[2] - 1))
	entries.append(Vector2i(x, ys[2]))
	exits.append(Vector2i(LAYOUT.COLS - 1, _between(rng, end.x, end.y)))
	layout._draw_river(rng)
	for index in rects.size():
		var slot := Slot.new()
		slot.id = index
		slot.role = LAYOUT.ROLES[index]
		slot.rect = rects[index]
		slot.entry = entries[index]
		slot.exit = exits[index]
		slot.margin = LAYOUT.BLOCK_MARGIN
		slot.bend_run = layout.bend_run
		slot.spine = _spine(rng, slot)
		for cell in layout.river_cells:
			if slot.rect.has_point(cell):
				slot.river.append(cell)
		layout.slots.append(slot)
	return layout


## Source and mouth, with a wobble in between, as a spline; the cells beside the centre line
## make it wide.
func _draw_river(rng: Rng) -> void:
	var top := LAYOUT.TOP_X
	var bottom := LAYOUT.BOTTOM_X
	var wobble: int = LAYOUT.RIVER_WOBBLE
	var from := float(top.x + rng.next_int(top.y)) + HALF
	var to := float(bottom.x + rng.next_int(bottom.y)) + HALF
	var points: Array[Vector2] = [Vector2(from, HALF)]
	var mids: int = LAYOUT.RIVER_MIDS
	for step in range(1, mids + 1):
		var t := float(step) / float(mids + 1)
		var x := from + (to - from) * t + float(rng.next_int(2 * wobble + 1) - wobble)
		points.append(Vector2(x, float(LAYOUT.ROWS) * t))
	points.append(Vector2(to, float(LAYOUT.ROWS) - HALF))
	river = RoadSpline.build(points)
	var seen := {}
	for cell in river.cells:
		for dx in LAYOUT.RIVER_WIDTH:
			var wet := cell + Vector2i(dx, 0)
			if not seen.has(wet) and wet.x < LAYOUT.COLS:
				seen[wet] = true
				river_cells.append(wet)


## The road's waypoints through a region: the entry, a point LEAD cells inside (so the road leaves
## the border square on), a few points that sway to alternate sides of the straight line, the
## same near the exit, and the exit.
static func _spine(rng: Rng, slot: Slot) -> Array[Vector2]:
	var start := Vector2(slot.entry) + Vector2(HALF, HALF)
	var finish := Vector2(slot.exit) + Vector2(HALF, HALF)
	var lead_in := start + Vector2(_inward(slot.rect, slot.entry)) * float(LAYOUT.LEAD)
	var lead_out := finish + Vector2(_inward(slot.rect, slot.exit)) * float(LAYOUT.LEAD)
	var along := lead_out - lead_in
	var length := sqrt(along.x * along.x + along.y * along.y)
	var normal := Vector2(-along.y, along.x) / maxf(length, 1.0)
	var margin: int = LAYOUT.SPINE_MARGIN
	var low := Vector2(slot.rect.position + Vector2i(margin, margin)) + Vector2(HALF, HALF)
	var high := Vector2(slot.rect.end - Vector2i(margin, margin)) - Vector2(HALF, HALF)
	var side := 1.0 - 2.0 * float(rng.next_int(2))
	var spine: Array[Vector2] = [start, lead_in]
	for step in range(1, LAYOUT.SPINE_MIDS + 1):
		var t := float(step) / float(LAYOUT.SPINE_MIDS + 1)
		var sway := float(LAYOUT.SWAY_MIN + rng.next_int(LAYOUT.SWAY_SPAN + 1))
		var point := lead_in + along * t + normal * (sway * side)
		spine.append(
			Vector2(maxf(low.x, minf(point.x, high.x)), maxf(low.y, minf(point.y, high.y)))
		)
		side = -side
	spine.append(lead_out)
	spine.append(finish)
	return spine


## The direction into the region from the border edge a gate cell is on.
static func _inward(rect: Rect2i, cell: Vector2i) -> Vector2i:
	if cell.x == rect.position.x:
		return Vector2i.RIGHT
	if cell.x == rect.end.x - 1:
		return Vector2i.LEFT
	if cell.y == rect.position.y:
		return Vector2i.DOWN
	return Vector2i.UP


static func _jitter(rng: Rng, base: int) -> int:
	return base + rng.next_int(2 * LAYOUT.JITTER + 1) - LAYOUT.JITTER


## A whole number from `low` to `high`, both included.
static func _between(rng: Rng, low: int, high: int) -> int:
	return low + rng.next_int(high - low + 1)
