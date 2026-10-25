## Road length, time under fire and exposure of the layout valley against the strip valley (#460).
## Run: godot --headless --path godot -s tools/measure_road_time.gd -- --n=300 --from=1
## Options: --n= seeds, --from= first seed, --width= road band width in cells (default the drawn
## one), --speed= multiplier on every foe's speed in this tool's arithmetic only (the strip valley
## reference stays at 1; content is never edited).
extends SceneTree

const FOES := preload("res://content/foes.gd")
const TOWERS := preload("res://content/towers.gd")
const ROAD := preload("res://content/valley/road_rules.gd")
const BAND := preload("res://tools/road_band_reach.gd")
const STATS := preload("res://tools/road_time_stats.gd")
const STEP := 0.1
const MEASURED_FOES: Array[String] = ["scrapGoblin", "corrugatedOrc", "cardboardGolem"]
const LANE_NAMES: Array[String] = ["main road", "lower lane"]
## In road order, the same as `ValleyLayout.Region` and the slot ids.
const REGION_NAMES: Array[String] = [
	"Outer March",
	"Sunken Meadow",
	"Bluewater Crossing",
	"Broken Ridge",
	"Ancient Fold",
	"Heartkeep"
]


## The routes a foe of the main source may walk: the sources' first list, else the main road
## (#481: on the forked layout valley the main road and the lower lane).
func _lanes(map: GameMap) -> Array[int]:
	var lanes: Array[int] = []
	if map.sources.is_empty():
		lanes.append(0)
	else:
		lanes.assign(Array(map.sources[0]))
	return lanes


## Walks route `index` in 0.1 cell steps. Returns distances in cells, so a foe's seconds are the
## distance over its speed: `total` (the walk), `fire` (cells inside a level-1 tower's reach to
## the centre line), `edge` (the same measured to the band's edge at `width`) and, per region of
## `rects`, `walk`, `cov` and `expo` (cells walked, cells covered, tower-cells; the last is the
## socket-seconds once divided by a speed).
func _stats(map: GameMap, width: float, index: int, rects: Array[Rect2i]) -> Dictionary:
	var route: Route = null
	if map.route_curves.is_empty():
		route = Route.build_curved(map.routes[index])
	else:
		route = Route.build_from_curve(map.routes[index], map.route_curves[index])
	var base: float = TOWERS.DEFS["spoolGuard"]["range"][0]
	var centres: Array[Vector3] = []
	for a in map.sockets:
		var c := map.socket_centre(a)
		centres.append(Vector3(c.x, c.y, base * map.range_multiplier(a)))
	var fire := 0.0
	var fire_edge := 0.0
	var walk: Array[float] = []
	var cov: Array[float] = []
	var expo: Array[float] = []
	for _r in rects.size():
		walk.append(0.0)
		cov.append(0.0)
		expo.append(0.0)
	var d := 0.0
	var k := 1
	while d < route.total:
		while k < route.cumulative.size() - 1 and route.cumulative[k] < d:
			k += 1
		var seg := route.cumulative[k] - route.cumulative[k - 1]
		var t := 0.0 if seg <= 0.0 else (d - route.cumulative[k - 1]) / seg
		var x := route.xs[k - 1] + (route.xs[k] - route.xs[k - 1]) * t
		var y := route.ys[k - 1] + (route.ys[k] - route.ys[k - 1]) * t
		var in_reach := 0
		var hit_edge := false
		for c in centres:
			var d2 := (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y)
			if d2 <= c.z * c.z:
				in_reach += 1
			var edge := BAND.edge_reach(c.z, width)
			if d2 <= edge * edge:
				hit_edge = true
		if in_reach > 0:
			fire += STEP
		if hit_edge:
			fire_edge += STEP
		STATS.add_step(walk, cov, expo, STATS.region_of(rects, x, y), in_reach, STEP)
		d += STEP
	return {
		"total": route.total,
		"fire": fire,
		"edge": fire_edge,
		"walk": walk,
		"cov": cov,
		"expo": expo,
	}


func _med(a: Array[float]) -> String:
	return (
		"min %.1f p10 %.1f med %.1f p90 %.1f max %.1f"
		% [
			STATS.minimum(a),
			STATS.percentile(a, 10),
			STATS.median(a),
			STATS.percentile(a, 90),
			STATS.percentile(a, 100)
		]
	)


