## Writes `tests/goldens/sockets.json`: the sockets and their levels for a few
## seeds, written by the GDScript sim itself. Run it only for a reviewed
## balance change (a new socket rule or number), then commit the result:
##
##   godot --headless --path godot -s tools/write_sockets_golden.gd
extends SceneTree

const SEEDS: Array[int] = [1, 7, 42, 99, 2024, 7920, 104729, 4294967295]
const PATH := "res://tests/goldens/sockets.json"


func _init() -> void:
	var out := []
	for map_seed in SEEDS:
		var map := MapGen.generate(map_seed, 9, 13, true, 1)
		var cells := []
		var levels := []
		for cell in map.sockets:
			cells.append([cell.x, cell.y])
			levels.append(map.elevation_at(cell))
		out.append({"seed": map_seed, "sockets": cells, "levels": levels})
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(out) + "\n")
	file.close()
	print("wrote %s for %d seeds" % [PATH, SEEDS.size()])
	quit()
