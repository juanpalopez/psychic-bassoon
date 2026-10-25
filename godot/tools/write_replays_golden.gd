## Writes `tests/goldens/replays.json`: whole games played by the scripted bot
## (the commands it sent, a checkpoint every 20 seconds of play and the final state,
## with floats as bits), written by the GDScript sim itself. Run it only for a
## reviewed balance change (a new rule or number), then commit the result:
##
##   godot --headless --path godot -s tools/write_replays_golden.gd
extends SceneTree

## Seed, bot profile and waves on the layout valley, the game board since #458 (foes at half pace,
## the Knight's skills): two won runs (spoolOnly 5 and 8, the second by 6 Heartstone health), lost
## runs (mix 2, mortarHeavy 7, guardMix 7), a run stopped at the wave cap (prismHeavy) and each
## strategy. A game must end inside the bot's thirty minutes, which the half pace makes tight: the
## mix never clears wave 20 on seeds 1 to 12. guardMix 7 builds Guard Tents and a Mess Tent, so the
## barracks tick path is covered.
const GAMES := [
	[5, "spoolOnly", 20],
	[8, "spoolOnly", 20],
	[2, "mix", 20],
	[7, "mortarHeavy", 20],
	[3, "prismHeavy", 6],
	[7, "guardMix", 20],
]
const PATH := "res://tests/goldens/replays.json"


func _init() -> void:
	var out := []
	for game in GAMES:
		out.append(ReplayKit.record(game[0], game[1], game[2]))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(out, "\t", true) + "\n")
	file.close()
	for rec in out:
		print("seed %d %s: %s after %d ticks" % [rec.seed, rec.profile, rec.outcome, rec.ticks])
	print("wrote %s" % PATH)
	quit()
