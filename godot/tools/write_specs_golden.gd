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
	var mortar := FileAccess.open(SpecScenario.MORTAR_GOLDEN_PATH, FileAccess.WRITE)
	if mortar == null:
		push_error("cannot write %s" % SpecScenario.MORTAR_GOLDEN_PATH)
		quit(1)
		return
	var shells := {
		"glitterCannon": SpecScenario.play_mortar("glitterCannon"),
		"stickyGlueMortar": SpecScenario.play_mortar("stickyGlueMortar"),
	}
	mortar.store_string(JSON.stringify(shells, "\t", true) + "\n")
	mortar.close()
	print("wrote %s" % SpecScenario.MORTAR_GOLDEN_PATH)
	var aviary := FileAccess.open(SpecScenario.AVIARY_GOLDEN_PATH, FileAccess.WRITE)
	if aviary == null:
		push_error("cannot write %s" % SpecScenario.AVIARY_GOLDEN_PATH)
		quit(1)
		return
	aviary.store_string(JSON.stringify(SpecScenario.play_aviary(), "\t", true) + "\n")
	aviary.close()
	print("wrote %s" % SpecScenario.AVIARY_GOLDEN_PATH)
	var guard := FileAccess.open(SpecScenario.GUARD_GOLDEN_PATH, FileAccess.WRITE)
	if guard == null:
		push_error("cannot write %s" % SpecScenario.GUARD_GOLDEN_PATH)
		quit(1)
		return
	var tents := {
		"cardboardKnights": SpecScenario.play_guard("cardboardKnights"),
		"scissorRogues": SpecScenario.play_guard("scissorRogues"),
	}
	guard.store_string(JSON.stringify(tents, "\t", true) + "\n")
	guard.close()
	print("wrote %s" % SpecScenario.GUARD_GOLDEN_PATH)
	quit()