## Seconds of a distance for a foe, with `scale` applied to its speed.
func _times(dists: Array, foe: String, scale: float) -> Array[float]:
	var speed := STATS.scaled_speed(FOES.DEFS[foe]["speed"], scale)
	var out: Array[float] = []
	for v in dists:
		out.append(v / speed)
	return out


func _verdict(ratio_values: Array[float]) -> String:
	return (
		"median %.3f min %.3f gate %s"
		% [
			STATS.median(ratio_values),
			STATS.minimum(ratio_values),
			"PASS" if STATS.gate_passes(ratio_values) else "FAIL"
		]
	)


func _init() -> void:
	var lens: Array[int] = []
	var hist := {}
	var tmpl := {}
	var shapes := {}
	var total_ms := 0.0
	var slowest := 0.0
	var fails := 0
	var stitch_fail := 0
	var under100 := 0
	var per_region: Array = [[], [], [], [], [], []]
	var socket_counts: Array[float] = []
	# Per layout lane: the distances of each seed, and per region the cells walked, covered and
	# tower-cells.
	var lane_total: Array = [[], []]
	var lane_fire: Array = [[], []]
	var lane_edge: Array = [[], []]
	var lane_walk: Array = [[], []]
	var lane_cov: Array = [[], []]
	var lane_expo: Array = [[], []]
	var lane_min_fire: Array[float] = []
	var n := 300
	var first := 1
	var scale := 1.0
	var width: float = ROAD.ROAD_WIDTH_CELLS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
		if arg.begins_with("--from="):
			first = int(arg.trim_prefix("--from="))
		if arg.begins_with("--width="):
			width = float(arg.trim_prefix("--width="))
		if arg.begins_with("--speed="):
			scale = float(arg.trim_prefix("--speed="))
	for seed in range(first, first + n):
		var t := Time.get_ticks_usec()
		var layout := ValleyLayout.generate(
			seed, ValleyLayout.LAYOUT.COLS, ValleyLayout.LAYOUT.ROWS
		)
		var ms := float(Time.get_ticks_usec() - t) / 1000.0
		total_ms += ms
		slowest = maxf(slowest, ms)
		if layout == null:
			fails += 1
			continue
		var rects: Array[Rect2i] = []
		rects.resize(layout.slots.size())
		for slot in layout.slots:
			rects[slot.id] = slot.rect
		var map := ValleyStitcher.build(
			seed,
			ValleyLayout.LAYOUT.COLS,
			ValleyLayout.LAYOUT.ROWS,
			ValleyLayout.sections(),
			layout,
			true
		)
		if map == null:
			stitch_fail += 1
		if map != null:
			socket_counts.append(float(map.sockets.size()))
			var worst := 1.0e30
			var lanes := _lanes(map)
			for k in mini(lanes.size(), 2):
				var lane := _stats(map, width, lanes[k], rects)
				lane_total[k].append(lane["total"])
				lane_fire[k].append(lane["fire"])
				lane_edge[k].append(lane["edge"])
				lane_walk[k].append(lane["walk"])
				lane_cov[k].append(lane["cov"])
				lane_expo[k].append(lane["expo"])
				worst = minf(worst, lane["fire"])
			lane_min_fire.append(worst)
		var all: Array[Vector2i] = []
		for slot in layout.slots:
			var c := RoadSpline.build(slot.spine).cells
			per_region[slot.id].append(c.size())
			all.append_array(c)
		lens.append(all.size())
		if all.size() < 100:
			under100 += 1
		var b: int = (all.size() / 10) * 10
		hist[b] = hist.get(b, 0) + 1
		var parts: Array[String] = []
		for s in layout.route_segments:
			parts.append(str(s))
		var key := ",".join(parts)
		tmpl[key] = tmpl.get(key, 0) + 1
		var sk := ""
		var last := Vector2i(-1, -1)
		for cell in all:
			var q := Vector2i(cell.x / 4, cell.y / 4)
			if q != last:
				sk += "%d.%d;" % [q.x, q.y]
				last = q
		shapes[sk] = true
	lens.sort()
	print("seeds ", n, " from ", first, " fails ", fails, " stitch_fail ", stitch_fail)
	if lens.size() > 0:
		print(
			"len min/median/max ", lens[0], "/", lens[lens.size() / 2], "/", lens[lens.size() - 1]
		)
	print("under100 ", under100)
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("  ", k, ": ", hist[k])
	print("templates ", tmpl.size())
	var tkeys := tmpl.keys()
	tkeys.sort()
	for k in tkeys:
		print("  ", tmpl[k], " ", k)
	print("distinct shapes (4-cell buckets) ", shapes.size())
	print("time mean ms %.1f slowest %.1f" % [total_ms / n, slowest])
	for r in 6:
		var a: Array = per_region[r]
		a.sort()
		if a.size() > 0:
			print("region ", r, " min/med/max ", a[0], "/", a[a.size() / 2], "/", a[a.size() - 1])
	print("band width ", width, " half ", BAND.half_band(width), " (cells)")
	print("speed scale ", scale, " (layout only; strip valley at 1)")
	var no_rects: Array[Rect2i] = []
	var strip_total: Array[float] = []
	var strip_fire: Array[float] = []
	var strip_edge: Array[float] = []
	var strip_cells: Array[float] = []
	for seed in range(first, first + n):
		var m := MapGen.generate_valley(seed)
		if m == null:
			continue
		var st := _stats(m, width, 0, no_rects)
		strip_total.append(st["total"])
		strip_fire.append(st["fire"])
		strip_edge.append(st["edge"])
		strip_cells.append(float(m.path.size()))
	print("STRIP path cells ", _med(strip_cells))
	print("LAYOUT sockets ", _med(socket_counts))
	for foe in MEASURED_FOES:
		print("== ", foe, " (speed ", FOES.DEFS[foe]["speed"], " x ", scale, ")")
		print("STRIP walk s ", _med(_times(strip_total, foe, 1.0)))
		print("STRIP fire s centre line ", _med(_times(strip_fire, foe, 1.0)))
		print("STRIP fire s band edge ", _med(_times(strip_edge, foe, 1.0)))
		var strip_med := STATS.median(_times(strip_fire, foe, 1.0))
		var strip_med_edge := STATS.median(_times(strip_edge, foe, 1.0))
		for k in 2:
			if lane_total[k].is_empty():
				continue
			var fire_s := _times(lane_fire[k], foe, scale)
			var edge_s := _times(lane_edge[k], foe, scale)
			print("LAYOUT ", LANE_NAMES[k], " walk s ", _med(_times(lane_total[k], foe, scale)))
			print("LAYOUT ", LANE_NAMES[k], " fire s centre line ", _med(fire_s))
			print("LAYOUT ", LANE_NAMES[k], " fire s band edge ", _med(edge_s))
			print(
				"RATIO ", LANE_NAMES[k], " centre line ", _verdict(STATS.ratios(fire_s, strip_med))
			)
			print(
				"RATIO ",
				LANE_NAMES[k],
				" band edge ",
				_verdict(STATS.ratios(edge_s, strip_med_edge))
			)
		print(
			"RATIO shorter lane per seed centre line ",
			_verdict(STATS.ratios(_times(lane_min_fire, foe, scale), strip_med))
		)
	# Coverage and socket-seconds per region, for the Scrap Goblin at the speed scale.
	var goblin: float = STATS.scaled_speed(FOES.DEFS["scrapGoblin"]["speed"], scale)
	for k in 2:
		if lane_walk[k].is_empty():
			continue
		for r in REGION_NAMES.size():
			var w: Array[float] = []
			var c: Array[float] = []
			var e: Array[float] = []
			var share: Array[float] = []
			for i in lane_walk[k].size():
				var walked: float = lane_walk[k][i][r] / goblin
				var covered: float = lane_cov[k][i][r] / goblin
				w.append(walked)
				c.append(covered)
				e.append(lane_expo[k][i][r] / goblin)
				share.append(STATS.coverage(walked, covered))
			print(
				"COVERAGE ",
				LANE_NAMES[k],
				" ",
				REGION_NAMES[r],
				(
					" walk s %.1f covered s %.1f socket-s %.1f coverage %.2f"
					% [STATS.median(w), STATS.median(c), STATS.median(e), STATS.median(share)]
				)
			)
	quit()
