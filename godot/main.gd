## The greybox scene (Phase 5, step A1): the real map on flat tiles.
##
## Tap "Next seed" to look at another map; on the web, open the page with
## `?seed=42` to start on a given seed. It only reads the map: no game logic
## lives here, and render code never touches the sim's state.
extends Node3D

@onready var _board: Board = $Board
@onready var _info: Label = $Hud/Info
@onready var _next_seed: Button = $Hud/NextSeed


func _ready() -> void:
	var from_url := _seed_from_url()
	if from_url >= 0:
		_board.map_seed = from_url
	_next_seed.pressed.connect(func() -> void: _board.map_seed += 1)
	# the browser smoke test waits for this flag
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.scraplineReady = true")


func _process(_delta: float) -> void:
	_info.text = (
		"Seed %d  |  %d routes  |  Godot %s  |  %d fps"
		% [
			_board.map_seed,
			_board.map.routes.size(),
			Engine.get_version_info().string,
			Engine.get_frames_per_second(),
		]
	)


## The `seed` query parameter of the page, or -1 when there is none.
func _seed_from_url() -> int:
	if not OS.has_feature("web"):
		return -1
	var value: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed')")
	if value is String and (value as String).is_valid_int():
		return int(value)
	return -1
