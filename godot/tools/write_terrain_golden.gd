## Writes `tests/goldens/terrain.json`: the valley terrain layer (heights, regions, river and
## bridges) for the seeds in `TerrainKit.SEEDS`, written by the GDScript sim itself. Run it
## only for a reviewed change to the terrain rules or numbers, then commit the result:
##
##   godot --headless --path godot -s tools/write_terrain_golden.gd
extends SceneTree

const PATH := "res://tests/goldens/terrain.json"


func _init() -> void:
	var out := TerrainKit.record()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(out, "\t") + "\n")
	file.close()
	print("wrote %s for %d seeds" % [PATH, out.size()])
	quit()
