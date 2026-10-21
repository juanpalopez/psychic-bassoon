## Writes a stitched 2D valley as JSON, for drawing it as an image. Run:
##
##   godot --headless --path godot -s tools/dump_valley_json.gd -- --seed=42 --out=/tmp/valley.json
##
## Holds the board size, the region rects (road order), each region's spine curve points, the river
## curve and cells, the main route curve, the feeder route curve (if any), the socket anchors with
## their level and tag, the bridges, the hero bridges, the Heartstone rect and the spawn. Curve
## points are in cell units (x + 0.5 is the middle of cell x).
extends SceneTree


func _init() -> void:
	var seed := 1
	var out := "valley.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var layout := ValleyLayout.generate(seed, 32, 20)
	var map: GameMap = null
	if layout != null:
		map = ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), layout)
	if map == null:
		print("seed %d: no valley" % seed)
		quit(1)
		return
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(_dump(layout, map), "  "))
	file.close()
	print("wrote %s" % out)
	quit()


func _dump(layout: ValleyLayout, map: GameMap) -> Dictionary:
	var regions: Array = []
	for slot in layout.slots:
		(
			regions
			. append(
				{
					"id": slot.id,
					"rect": _rect(slot.rect),
					"entry": _cell(slot.entry),
					"exit": _cell(slot.exit),
					"spine": _curve(RoadSpline.build(slot.spine)),
				}
			)
		)
	var sockets: Array = []
	for anchor in map.sockets:
		var level: int = map.elevation[anchor.y][anchor.x]
		sockets.append(
			{"anchor": _cell(anchor), "level": level, "tag": "high" if level > 0 else "low"}
		)
	var bridges: Array = []
	for bridge in map.bridges:
		bridges.append({"cell": _cell(bridge.cell), "horizontal": bridge.horizontal})
	var routes: Array = []
	for curve in map.route_curves:
		routes.append(_curve(curve))
	var hero: Array = []
	for cell in map.hero_bridges:
		hero.append(_cell(cell))
	return {
		"seed": map.seed,
		"cols": map.cols,
		"rows": map.rows,
		"regions": regions,
		"river": _curve(layout.river),
		"river_cells": layout.river_cells.map(_cell),
		"main_route": routes[0] if not routes.is_empty() else {},
		"feeder_route": routes[1] if routes.size() > 1 else {},
		"feeder_length": map.feeder_length,
		"sockets": sockets,
		"bridges": bridges,
		"hero_bridges": hero,
		"heartstone": _rect(map.heartstone),
		"spawn": _cell(map.path[0]),
	}


func _curve(curve: RoadCurve) -> Dictionary:
	var xs: Array = []
	var ys: Array = []
	for index in curve.xs.size():
		xs.append(floor(curve.xs[index] * 1000.0 + 0.5) / 1000.0)
		ys.append(floor(curve.ys[index] * 1000.0 + 0.5) / 1000.0)
	return {"xs": xs, "ys": ys}


func _cell(cell: Vector2i) -> Array:
	return [cell.x, cell.y]


func _rect(rect: Rect2i) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
