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
const ROAD := preload("res://content/valley/road_rules.gd")
const HALF := 0.5
## The regions whose roads run end to end across their gates, for the straight-leg rule: the March
## and the Meadow, then the Ridge, the Fold and Heartkeep (the Crossing breaks the road).
const STRAIGHT_GROUPS: Array = [
	[Region.OUTER_MARCH, Region.SUNKEN_MEADOW],
	[Region.BROKEN_RIDGE, Region.ANCIENT_FOLD, Region.HEARTKEEP_APPROACH],
]

## The river's centre line (a spline from the top edge to the bottom edge).
var river: RoadCurve = null
## Every cell of the river: the centre line and the cells beside it that make it wide.
var river_cells: Array[Vector2i] = []
## The template ids the road is made of, in road order (`RouteComposer`).
var route_segments: Array[StringName] = []
## The same for the fork's lower lane (#481), over the slots that have one; empty without a fork.
var lane_segments: Array[StringName] = []


## The layout for a seed, or null (with an error) when no draw passes `problems` and stitches with
## the stand-in sections (no error when `quiet`). Each retry draws the next layout from the same
## stream.
static func generate(
	seed: int, cols: int, rows: int, forked: bool = LAYOUT.FORK_LANES, quiet: bool = false
) -> ValleyLayout:
	assert(
		cols == LAYOUT.COLS and rows == LAYOUT.ROWS,
		"the layout is made for its own size (LAYOUT.COLS by LAYOUT.ROWS)"
	)
	var rng := Rng.derive(seed, Streams.VALLEY_LAYOUT)
	var fork_rng := Rng.derive(seed, Streams.VALLEY_FORK) if forked else null
	for attempt in LAYOUT.MAX_ATTEMPTS:
		var layout := _draw(seed, rng, fork_rng)
		if layout != null and layout.problems().is_empty() and _stitches(layout):
			return layout
	if not quiet:
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
			found.append_array(_crossing_problems(slot, cells, slot.entry.y))
	found.append_array(_lane_problems(all_cells))
	found.append_array(_straight_problems())
	found.append_array(_fork_problems(wet))
	return found


## What is wrong with the fork's lower lane (#481): it stays in its regions, keeps dry but for
## one wade of the river on its own level row, follows the lane rule and the straight-leg rule
## as a whole road, and keeps `LANE_APART` cells from the upper lane but near the fork and the
## merge.
func _fork_problems(wet: Dictionary) -> Array[String]:
	var found: Array[String] = []
	if not slots.any(func(slot: Slot) -> bool: return slot.has_branch()):
		return found
	var road: Array[Vector2i] = []
	var own: Array[Vector2i] = []
	var upper: Array[Vector2i] = []
	for slot in slots:
		var cells := RoadSpline.build(slot.spine).cells
		if not slot.has_branch():
			road.append_array(cells)
			continue
		var lane := RoadSpline.build(slot.branch_spine).cells
		for cell in lane:
			if not slot.rect.has_point(cell):
				found.append("region %d: the lower lane leaves it at %s" % [slot.id, cell])
				break
		var dry := slot.id != Region.BLUEWATER_CROSSING
		if dry and lane.any(func(cell: Vector2i) -> bool: return wet.has(cell)):
			found.append("region %d: the lower lane touches the river" % slot.id)
		elif not dry:
			if _wet_runs(lane, wet) != 1:
				found.append("region %d: the lower lane must wade the river once" % slot.id)
			found.append_array(_crossing_problems(slot, lane, slot.branch_entry.y))
		road.append_array(lane)
		own.append_array(lane)
		upper.append_array(cells)
	found.append_array(_lane_problems(road))
	found.append_array(_apart_problems(own, upper))
	for group in STRAIGHT_GROUPS:
		var cells: Array[Vector2i] = []
		for id in group:
			cells.append_array(
				(
					RoadSpline
					. build(slots[id].branch_spine if slots[id].has_branch() else slots[id].spine)
					. cells
				)
			)
		if _longest_straight(cells) > LAYOUT.MAX_STRAIGHT:
			found.append("regions %s: the lower lane runs straight for too long" % [group])
	return found


## The lower lane's own cells keep `LANE_APART` cells from the upper lane's, but within
## `LANE_JOIN` cells of either end of the stretch (the fork and the merge).
static func _apart_problems(own: Array[Vector2i], upper: Array[Vector2i]) -> Array[String]:
	var apart: int = LAYOUT.LANE_APART
	for index in range(LAYOUT.LANE_JOIN, own.size() - LAYOUT.LANE_JOIN):
		for cell in upper:
			if (own[index] - cell).length_squared() < apart * apart:
				return ["the lanes run within %d cells of each other at %s" % [apart, own[index]]]
	return []


