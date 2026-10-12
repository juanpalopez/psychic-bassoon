## The objective is the Heartstone (GDD, 2026-10-12): no code or test still calls
## it the kingdom.
extends GutTest

const ROOTS: Array[String] = [
	"res://content", "res://sim", "res://render", "res://ui", "res://tests", "res://tools"
]


func test_the_game_state_has_heartstone_health() -> void:
	var game := Game.create(1)
	assert_eq(game.heartstone_health, 20)
	assert_false("kingdom_health" in game)


func test_the_start_value_is_in_content_under_the_new_name() -> void:
	var Rules := preload("res://content/game_rules.gd")
	assert_eq(Rules.START_HEARTSTONE_HEALTH, 20)


func test_the_top_bar_says_heartstone() -> void:
	var bar := TopBar.new()
	add_child_autofree(bar)
	bar.show_state(Game.create(1))
	assert_eq(bar.texts()[1], "Heartstone 20")


func test_no_script_or_scene_still_says_kingdom() -> void:
	# built from pieces so this file does not contain the word itself
	var old := "king" + "dom"
	var found: Array[String] = []
	for root in ROOTS:
		_scan(root, old, found)
	_scan_file("res://main.gd", old, found)
	_scan_file("res://main.tscn", old, found)
	assert_eq(found, [], "the old name")


func _scan(dir: String, old: String, found: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, old, found)
	for file in DirAccess.get_files_at(dir):
		if file == "test_heartstone_name.gd":
			continue
		if file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn"):
			_scan_file(dir + "/" + file, old, found)


func _scan_file(path: String, old: String, found: Array[String]) -> void:
	var text := FileAccess.get_file_as_string(path).to_lower()
	if text.contains(old):
		found.append(path)
