## Writes `tests/goldens/specs.json`: the fixed tier 4 scenario (`SpecScenario`),
## written by the GDScript sim itself. Run it only for a reviewed change to specs,
## then commit the result:
##
##   godot --headless --path godot -s tools/write_specs_golden.gd
extends SceneTree


func _init() -> void:
	var file := FileAccess.open(SpecScenario.GOLDEN_PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % SpecScenario.GOLDEN_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(SpecScenario.play(), "\t", true) + "\n")
	file.close()
	print("wrote %s" % SpecScenario.GOLDEN_PATH)
	var prism := FileAccess.open(SpecScenario.PRISM_GOLDEN_PATH, FileAccess.WRITE)
	if prism == null:
		push_error("cannot write %s" % SpecScenario.PRISM_GOLDEN_PATH)
		quit(1)
		return
	var both := {
		"cryoOrigamiSpire": SpecScenario.play_prism("cryoOrigamiSpire"),
		"blotSingularity": SpecScenario.play_prism("blotSingularity"),
	}
	prism.store_string(JSON.stringify(both, "\t", true) + "\n")
	prism.close()
	print("wrote %s" % SpecScenario.PRISM_GOLDEN_PATH)
	quit()
