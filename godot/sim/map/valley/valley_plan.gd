## The macro layer of the sectioned valley (#381): cuts the board into six strips of columns,
## one per section in a fixed order, and picks the rows where the road crosses from one strip
## to the next. It builds no tiles; each section draws its own strip from its own stream.
class_name ValleyPlan
extends RefCounted

## The sections in road order. The order never changes with the seed.
enum Id {
	OUTER_MARCH,
	BROKEN_RIDGE,
	BLUEWATER_CROSSING,
	SUNKEN_MEADOW,
	ANCIENT_FOLD,
	HEARTKEEP_APPROACH,
}

const RULES := preload("res://content/valley/valley_rules.gd")
const HERO := preload("res://content/valley/hero_rules.gd")


## One section's place on the board.
class Slot:
	extends RefCounted
	var id: int = 0
	## The strip of columns the section owns, across the whole board height.
	var rect := Rect2i()
	## The road's first cell in the strip (on its left column) and its last (on its right
	## column). The next section's entry is the cell right of this exit, on the same row.
	var entry := Vector2i.ZERO
	var exit := Vector2i.ZERO
	## The kind of section (an `Id`); -1 means the id itself, as in the strip layout.
	var role: int = -1
	## Empty cells (right, bottom) a socket block keeps from the rect's edges.
	var margin := Vector2i(RULES.STRIP_RIGHT_MARGIN, 0)
	## The shortest straight runs on both sides of a turn that make it a bend to cover.
	var bend_run: int = 1
	## The road's waypoints in cell units, when the layout gives them (the 2D layout).
	var spine: Array[Vector2] = []
	## The cells of the river inside the rect, when the layout has one.
	var river: Array[Vector2i] = []


var seed: int = 0
var cols: int = 0
var rows: int = 0
## The six slots, in `Id` order.
var slots: Array[Slot] = []
## The steps the hero may need from the meadow to each kind of section: (kind, steps).
var hero_caps: Array[Vector2i] = HERO.CAPS
## The bend rule of the slots (`Slot.bend_run`), for the bends where two sections join.
var bend_run: int = 1
## The lane rule (#406): no two road cells `lane_run` or more cells apart along the road may be
## closer than `lane_gap` cells in a straight line (0: no rule, the strip valley).
var lane_gap: int = 0
var lane_run: int = 0
## How often the stitcher draws a failing section again before it gives up.
var section_attempts: int = RULES.MAX_SECTION_ATTEMPTS


## The plan for a seed on a board of `cols` by `rows` cells (the widths add up to 32 columns).
static func create(seed: int, cols: int, rows: int) -> ValleyPlan:
	var plan := ValleyPlan.new()
	plan.seed = seed
	plan.cols = cols
	plan.rows = rows
	var rng := Rng.derive(seed, Streams.VALLEY_PLAN)
	var widths := _widths(rng)
	var gates := _gate_rows(rng, rows, widths.size() + 1)
	var left := 0
	for index in widths.size():
		var slot := Slot.new()
		slot.id = index
		slot.role = index
		slot.rect = Rect2i(left, 0, widths[index], rows)
		slot.entry = Vector2i(left, gates[index])
		slot.exit = Vector2i(left + widths[index] - 1, gates[index + 1])
		plan.slots.append(slot)
		left += widths[index]
	assert(left == cols, "the strips tile %d columns, not %d" % [left, cols])
	return plan


## The stream of one section's attempt as the stitcher asks for it; a layout may use other
## stream ids.
func rng_for(id: int, attempt: int) -> Rng:
	return ValleyPlan.section_rng(seed, id, attempt)


## The stream of one section's attempt: a section drawn again never moves another one.
static func section_rng(seed: int, id: int, attempt: int) -> Rng:
	assert(attempt < RULES.SECTION_STREAM_STRIDE, "too many attempts")
	return Rng.derive(seed, Streams.VALLEY_SECTION + id * RULES.SECTION_STREAM_STRIDE + attempt)


static func _widths(rng: Rng) -> Array[int]:
	var widths: Array[int] = RULES.BASE_WIDTHS.duplicate()
	var jitter: int = RULES.BOUNDARY_JITTER
	for boundary in widths.size() - 1:
		var shift := rng.next_int(2 * jitter + 1) - jitter
		var left_width: int = widths[boundary] + shift
		var right_width: int = widths[boundary + 1] - shift
		if (
			left_width >= RULES.MIN_WIDTHS[boundary]
			and right_width >= RULES.MIN_WIDTHS[boundary + 1]
		):
			widths[boundary] = left_width
			widths[boundary + 1] = right_width
	return widths


## `count` gate rows: the road's row at the left edge, between each pair of sections, and at
## the Heartstone's edge.
static func _gate_rows(rng: Rng, rows: int, count: int) -> Array[int]:
	var low: int = RULES.GATE_MARGIN
	var high: int = rows - 1 - RULES.GATE_MARGIN
	var step: int = RULES.GATE_MAX_STEP
	var gates: Array[int] = [low + rng.next_int(high - low + 1)]
	while gates.size() < count:
		var row: int = gates[gates.size() - 1] + rng.next_int(2 * step + 1) - step
		gates.append(clampi(row, low, high))
	return gates
