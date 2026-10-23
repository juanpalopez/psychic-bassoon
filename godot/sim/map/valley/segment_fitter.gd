## Fits a road template between two gates of a region (#433, epic #404). The road enters through a
## border (its heading is the border's inward normal) and leaves through another. Of the eight
## symmetries of a template (four rotations, each mirrored) it keeps the ones whose ports point
## along the gates' headings, scales the template along its two axes (within its scale range) so its
## exit is as near the exit gate as the bound on straight leads allows, adds the straight leads that
## close the gap, and rejects a fit that leaves the region or turns too sharply. Only `+ - * /`.
class_name SegmentFitter
extends RefCounted

const FIT := preload("res://content/valley/route_rules.gd")


## The waypoints of a fit, or the reason there is none.
class Fitted:
	extends RefCounted
	var points: Array[Vector2] = []
	var reason := ""
	## The straight lead added before and after the template (cells).
	var lead := 0.0

	func ok() -> bool:
		return not points.is_empty()


## The template placed from `entry` (heading `entry_dir`) to `exit` (heading `exit_dir`, the way the
## road leaves) inside `rect`. `bias` in [0, 1] picks the scale between the least and the most.
static func fit(
	segment: RoadSegment,
	entry: Vector2,
	entry_dir: Vector2,
	exit: Vector2,
	exit_dir: Vector2,
	rect: Rect2i,
	bias: float
) -> Fitted:
	var best := Fitted.new()
	best.reason = "no symmetry of %s has ports along the gates" % segment.id
	for axis: Vector2 in FIT.AXES:
		for mirror: float in [1.0, -1.0]:
			var across := Vector2(-axis.y, axis.x) * mirror
			var found := _place(
				segment, [entry, exit, entry_dir, exit_dir], [axis, across], rect, bias
			)
			if found.ok() and (not best.ok() or found.lead < best.lead):
				best = found
			elif not best.ok() and found.reason != "":
				best.reason = found.reason
	return best


## One symmetry: `gates` is entry, exit, entry heading, exit heading; `frame` the world vectors of
## the local x and y axes.
static func _place(
	segment: RoadSegment, gates: Array, frame: Array, rect: Rect2i, bias: float
) -> Fitted:
	var found := Fitted.new()
	var entry: Vector2 = gates[0]
	var exit: Vector2 = gates[1]
	var heading_in := _world(segment.entry_heading, frame)
	var heading_out := _world(segment.exit_heading, frame)
	if heading_in.dot(gates[2]) < FIT.HEADING_COS or heading_out.dot(gates[3]) < FIT.HEADING_COS:
		return found
	var want := _local(exit - entry, frame)
	var bounds := _scale_bounds(segment, want)
	if bounds.is_empty():
		found.reason = "%s does not fit these gates within its scale range" % segment.id
		return found
	var scale := Vector2.ONE
	var residual := Vector2.ZERO
	for axis in 2:
		if absf(segment.exit[axis]) < FIT.EPSILON:
			if absf(want[axis]) > FIT.FLAT_TOLERANCE:
				found.reason = (
					"%s cannot reach a gate %.1f cells off its line" % [segment.id, want[axis]]
				)
				return found
			continue
		scale[axis] = bounds[axis].x + (bounds[axis].y - bounds[axis].x) * bias
		residual[axis] = want[axis] - scale[axis] * segment.exit[axis]
	var leads := _leads(segment, residual)
	if leads.size() < 2:
		found.reason = "%s leaves a gap no straight lead closes" % segment.id
		return found
	var head: float = leads[0]
	var tail: float = leads[1]
	var points: Array[Vector2] = [entry]
	var start := entry + heading_in * head
	if head > FIT.EPSILON:
		points.append(start)
	for index in range(1, segment.points.size() - 1):
		points.append(start + _world(segment.points[index] * scale, frame))
	if tail > FIT.EPSILON:
		points.append(start + _world(segment.exit * scale, frame))
	points.append(exit)
	found.reason = _problem(points, rect)
	if found.reason == "":
		found.points = points
		found.lead = head + tail
	return found


