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
	var map := ValleyStitcher.build(layout.seed, layout.cols, layout.rows, sections(), layout, true)
	return map != null


## The six sections, in road order (stand-ins until each ticket replaces its class).
static func sections() -> Array[ValleySection]:
	return [
		OuterMarchRegion.new(),
		SunkenMeadowRegion.new(),
		BluewaterCrossingRegion.new(),
		BrokenRidgeRegion.new(),
		AncientFoldRegion.new(),
		HeartkeepApproachRegion.new(),
	]


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
	var all_cells: Array[Vector2i] = []
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
		all_cells.append_array(cells)
		if not dry:
			found.append_array(_crossing_problems(slot, cells))
	found.append_array(_lane_problems(all_cells))
	return found


## The rows from `first` down where the Crossing can enter: both gate cells dry, the river at
## least `APPROACH_STRAIGHT` cells in from the entry and its far side `APPROACH_REACH` cells short
## of the Ridge's gate column.
func _crossing_rows(left: int, ridge_x: int, first: int) -> Array[int]:
	var reach: int = BluewaterCrossingRegion.BLUEWATER.APPROACH_REACH
	var straight: int = BluewaterCrossingRegion.BLUEWATER.APPROACH_STRAIGHT
	var wet := {}
	var span := {}
	for cell in river_cells:
		wet[cell] = true
		var old: Vector2i = span.get(cell.y, Vector2i(cell.x, cell.x))
		span[cell.y] = Vector2i(mini(old.x, cell.x), maxi(old.y, cell.x))
	var rows: Array[int] = []
	for y in range(first, LAYOUT.ROWS - LAYOUT.GATE_INSET):
		var here: Vector2i = span.get(y, Vector2i(-1, -1))
		if (
			not wet.has(Vector2i(left - 1, y))
			and not wet.has(Vector2i(left, y))
			and here.x - left >= straight
			and here.y + reach <= ridge_x
		):
			rows.append(y)
	return rows


## The Crossing's road meets the river level on one row, with straight approaches before and
## after the wet stretch and the far bank in reach of the exit (the real section draws that road).
static func _crossing_problems(slot: Slot, cells: Array[Vector2i]) -> Array[String]:
	var span := BluewaterCrossingRegion._span(slot.river, slot.entry.y)
	var reach: int = BluewaterCrossingRegion.BLUEWATER.APPROACH_STRAIGHT
	var found: Array[String] = []
	var first := -1
	var last := -1
	for index in cells.size():
		if slot.river.has(cells[index]):
			first = index if first < 0 else first
			last = index
	if span.y < 0 or first < reach or last + reach >= cells.size():
		return ["the crossing has no room for straight approaches"]
	for step in range(1, reach + 1):
		if (
			cells[first - step] != cells[first] + Vector2i.LEFT * step
			or cells[last + step] != cells[last] + Vector2i.RIGHT * step
		):
			found.append("the bridge approaches are not straight")
			break
	if cells[last].y != slot.entry.y:
		found.append("the bridge is not level with the entry")
	return found


