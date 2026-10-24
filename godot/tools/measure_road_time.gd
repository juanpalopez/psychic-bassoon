extends SceneTree

const FOES := preload("res://content/foes.gd")
const TOWERS := preload("res://content/towers.gd")
const ROAD := preload("res://content/valley/road_rules.gd")
const BAND := preload("res://tools/road_band_reach.gd")


## Returns (walk seconds, fire seconds measured to the centre line, fire seconds measured to the
## band's edge at `width`). Only the walk comes from the route; the two fire times differ by reach.
func _stats(map: GameMap, width: float) -> Vector3:
	var route: Route = null
	if map.route_curves.is_empty():
		route = Route.build_curved(map.routes[0])
	else:
		route = Route.build_from_curve(map.routes[0], map.route_curves[0])
	var speed: float = FOES.DEFS["scrapGoblin"]["speed"]
	var base: float = TOWERS.DEFS["spoolGuard"]["range"][0]
	var centres: Array[Vector3] = []
	for a in map.sockets:
		var c := map.socket_centre(a)
		centres.append(Vector3(c.x, c.y, base * map.range_multiplier(a)))
	var fire := 0.0
	var fire_edge := 0.0
	var d := 0.0
	var k := 1
	while d < route.total:
		while k < route.cumulative.size() - 1 and route.cumulative[k] < d:
			k += 1
		var seg := route.cumulative[k] - route.cumulative[k - 1]
		var t := 0.0 if seg <= 0.0 else (d - route.cumulative[k - 1]) / seg
		var x := route.xs[k - 1] + (route.xs[k] - route.xs[k - 1]) * t
		var y := route.ys[k - 1] + (route.ys[k] - route.ys[k - 1]) * t
		var hit := false
		var hit_edge := false
		for c in centres:
			var d2 := (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y)
			if not hit and d2 <= c.z * c.z:
				hit = true
			var edge := BAND.edge_reach(c.z, width)
			if not hit_edge and d2 <= edge * edge:
				hit_edge = true
			if hit and hit_edge:
				break
		if hit:
			fire += 0.1
		if hit_edge:
			fire_edge += 0.1
		d += 0.1
	return Vector3(route.total / speed, fire / speed, fire_edge / speed)


func _med(a: Array[float]) -> String:
	a.sort()
	return (
		"min %.1f p10 %.1f med %.1f p90 %.1f max %.1f"
		% [a[0], a[a.size() / 10], a[a.size() / 2], a[a.size() * 9 / 10], a[a.size() - 1]]
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
	var walk: Array[float] = []
	var fire_t: Array[float] = []
	var fire_e: Array[float] = []
	var per_region: Array = [[], [], [], [], [], []]
	var n := 300
	var width: float = ROAD.ROAD_WIDTH_CELLS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
		if arg.begins_with("--width="):
			width = float(arg.trim_prefix("--width="))
	for seed in range(1, n + 1):
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
			var st := _stats(map, width)
			walk.append(st.x)
			fire_t.append(st.y)
			fire_e.append(st.z)
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
	print("seeds ", n, " fails ", fails, " stitch_fail ", stitch_fail)
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
	for k in tmpl:
		print("  ", tmpl[k], " ", k)
	print("distinct shapes (4-cell buckets) ", shapes.size())
	print("time mean ms ", total_ms / n, " slowest ", slowest)
	for r in 6:
		var a: Array = per_region[r]
		a.sort()
		if a.size() > 0:
			print("region ", r, " min/med/max ", a[0], "/", a[a.size() / 2], "/", a[a.size() - 1])
	print("band width ", width, " half ", BAND.half_band(width), " (cells)")
	print("LAYOUT walk s ", _med(walk))
	print("LAYOUT fire s centre line ", _med(fire_t))
	print("LAYOUT fire s band edge ", _med(fire_e))
	var sw: Array[float] = []
	var sf: Array[float] = []
	var sfe: Array[float] = []
	var slen: Array[float] = []
	for seed in range(1, n + 1):
		var m := MapGen.generate_valley(seed)
		if m == null:
			continue
		var st2 := _stats(m, width)
		sw.append(st2.x)
		sf.append(st2.y)
		sfe.append(st2.z)
		slen.append(float(m.path.size()))
	print("STRIP path cells ", _med(slen))
	print("STRIP walk s ", _med(sw))
	print("STRIP fire s centre line ", _med(sf))
	print("STRIP fire s band edge ", _med(sfe))
	var sfm := sf.duplicate()
	sfm.sort()
	var sfem := sfe.duplicate()
	sfem.sort()
	var med: float = sfm[sfm.size() / 2]
	var med_edge: float = sfem[sfem.size() / 2]
	fire_t.sort()
	fire_e.sort()
	print(
		"LAYOUT/STRIP fire median ratio centre line ",
		fire_t[fire_t.size() / 2] / med,
		" min ratio ",
		fire_t[0] / med
	)
	print(
		"LAYOUT/STRIP fire median ratio band edge ",
		fire_e[fire_e.size() / 2] / med_edge,
		" min ratio ",
		fire_e[0] / med_edge
	)
	quit()
