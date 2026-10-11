## One Theme sets the HUD's look; scenes and scripts hold no colours or sizes.
extends GutTest

const THEME_PATH := "res://ui/hud_theme.tres"


func test_the_theme_sets_fonts_buttons_labels_and_panels() -> void:
	var theme := load(THEME_PATH) as Theme
	assert_not_null(theme)
	assert_gt(theme.default_font_size, 0)
	for state in ["normal", "hover", "pressed", "disabled"]:
		assert_true(theme.has_stylebox(state, "Button"), state)
	assert_true(theme.has_color("font_color", "Label"))
	assert_true(theme.has_color("font_color", "Button"))
	assert_true(theme.has_stylebox("panel", "PanelContainer"))


func test_every_hud_control_uses_the_theme() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(main)
	var theme := load(THEME_PATH) as Theme
	for child in main.get_node("Hud").get_children():
		if child is Control:
			assert_eq((child as Control).theme, theme, child.name)


func test_the_hud_scene_has_no_overrides() -> void:
	var text := FileAccess.get_file_as_string("res://main.tscn")
	assert_false(text.contains("theme_override"), "overrides in main.tscn")


func test_ui_scripts_hold_no_colours_or_font_sizes() -> void:
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://ui/" + file)
		assert_false(text.contains("add_theme_font_size_override"), file)
		assert_false(text.contains("add_theme_color_override"), file)
		assert_false(text.contains("Color("), file)