## Per axis, the least and most scale that keeps the straight leads within bounds, drawn together
## to one scale for both axes where the ranges overlap (a lopsided stretch bends too sharply); empty
## when an axis cannot be met.
static func _scale_bounds(segment: RoadSegment, want: Vector2) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var low := 0.0
	var high := 1.0e9
	for axis in 2:
		var extent := absf(segment.exit[axis])
		if extent < FIT.EPSILON:
			found.append(Vector2.ONE)
			continue
		if want[axis] * segment.exit[axis] <= 0.0:
			return []
		var wanted := absf(want[axis])
		var most := minf(segment.scale_range.y, wanted / extent)
		var least := maxf(segment.scale_range.x, (wanted - FIT.LEAD_MAX) / extent)
		if not _closable(segment, axis):
			# no straight lead runs along this axis (a U-turn's side), so the scale alone
			# must reach the gate
			var exact := wanted / extent
			if (
				exact < segment.scale_range.x - FIT.EPSILON
				or exact > segment.scale_range.y + FIT.EPSILON
			):
				return []
			least = exact
			most = exact
		if least > most + FIT.EPSILON:
			return []
		found.append(Vector2(least, maxf(most, least)))
		low = maxf(low, least)
		high = minf(high, maxf(most, least))
	if low <= high:
		for axis in found.size():
			if absf(segment.exit[axis]) >= FIT.EPSILON:
				found[axis] = Vector2(low, high)
	return found


## Whether a straight lead before or after the template can make up a gap along this local axis.
static func _closable(segment: RoadSegment, axis: int) -> bool:
	return absf(segment.entry_heading[axis]) > 0.5 or absf(segment.exit_heading[axis]) > 0.5


## The lengths of the leads (head, tail) that close `residual`, or nothing when none can.
static func _leads(segment: RoadSegment, residual: Vector2) -> Array[float]:
	var lengths: Array[float] = [0.0, 0.0]
	for axis in 2:
		var gap: float = residual[axis]
		if absf(gap) < FIT.EPSILON:
			continue
		if absf(segment.entry_heading[axis]) > 0.5 and gap * segment.entry_heading[axis] > 0.0:
			lengths[0] += absf(gap)
		elif absf(segment.exit_heading[axis]) > 0.5 and gap * segment.exit_heading[axis] > 0.0:
			lengths[1] += absf(gap)
		else:
			return []
	return lengths


## What is wrong with a fit's road: it leaves the region, a waypoint hugs the edge, or it bends
## too sharply (the cosine of the turn between two one cell steps).
static func _problem(points: Array[Vector2], rect: Rect2i) -> String:
	var low := Vector2(rect.position) + Vector2(FIT.MARGIN, FIT.MARGIN)
	var high := Vector2(rect.end) - Vector2(FIT.MARGIN, FIT.MARGIN)
	for index in range(1, points.size() - 1):
		var at := points[index]
		if at.x < low.x or at.y < low.y or at.x > high.x or at.y > high.y:
			return "waypoint %s is too near the region's edge" % points[index]
	var curve := RoadSpline.build(points)
	for cell in curve.cells:
		if not rect.has_point(cell):
			return "the road leaves the region at %s" % cell
	return "" if is_smooth(curve) else "the road bends too sharply"


## Whether no two consecutive one cell steps of the curve turn by more than the limit.
static func is_smooth(curve: RoadCurve) -> bool:
	var steps: Array[Vector2] = [Vector2(curve.xs[0], curve.ys[0])]
	for index in range(1, curve.xs.size()):
		var point := Vector2(curve.xs[index], curve.ys[index])
		if point.distance_to(steps[steps.size() - 1]) >= 1.0:
			steps.append(point)
	for index in range(1, steps.size() - 1):
		var before := (steps[index] - steps[index - 1]).normalized()
		if before.dot((steps[index + 1] - steps[index]).normalized()) < FIT.CURVE_COS:
			return false
	return true


static func _world(local: Vector2, frame: Array) -> Vector2:
	var x: Vector2 = frame[0]
	var y: Vector2 = frame[1]
	return x * local.x + y * local.y


static func _local(world: Vector2, frame: Array) -> Vector2:
	var x: Vector2 = frame[0]
	var y: Vector2 = frame[1]
	return Vector2(world.dot(x), world.dot(y))
