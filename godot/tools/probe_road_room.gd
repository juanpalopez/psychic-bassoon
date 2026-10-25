## Room per shared region for the long road templates (#460). For each seed's real layout, every
## region is fitted with the real `SegmentFitter` at four biases, once at today's gates and once at
## each gate variant (March exit column, Ridge exit row and entry, Fold exit offset, Heartkeep
## entry offset and end row), under the lane rule (no cell twice, cells 12 or more apart along the
## road at least 5 apart). Prints the rows that fit on at least `--min-fit=` percent of the seeds
## (default 20), with the mean cell count.
## Run: godot --headless --path godot -s tools/probe_road_room.gd -- --n=60 --from=1
extends SceneTree

const SEG := preload("res://content/valley/segments.gd")
const HALF := 0.5
const BIASES := 4
const BIAS_FIRST := 0.7
const BIAS_STEP := 0.1
const LANE_ALONG := 12
const LANE_APART_SQ := 25
## Only the templates that double back add length (every other template only moves forward).
const IDS: Array[StringName] = [SEG.HOOK, SEG.U_TURN]
const MARCH := 0
const RIDGE := 3
const FOLD := 4
const HEARTKEEP := 5


func _lane_ok(cells: Array[Vector2i]) -> bool:
	var seen := {}
	for c in cells:
		if seen.has(c):
			return false
		seen[c] = true
	for later in range(LANE_ALONG, cells.size()):
		for earlier in later - LANE_ALONG + 1:
			if (cells[later] - cells[earlier]).length_squared() < LANE_APART_SQ:
				return false
	return true


## The best cell count of template `id` between the entry and exit cells in `rect`, or 0.
func _best(id: StringName, rect: Rect2i, entry: Vector2i, exit: Vector2i) -> int:
	var seg := RoadSegment.get_segment(id)
	var h_in := Vector2(ValleyLayout._inward(rect, entry))
	var h_out := -Vector2(ValleyLayout._inward(rect, exit))
	var best := 0
	for b in BIASES:
		var f := SegmentFitter.fit(
			seg,
			Vector2(entry) + Vector2(HALF, HALF),
			h_in,
			Vector2(exit) + Vector2(HALF, HALF),
			h_out,
			rect,
			BIAS_FIRST + BIAS_STEP * b
		)
		if f.ok():
			var cells := RoadSpline.build(f.points).cells
			if _lane_ok(cells):
				best = maxi(best, cells.size())
	return best


## The gate variants of a slot as [label, entry, exit].
func _variants(slot) -> Array:
	var r: Rect2i = slot.rect
	var out: Array = [["cur", slot.entry, slot.exit]]
	match slot.id:
		MARCH:
			for col in range(1, 10):
				out.append(["exitcol%d" % col, slot.entry, Vector2i(col, slot.exit.y)])
		RIDGE:
			for row in range(2, 10):
				out.append(["exitrow%d" % row, slot.entry, Vector2i(slot.exit.x, row)])
			for dx in range(-6, 1):
				out.append(["entrydx%d" % dx, slot.entry + Vector2i(dx, 0), slot.exit])
		FOLD:
			for off in range(1, 9):
				out.append(
					["exitoff%d" % off, slot.entry, Vector2i(r.position.x + off, slot.exit.y)]
				)
		HEARTKEEP:
			for off in range(1, 9):
				for row in range(r.position.y + 2, 23, 2):
					out.append(
						[
							"entoff%d_end%d" % [off, row],
							Vector2i(r.position.x + off, slot.entry.y),
							Vector2i(slot.exit.x, row)
						]
					)
	return out


func _init() -> void:
	var n := 60
	var first := 1
	var min_fit := 20
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
		if arg.begins_with("--from="):
			first = int(arg.trim_prefix("--from="))
		if arg.begins_with("--min-fit="):
			min_fit = int(arg.trim_prefix("--min-fit="))
	var stats := {}  # key -> [fits, total cells]
	var layouts := 0
	for seed in range(first, first + n):
		var lay := ValleyLayout.generate(seed, ValleyLayout.LAYOUT.COLS, ValleyLayout.LAYOUT.ROWS)
		if lay == null:
			continue
		layouts += 1
		for slot in lay.slots:
			for v in _variants(slot):
				for id in IDS:
					var cells := _best(id, slot.rect, v[1], v[2])
					var key := "r%d %s %s" % [slot.id, v[0], id]
					var s: Array = stats.get(key, [0, 0])
					if cells > 0:
						s[0] += 1
						s[1] += cells
					stats[key] = s
	print("layouts ", layouts, " from ", first)
	var keys := stats.keys()
	keys.sort()
	for k in keys:
		var s: Array = stats[k]
		if s[0] * 100 >= min_fit * layouts and s[0] > 0:
			print("%-34s fit %3d/%d  mean cells %.1f" % [k, s[0], layouts, float(s[1]) / s[0]])
	quit()
