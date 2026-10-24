## Composes the valley's road from the segment library (#433, epic #404): for each region the seed
## picks one of the segment sequences its role allows, `SegmentFitter` fits it between the region's
## gates, and the six pieces joined end to end must pass the layout's checks, the curvature limit,
## no template three times in a row and the length bounds; otherwise the next draw is tried.
class_name RouteComposer
extends RefCounted

const ROUTES := preload("res://content/valley/route_rules.gd")
const HALF := 0.5


## Sets every slot's `spine` and the layout's `route_segments`; false when no draw passes.
static func compose(layout: ValleyLayout, rng: Rng) -> bool:
	for attempt in ROUTES.ATTEMPTS:
		var ids: Array[StringName] = []
		var spines: Array[Array] = []
		var lanes: Array[Array] = []
		var lane_ids: Array[StringName] = []
		for slot in layout.slots:
			var piece := _slot_spine(slot, rng)
			if not piece.ok():
				break
			spines.append(piece.points)
			ids.append_array(piece.ids)
			var lane := SlotRoad.new()
			if slot.branch_entry.x >= 0:
				lane = _lane_spine(slot, piece)
				if not lane.ok():
					break
				lane_ids.append_array(lane.ids)
			lanes.append(lane.points)
		if spines.size() < layout.slots.size():
			continue
		for index in spines.size():
			layout.slots[index].spine.assign(spines[index])
			layout.slots[index].branch_spine.assign(lanes[index])
		layout.route_segments = ids
		layout.lane_segments = lane_ids
		if _accepts(layout):
			return true
	return false


## The Crossing's road: a bridge level with the entry row over the river, then a bend to the exit.
## The section draws it again from the same data, so it never uses the stream.
static func crossing_waypoints(slot: ValleyPlan.Slot, span: Vector2i) -> SlotRoad:
	return lane_waypoints(slot.entry, slot.exit, slot, span)


## The same road for a lane that enters on `entry`'s row (the fork's lower lane, #481).
static func lane_waypoints(
	entry: Vector2i, exit: Vector2i, slot: ValleyPlan.Slot, span: Vector2i
) -> SlotRoad:
	var reach: int = ValleyLayout.LAYOUT.CROSSING_REACH
	var row := float(entry.y) + HALF
	var start := Vector2(entry) + Vector2(HALF, HALF)
	var finish := Vector2(exit) + Vector2(HALF, HALF)
	var junction := Vector2(float(span.y + reach) + HALF, row)
	var sequence: Array = ROUTES.ALLOWED[ValleyLayout.Region.BLUEWATER_CROSSING][0]
	var road := SlotRoad.new()
	var heading := _headings(slot, entry, exit)
	var bias: float = ROUTES.CROSSING_BIAS
	var bridge := _fit(sequence[0], start, heading[0], junction, heading[0], slot, bias)
	var bend := _fit(sequence[1], junction, heading[0], finish, heading[1], slot, bias)
	if bridge.ok() and bend.ok():
		road.points = bridge.points + bend.points.slice(1)
		road.ids = [sequence[0], sequence[1]]
	return road


## A region's road: its waypoints and the template ids, or empty when nothing fits.
class SlotRoad:
	extends RefCounted
	var points: Array[Vector2] = []
	var ids: Array[StringName] = []
	## The bias the road was fitted with (the fork's second lane uses the same one).
	var bias: float = 0.0

	func ok() -> bool:
		return not points.is_empty()


static func _slot_spine(slot: ValleyPlan.Slot, rng: Rng) -> SlotRoad:
	if slot.id == ValleyLayout.Region.BLUEWATER_CROSSING:
		return crossing_waypoints(slot, BluewaterCrossingRegion._span(slot.river, slot.entry.y))
	var options: Array = ROUTES.ALLOWED[slot.id]
	var first := rng.next_int(options.size())
	var draw := float(rng.next_int(ROUTES.BIAS_STEPS)) / float(ROUTES.BIAS_STEPS - 1)
	var bias: float = ROUTES.BIAS_FLOOR + (1.0 - ROUTES.BIAS_FLOOR) * draw
	var start := Vector2(slot.entry) + Vector2(HALF, HALF)
	var finish := Vector2(slot.exit) + Vector2(HALF, HALF)
	var heading := _headings(slot, slot.entry, slot.exit)
	for step in options.size():
		var option: Array = options[(first + step) % options.size()]
		var fitted := _fit(option[0], start, heading[0], finish, heading[1], slot, bias)
		if fitted.ok():
			var road := SlotRoad.new()
			road.points = fitted.points
			road.ids = [option[0]]
			road.bias = bias
			return road
	return SlotRoad.new()


## The fork's second lane through a slot (#481): the Crossing's own road from the lane's entry
## row; elsewhere the template of the upper lane at the same bias (nested curves stay apart),
## else the slot's other options. The layout's gap rule judges the pair.
static func _lane_spine(slot: ValleyPlan.Slot, upper: SlotRoad) -> SlotRoad:
	if slot.id == ValleyLayout.Region.BLUEWATER_CROSSING:
		var span := BluewaterCrossingRegion._span(slot.river, slot.branch_entry.y)
		return lane_waypoints(slot.branch_entry, slot.exit, slot, span)
	var start := Vector2(slot.branch_entry) + Vector2(HALF, HALF)
	var finish := Vector2(slot.branch_exit) + Vector2(HALF, HALF)
	var heading := _headings(slot, slot.branch_entry, slot.branch_exit)
	var options: Array = ROUTES.ALLOWED[slot.id]
	var ids: Array = [upper.ids[0]]
	for option in options:
		if option[0] != upper.ids[0]:
			ids.append(option[0])
	for id in ids:
		var fitted := _fit(id, start, heading[0], finish, heading[1], slot, upper.bias)
		if fitted.ok():
			var road := SlotRoad.new()
			road.points = fitted.points
			road.ids = [id]
			road.bias = upper.bias
			return road
	return SlotRoad.new()


## The template `id` fitted from `from` (heading `entry_dir`) to `to` (heading `exit_dir`).
static func _fit(
	id: StringName,
	from: Vector2,
	entry_dir: Vector2,
	to: Vector2,
	exit_dir: Vector2,
	slot: ValleyPlan.Slot,
	bias: float
) -> SegmentFitter.Fitted:
	var segment := RoadSegment.get_segment(id)
	return SegmentFitter.fit(segment, from, entry_dir, to, exit_dir, slot.rect, bias)


## The way the road runs in at the region's entry gate, and out at the exit gate.
static func _headings(slot: ValleyPlan.Slot, entry: Vector2i, exit: Vector2i) -> Array[Vector2]:
	var inward := Vector2(ValleyLayout._inward(slot.rect, entry))
	return [inward, -Vector2(ValleyLayout._inward(slot.rect, exit))]


static func _accepts(layout: ValleyLayout) -> bool:
	if not layout.problems().is_empty():
		return false
	var length := 0
	for slot in layout.slots:
		length += RoadSpline.build(slot.spine).cells.size()
	if length < ROUTES.LENGTH.x or length > ROUTES.LENGTH.y:
		return false
	var run := 1
	for index in range(1, layout.route_segments.size()):
		run = run + 1 if layout.route_segments[index] == layout.route_segments[index - 1] else 1
		if run > ROUTES.MAX_REPEAT:
			return false
	return true