## No straight leg longer than `MAX_STRAIGHT` cells, also across the gates between regions (the
## Crossing's level approaches to the bridge excepted).
func _straight_problems() -> Array[String]:
	var found: Array[String] = []
	for group in STRAIGHT_GROUPS:
		var cells: Array[Vector2i] = []
		for id in group:
			cells.append_array(RoadSpline.build(slots[id].spine).cells)
		if _longest_straight(cells) > LAYOUT.MAX_STRAIGHT:
			found.append("regions %s: the road runs straight for too long" % [group])
	return found


## The rows from `first` down where the Crossing can enter: both gate cells dry, the river at
## least `APPROACH_STRAIGHT` cells in from the entry and its far side `CROSSING_REACH` plus
## `CROSSING_BEND_ROOM` cells short of the Ridge's gate column.
func _crossing_rows(left: int, ridge_x: int, first: int) -> Array[int]:
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
			and here.y + LAYOUT.CROSSING_REACH + LAYOUT.CROSSING_BEND_ROOM <= ridge_x
		):
			rows.append(y)
	return rows


## The Crossing's road meets the river level on one row, with straight approaches before and
## after the wet stretch and the far bank in reach of the exit (the real section draws that road).
static func _crossing_problems(slot: Slot, cells: Array[Vector2i], row: int) -> Array[String]:
	var span := BluewaterCrossingRegion._span(slot.river, row)
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
	if cells[last].y != row:
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


static func _draw(seed: int, rng: Rng, fork_rng: Rng = null) -> ValleyLayout:
	var layout := ValleyLayout.new()
	layout.seed = seed
	layout.cols = LAYOUT.COLS
	layout.rows = LAYOUT.ROWS
	layout.hero_caps = LAYOUT.HERO_CAPS
	layout.bend_run = LAYOUT.BEND_RUN
	layout.road_width = ROAD.ROAD_WIDTH_CELLS
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
	var dry_rows: Array[int] = []
	for _try in LAYOUT.RIVER_TRIES:
		layout.river_cells.clear()
		layout._draw_river(rng)
		rows = layout._crossing_rows(left, ridge_x, first)
		var open_rows := rows
		if fork_rng != null:
			# The upper lane may enter higher; only the lower one needs the drop to turn north.
			open_rows = layout._crossing_rows(
				left, ridge_x, maxi(ys[0] + inset, ys[1] + LAYOUT.FORK_UPPER_DROP)
			)
			rows = _with_lower_row(open_rows, first)
		if not rows.is_empty():
			dry_rows = open_rows
			break
	if rows.is_empty():
		if fork_rng != null:
			return null
		rows.append(first)
	var y: int = rows[rng.next_int(rows.size())]
	exits.append(Vector2i(left - 1, y))
	entries.append(Vector2i(left, y))
	# The fork's lower lane: it leaves the Meadow's entry gate and reaches the Crossing on the row
	# `gap` rows below, from its own stream.
	var lower := -1
	if fork_rng != null:
		lower = y + _gap_below(dry_rows, y, first, fork_rng)
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
		slot.road_width = layout.road_width
		for cell in layout.river_cells:
			if slot.rect.has_point(cell):
				slot.river.append(cell)
		if lower >= 0 and index == Region.SUNKEN_MEADOW:
			slot.branch_entry = slot.entry
			slot.branch_exit = Vector2i(left - 1, lower)
		elif lower >= 0 and index == Region.BLUEWATER_CROSSING:
			slot.branch_entry = Vector2i(left, lower)
			slot.branch_exit = slot.exit
		layout.slots.append(slot)
	return layout if RouteComposer.compose(layout, rng) else null


## The rows that can enter the Crossing with a second row `FORK_ROW_GAP` below that can too.
static func _with_lower_row(rows: Array[int], lowest: int) -> Array[int]:
	var found: Array[int] = []
	for row in rows:
		if _gaps_below(rows, row, lowest).size() > 0:
			found.append(row)
	return found


## The row gaps (from `FORK_ROW_GAP`) at which `row` has a lower row among `rows`, `lowest` or
## below.
static func _gaps_below(rows: Array[int], row: int, lowest: int) -> Array[int]:
	var gaps: Array[int] = []
	for gap in range(LAYOUT.FORK_ROW_GAP.x, LAYOUT.FORK_ROW_GAP.y + 1):
		if rows.has(row + gap) and row + gap >= lowest:
			gaps.append(gap)
	return gaps


static func _gap_below(rows: Array[int], row: int, lowest: int, fork_rng: Rng) -> int:
	var gaps := _gaps_below(rows, row, lowest)
	return gaps[fork_rng.next_int(gaps.size())]


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
