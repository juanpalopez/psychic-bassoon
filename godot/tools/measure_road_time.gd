extends SceneTree

const FOES := preload("res://content/foes.gd")
const TOWERS := preload("res://content/towers.gd")


func _stats(map: GameMap) -> Vector2:
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
	var d := 0.0
	var k := 1
	while d < route.total:
		while k < route.cumulative.size() - 1 and route.cumulative[k] < d:
			k += 1
		var seg := route.cumulative[k] - route.cumulative[k - 1]
		var t := 0.0 if seg <= 0.0 else (d - route.cumulative[k - 1]) / seg
		var x := route.xs[k - 1] + (route.xs[k] - route.xs[k - 1]) * t
		var y := route.ys[k - 1] + (route.ys[k] - route.ys[k - 1]) * t
		for c in centres:
			if (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y) <= c.z * c.z:
				fire += 0.1
				break
		d += 0.1
	return Vector2(route.total / speed, fire / speed)


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
	var per_region: Array = [[], [], [], [], [], []]
	var n := 300
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
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
			var st := _stats(map)
			walk.append(st.x)
			fire_t.append(st.y)
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
	print("LAYOUT walk s ", _med(walk))
	print("LAYOUT fire s ", _med(fire_t))
	var sw: Array[float] = []
	var sf: Array[float] = []
	var slen: Array[float] = []
	for seed in range(1, n + 1):
		var m := MapGen.generate_valley(seed)
		if m == null:
			continue
		var st2 := _stats(m)
		sw.append(st2.x)
		sf.append(st2.y)
		slen.append(float(m.path.size()))
	print("STRIP path cells ", _med(slen))
	print("STRIP walk s ", _med(sw))
	print("STRIP fire s ", _med(sf))
	var sfm := sf.duplicate()
	sfm.sort()
	var med: float = sfm[sfm.size() / 2]
	var lo := 0
	fire_t.sort()
	print(
		"LAYOUT/STRIP fire median ratio ",
		fire_t[fire_t.size() / 2] / med,
		" min ratio ",
		fire_t[0] / med
	)
	quit()
