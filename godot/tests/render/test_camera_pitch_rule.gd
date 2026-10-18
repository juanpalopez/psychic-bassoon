## The pitch range in the code is the one CLAUDE.md states (#313): they once disagreed.
extends GutTest

const RULES_FILE := "../CLAUDE.md"


func _rules() -> String:
	return FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://") + RULES_FILE)


func test_claude_md_states_the_pitch_range_the_camera_uses() -> void:
	var text := _rules()
	assert_false(text.is_empty(), "CLAUDE.md is readable from the project")
	var pattern := RegEx.create_from_string(
		"pitched (\\d+(?:\\.\\d+)?)° zoomed out and (\\d+(?:\\.\\d+)?)° zoomed in"
	)
	var found := pattern.search_all(text)
	assert_eq(found.size(), 1, "CLAUDE.md states the pitch range once")
	if found.size() != 1:
		return
	assert_eq(float(found[0].get_string(1)), CameraRig.MAX_PITCH, "zoomed out")
	assert_eq(float(found[0].get_string(2)), CameraRig.MIN_PITCH, "zoomed in")


func test_the_rig_pitches_through_that_range() -> void:
	assert_eq(CameraRig.pitch_for(0.0), CameraRig.MAX_PITCH)
	assert_eq(CameraRig.pitch_for(1.0), CameraRig.MIN_PITCH)
