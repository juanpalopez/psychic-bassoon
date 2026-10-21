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
	found.append_array(_straight_problems())
	return found


## No straight leg longer than `MAX_STRAIGHT` cells, also across the gates between regions (the
## Crossing's level approaches to the bridge excepted).
func _straight_problems() -> Array[String]:
	var found: Array[String] = []
	for group in [[0, 1], [3, 4, 5]]:
		var cells: Array[Vector2i] = []
		for id in group:
			cells.append_array(RoadSpline.build(slots[id].spine).cells)
		if _longest_straight(cells) > LAYOUT.MAX_STRAIGHT:
			found.append("regions %s: the road runs straight for too long" % [group])
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
	var x := _between(rng, LAYOUT.MEADOW_GATE.x, LAYOUT.MEADOW_GATE.y)
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
	x = right + _between(rng, LAYOUT.HEARTKEEP_GATE.x, LAYOUT.HEARTKEEP_GATE.y)
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
		slot.spine = _spine(rng, slot)
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


## The road's waypoints through a region, a sweeping curve: the entry, a short lead along the
## heading into the region (square to the border), one or two middle points pushed off the chord
## between the leads towards the region's middle (one gives a C, two a S), a lead before the
## exit, and the exit. The spline does the curving, so the road runs on diagonals, not in legs.
## The Crossing's road is the one its section draws.
static func _spine(rng: Rng, slot: Slot) -> Array[Vector2]:
	var start := Vector2(slot.entry) + Vector2(HALF, HALF)
	var finish := Vector2(slot.exit) + Vector2(HALF, HALF)
	if slot.id == Region.BLUEWATER_CROSSING:
		return BluewaterCrossingRegion.waypoints(
			slot, BluewaterCrossingRegion._span(slot.river, slot.entry.y)
		)
	var lead_in := start + Vector2(_inward(slot.rect, slot.entry)) * _lead(rng)
	var lead_out := finish + Vector2(_inward(slot.rect, slot.exit)) * _lead(rng)
	var chord := lead_out - lead_in
	var length := chord.length()
	var normal := Vector2(-chord.y, chord.x) / maxf(length, 1.0)
	var middle := Vector2(slot.rect.position) + Vector2(slot.rect.size) * HALF
	var side := 1.0 if (middle - (lead_in + lead_out) * HALF).dot(normal) >= 0.0 else -1.0
	var push := float(LAYOUT.PUSH.x + rng.next_int(LAYOUT.PUSH.y + 1))
	push = minf(push, length * LAYOUT.PUSH_SHARE)
	var bends := 1 if length >= LAYOUT.S_LENGTH else 0
	var low := (
		Vector2(slot.rect.position + Vector2i.ONE * LAYOUT.SPINE_MARGIN) + Vector2(HALF, HALF)
	)
	var high := Vector2(slot.rect.end - Vector2i.ONE * LAYOUT.SPINE_MARGIN) - Vector2(HALF, HALF)
	var spine: Array[Vector2] = [start, lead_in]
	for step in range(1, bends + 1):
		var point := lead_in + chord * (float(step) / float(bends + 1))
		point += normal * (push * side * (1.0 if step % 2 == 1 else -1.0))
		spine.append(
			Vector2(maxf(low.x, minf(point.x, high.x)), maxf(low.y, minf(point.y, high.y)))
		)
	spine.append(lead_out)
	spine.append(finish)
	return spine


static func _lead(rng: Rng) -> float:
	return float(LAYOUT.LEAD.x + rng.next_int(LAYOUT.LEAD.y + 1))


## The longest straight run of road cells (steps in one direction), for the rule that a region's
## road has no long straight leg.
static func _longest_straight(cells: Array[Vector2i]) -> int:
	var longest := 1
	var run := 1
	for index in range(2, cells.size()):
		run = (
			run + 1 if cells[index] - cells[index - 1] == cells[index - 1] - cells[index - 2] else 1
		)
		longest = maxi(longest, run)
	return longest


## The share of the six roads on a diagonal: the heading over a cell's reach either side is
## between 20 and 70 degrees off an axis (the ratio of its steps, no trig).
func diagonal_share() -> float:
	var diagonal := 0
	var total := 0
	for slot in slots:
		var curve := RoadSpline.build(slot.spine)
		for index in range(2, curve.xs.size() - 2):
			var across := absf(curve.xs[index + 2] - curve.xs[index - 2])
			var down := absf(curve.ys[index + 2] - curve.ys[index - 2])
			total += 1
			if (
				down * 1000.0 > LAYOUT.DIAGONAL.x * across
				and down * 1000.0 < LAYOUT.DIAGONAL.y * across
			):
				diagonal += 1
	return float(diagonal) / float(maxi(total, 1))


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
