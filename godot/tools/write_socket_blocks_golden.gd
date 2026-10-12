## Writes `tests/goldens/socket_blocks.json`: the 2x2 socket anchors, their levels
## and the Heartstone's footprint on the landscape 22 by 16 board for a few
## seeds, written by the GDScript sim itself. Run it only for a reviewed balance
## change (a new socket rule or number), then commit the result:
##
##   godot --headless --path godot -s tools/write_socket_blocks_golden.gd
extends SceneTree

const RULES := preload("res://content/map_rules.gd")

const SEEDS: Array[int] = [1, 7, 42, 99, 2024, 7920, 104729, 4294967295]
const PATH := "res://tests/goldens/socket_blocks.json"


func _init() -> void:
	var out := []
	for map_seed in SEEDS:
		var map := MapGen.generate(
			map_seed, RULES.LANDSCAPE_COLS, RULES.LANDSCAPE_ROWS, false, RULES.SOCKET_FOOTPRINT
		)
		var anchors := []
		var levels := []
		for anchor in map.sockets:
			anchors.append([anchor.x, anchor.y])
			levels.append(map.elevation_at(anchor))
		(
			out
			. append(
				{
					"seed": map_seed,
					"sockets": anchors,
					"levels": levels,
					"heartstone": [map.heartstone.position.x, map.heartstone.position.y],
				}
			)
		)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(out) + "\n")
	file.close()
	print("wrote %s for %d seeds" % [PATH, SEEDS.size()])
	quit()
