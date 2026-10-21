## Prints the 32 by 20 valley as text, one character per cell, to check a layout by eye. Run:
##
##   godot --headless --path godot -s tools/print_valley.gd -- --seed=42 [--layout]
##
## Without `--layout` it prints the map the game plays on; with it, the 2D layout (#407) stitched
## from its stand-in sections, with the region letters in road order: A Outer March, D Sunken
## Meadow, C Bluewater Crossing, B Broken Ridge, E Ancient Fold, F Heartkeep Approach.
## `~` river, `#` road, `S` socket block anchor, `>` spawn, `H` Heartstone, `f` feeder.
extends SceneTree

const LETTERS := "ADCBEF"


func _init() -> void:
	var seed := 1
	var layout := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg == "--layout":
			layout = true
	var plan: ValleyLayout = null
	var map: GameMap = null
	if layout:
		plan = ValleyLayout.generate(seed, 32, 20)
		map = ValleyStitcher.build(seed, 32, 20, ValleyLayout.sections(), plan)
	else:
		map = MapGen.game_map(seed)
	if map == null:
		print("seed %d: no valley" % seed)
		quit(1)
		return
	print("seed %d" % seed)
	for y in map.rows:
		var line := ""
		for x in map.cols:
			line += _glyph(Vector2i(x, y), map, plan)
		print(line)
	quit()


func _glyph(cell: Vector2i, map: GameMap, plan: ValleyLayout) -> String:
	var glyph := "."
	if plan != null:
		for slot in plan.slots:
			if slot.rect.has_point(cell):
				glyph = LETTERS[slot.id]
	var feeder: Array[Vector2i] = []
	if map.routes.size() > 1:
		feeder = map.routes[1].slice(0, map.feeder_length)
	if map.river.has(cell):
		glyph = "~"
	if feeder.has(cell):
		glyph = "f"
	if map.path.has(cell):
		glyph = "#"
	if map.sockets.has(cell):
		glyph = "S"
	if map.heartstone.has_point(cell):
		glyph = "H"
	if cell == map.path[0]:
		glyph = ">"
	return glyph