## The lane rule over the whole road (the six spines end to end): no cell twice, and no two cells
## `lane_run` or more apart along the road closer than `lane_gap` in a straight line.
func _lane_problems(cells: Array[Vector2i]) -> Array[String]:
	var seen := {}
	for cell in cells:
		if seen.has(cell):
			return ["the road visits %s twice" % cell]
		seen[cell] = true
	for later in range(lane_run, cells.size()):
		for earlier in later - lane_run + 1:
			if (cells[later] - cells[earlier]).length_squared() < lane_gap * lane_gap:
				return ["the road at %s runs beside itself at %s" % [cells[later], cells[earlier]]]
	return []


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
	layout.lane_gap = LAYOUT.LANE_GAP
	layout.lane_run = LAYOUT.LANE_RUN
	layout.section_attempts = LAYOUT.SECTION_ATTEMPTS
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
	# Ridge: above the Crossing, on the far bank of the river.
	var ridge_x := _between(rng, right - reach.y, right - reach.x)
	# Crossing: right of the Meadow, on a row where the river leaves room for straight approaches
	# and for the bank to turn north to the Ridge; the river is drawn again until one does.
	var first := maxi(ys[0] + inset, ys[1] + LAYOUT.CROSSING_DROP)
	var rows: Array[int] = []
	for _try in LAYOUT.RIVER_TRIES:
		layout.river_cells.clear()
		layout._draw_river(rng)
		rows = layout._crossing_rows(left, ridge_x, first)
		if not rows.is_empty():
			break
	if rows.is_empty():
		rows.append(first)
	var y: int = rows[rng.next_int(rows.size())]
	exits.append(Vector2i(left - 1, y))
	entries.append(Vector2i(left, y))
	exits.append(Vector2i(ridge_x, ys[1]))
	entries.append(Vector2i(ridge_x, ys[1] - 1))
	# Fold: right of the Ridge.
	y = _between(rng, LAYOUT.RIDGE_EXIT_ROWS.x, LAYOUT.RIDGE_EXIT_ROWS.y)
	exits.append(Vector2i(right - 1, y))
	entries.append(Vector2i(right, y))
	# Heartkeep: under the Fold, then on to the Heartstone at the east edge.
	x = _between(rng, right + inset, LAYOUT.COLS - 1 - inset)
	exits.append(Vector2i(x, ys[2] - 1))
	entries.append(Vector2i(x, ys[2]))
	exits.append(Vector2i(LAYOUT.COLS - 1, _between(rng, end.x, end.y)))
	for index in rects.size():
		var slot := Slot.new()
		slot.id = index
		slot.role = LAYOUT.ROLES[index]
		slot.rect = rects[index]
		slot.entry = entries[index]
		slot.exit = exits[index]
		slot.margin = LAYOUT.BLOCK_MARGIN
		slot.bend_run = layout.bend_run
		for cell in layout.river_cells:
			if slot.rect.has_point(cell):
				slot.river.append(cell)
		slot.spine = _spine(slot)
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


## The road's waypoints through a region: one wide bend. The road leaves the entry square on to the
## border, runs to a corner where the line from the entry meets the line into the exit, and the
## corner is rounded by an arc of `BEND_RADIUS` cells (less when a leg is shorter); the waypoints
## are spaced `SPINE_SPACING` apart or less, so the spline stays smooth. The Crossing's road is
## the one its section draws.
static func _spine(slot: Slot) -> Array[Vector2]:
	var start := Vector2(slot.entry) + Vector2(HALF, HALF)
	var finish := Vector2(slot.exit) + Vector2(HALF, HALF)
	if slot.id == Region.BLUEWATER_CROSSING:
		return BluewaterCrossingRegion.waypoints(
			slot, BluewaterCrossingRegion._span(slot.river, slot.entry.y)
		)
	var heading := Vector2(_inward(slot.rect, slot.entry))
	var arriving := -Vector2(_inward(slot.rect, slot.exit))
	var corner := Vector2(finish.x, start.y) if heading.y == 0.0 else Vector2(start.x, finish.y)
	var leg_in := (corner - start).length()
	var leg_out := (finish - corner).length()
	var radius := minf(float(LAYOUT.BEND_RADIUS), minf(leg_in, leg_out))
	var first := corner - heading * radius
	var last := corner + arriving * radius
	var middle := corner + (-heading + arriving) * (radius * (1.0 - sqrt(HALF)))
	var spine: Array[Vector2] = [start]
	_fill(spine, first)
	spine.append(middle)
	spine.append(last)
	_fill(spine, finish)
	return spine


## Adds the waypoints from the last one to `to`, evenly spaced `SPINE_SPACING` apart or less.
static func _fill(spine: Array[Vector2], to: Vector2) -> void:
	var from := spine[spine.size() - 1]
	var steps := int(floor((from.distance_to(to) - HALF) / LAYOUT.SPINE_SPACING)) + 1
	for step in range(1, steps + 1):
		spine.append(from + (to - from) * (float(step) / float(steps)))


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
