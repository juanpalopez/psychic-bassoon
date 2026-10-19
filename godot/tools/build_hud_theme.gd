## Writes `ui/hud_theme.tres` from the papercraft design tokens (the kit artboard of the
## Claude Design canvas for the HUD). Edit the tokens here and rerun:
## `godot --headless --path godot --script tools/build_hud_theme.gd`
## The HUD reads only the saved Theme; nothing in the game runs this script.
extends SceneTree

const OUT := "res://ui/hud_theme.tres"
const DISPLAY_FONT := "res://assets/fonts/BricolageGrotesque.ttf"
const HAND_FONT := "res://assets/fonts/PatrickHand-Regular.ttf"

# paper
const CARDSTOCK := Color("#F3E9D2")
const NOTE := Color("#FBF6EA")
const RECEIPT := Color("#FBF7EE")
const CARD_EDGE := Color("#D8C7A3")
const NOTE_EDGE := Color("#DDCDAE")
const INK := Color("#2A1F17")
const INK_SOFT := Color("#5C4632")
# craft desk
const KRAFT := Color("#C99A62")
const KRAFT_EDGE := Color("#A57A48")
# signals
const ACTION := Color("#2E5E9E")
const ACTION_EDGE := Color("#1F416F")
const ACTION_TEXT := Color("#F6EFDF")
const GOLD := Color("#E3A82B")
const SHORT := Color("#7E1C10")
const SHADOW := Color(0.08, 0.05, 0.02, 0.45)
const DIM := Color(0.11, 0.07, 0.04, 0.6)

# the paper stack: an edge drawn inside the bottom, then a hard shadow under it
const EDGE := 4
const LIFT := 4
const RADIUS := 8
const TAG_RADIUS := 6


func _init() -> void:
	var theme := Theme.new()
	var display := load(DISPLAY_FONT) as FontFile
	var hand := load(HAND_FONT) as FontFile
	theme.default_font = _weight(display, 700)
	theme.default_font_size = 26

	_buttons(theme)
	_labels(theme, display, hand)
	_panels(theme)
	_tokens(theme, display)

	var error := ResourceSaver.save(theme, OUT)
	print("saved %s: %s" % [OUT, error_string(error)])
	quit(error)


func _weight(base: FontFile, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): weight
	}
	return font


func _box(
	fill: Color,
	edge: Color,
	edge_width: int,
	lift: int,
	radius: int,
	margin := Vector4(16, 8, 16, 8)
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_bottom = edge_width
	box.set_corner_radius_all(radius)
	if lift > 0:
		box.shadow_color = SHADOW
		box.shadow_size = 1
		box.shadow_offset = Vector2(0, lift)
	box.content_margin_left = margin.x
	box.content_margin_top = margin.y
	box.content_margin_right = margin.z
	box.content_margin_bottom = margin.w
	box.anti_aliasing = true
	return box


## A pressed piece of paper sinks: a thinner edge, a shorter shadow and its content lower.
func _sunk(box: StyleBoxFlat) -> StyleBoxFlat:
	var sunk := box.duplicate() as StyleBoxFlat
	sunk.border_width_bottom = 1
	sunk.shadow_offset = Vector2(0, 1)
	sunk.content_margin_top += 3
	sunk.content_margin_bottom -= 3
	return sunk


func _buttons(theme: Theme) -> void:
	var normal := _box(CARDSTOCK, CARD_EDGE, EDGE, LIFT, RADIUS)
	var hover := _box(NOTE, CARD_EDGE, EDGE, LIFT, RADIUS)
	var on := _box(ACTION, ACTION_EDGE, 2, 1, RADIUS)
	on.content_margin_top += 3
	on.content_margin_bottom -= 3
	var disabled := _box(Color(CARDSTOCK, 0.55), Color(CARD_EDGE, 0.55), EDGE, 0, RADIUS)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = ACTION
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(RADIUS + 3)
	focus.set_expand_margin_all(4.0)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", on)
	theme.set_stylebox("hover_pressed", "Button", on)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", ACTION_TEXT)
	theme.set_color("font_hover_pressed_color", "Button", ACTION_TEXT)
	theme.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	# white icons take the text's colour
	theme.set_color("icon_normal_color", "Button", INK)
	theme.set_color("icon_hover_color", "Button", INK)
	theme.set_color("icon_focus_color", "Button", INK)
	theme.set_color("icon_pressed_color", "Button", ACTION_TEXT)
	theme.set_color("icon_hover_pressed_color", "Button", ACTION_TEXT)
	theme.set_color("icon_disabled_color", "Button", Color(INK, 0.45))
	theme.set_constant("h_separation", "Button", 12)
	theme.set_constant("icon_max_width", "Button", 40)

	# the one action that moves the game on: blue cardstock
	theme.set_type_variation("ActionButton", "Button")
	var action := _box(ACTION, ACTION_EDGE, EDGE, LIFT, RADIUS, Vector4(22, 8, 26, 8))
	var action_hover := action.duplicate() as StyleBoxFlat
	action_hover.bg_color = ACTION.lightened(0.08)
	var action_off := _box(Color(ACTION, 0.5), Color(ACTION_EDGE, 0.5), EDGE, 0, RADIUS)
	action_off.content_margin_left = 22
	action_off.content_margin_right = 26
	theme.set_stylebox("normal", "ActionButton", action)
	theme.set_stylebox("hover", "ActionButton", action_hover)
	theme.set_stylebox("pressed", "ActionButton", _sunk(action))
	theme.set_stylebox("hover_pressed", "ActionButton", _sunk(action))
	theme.set_stylebox("disabled", "ActionButton", action_off)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(state, "ActionButton", ACTION_TEXT)
	theme.set_color("font_disabled_color", "ActionButton", Color(ACTION_TEXT, 0.7))
	for state in [
		"icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"
	]:
		theme.set_color(state, "ActionButton", ACTION_TEXT)
	theme.set_color("icon_disabled_color", "ActionButton", Color(ACTION_TEXT, 0.7))
	theme.set_font_size("font_size", "ActionButton", 28)

	# square icon buttons in the corners, with a small caption under the icon
	theme.set_type_variation("IconButton", "Button")
	theme.set_font_size("font_size", "IconButton", 18)
	theme.set_constant("h_separation", "IconButton", 2)
	# glyph and caption fit inside the 88 px square, so the square never grows past its row
	theme.set_constant("icon_max_width", "IconButton", 36)
	var square := _box(CARDSTOCK, CARD_EDGE, EDGE, LIFT, RADIUS, Vector4(4, 4, 4, 4))
	var square_hover := square.duplicate() as StyleBoxFlat
	square_hover.bg_color = NOTE
	var square_on := _box(ACTION, ACTION_EDGE, 2, 1, RADIUS, Vector4(4, 6, 4, 2))
	var square_off := _box(Color(CARDSTOCK, 0.55), Color(CARD_EDGE, 0.55), EDGE, 0, RADIUS)
	square_off.content_margin_top = 4
	square_off.content_margin_bottom = 4
	theme.set_stylebox("normal", "IconButton", square)
	theme.set_stylebox("hover", "IconButton", square_hover)
	theme.set_stylebox("pressed", "IconButton", square_on)
	theme.set_stylebox("hover_pressed", "IconButton", square_on)
	theme.set_stylebox("disabled", "IconButton", square_off)

	# the speed button: just the number, big
	theme.set_type_variation("SpeedButton", "Button")
	theme.set_font("font", "SpeedButton", _weight(load(DISPLAY_FONT) as FontFile, 800))
	theme.set_font_size("font_size", "SpeedButton", 34)


func _labels(theme: Theme, display: FontFile, hand: FontFile) -> void:
	theme.set_color("font_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 0)
	theme.set_constant("line_spacing", "Label", 0)

	theme.set_type_variation("ChipNumber", "Label")
	theme.set_font("font", "ChipNumber", _weight(display, 800))
	theme.set_font_size("font_size", "ChipNumber", 34)

	theme.set_type_variation("Caption", "Label")
	theme.set_font_size("font_size", "Caption", 18)
	theme.set_color("font_color", "Caption", INK_SOFT)

	theme.set_type_variation("Title", "Label")
	theme.set_font("font", "Title", _weight(display, 800))
	theme.set_font_size("font_size", "Title", 30)

	theme.set_type_variation("CardText", "Label")
	theme.set_font_size("font_size", "CardText", 21)

	theme.set_type_variation("Hand", "Label")
	theme.set_font("font", "Hand", hand)
	theme.set_font_size("font_size", "Hand", 30)

	# a short note on a strip of receipt paper, floating over the board
	theme.set_type_variation("Toast", "Label")
	theme.set_font("font", "Toast", hand)
	theme.set_font_size("font_size", "Toast", 30)
	theme.set_stylebox(
		"normal", "Toast", _box(RECEIPT, CARD_EDGE, 0, LIFT, 2, Vector4(18, 6, 18, 6))
	)


func _panels(theme: Theme) -> void:
	# notes and cards: lighter paper, taped down
	var note := _box(NOTE, NOTE_EDGE, 3, 6, 4, Vector4(22, 18, 22, 18))
	theme.set_stylebox("panel", "PanelContainer", note)

	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", note)

	theme.set_type_variation("Chip", "PanelContainer")
	theme.set_stylebox(
		"panel", "Chip", _box(CARDSTOCK, CARD_EDGE, 3, LIFT, TAG_RADIUS, Vector4(18, 6, 22, 6))
	)

	# the build tray: a strip of kraft paper
	theme.set_type_variation("Kraft", "PanelContainer")
	theme.set_stylebox(
		"panel", "Kraft", _box(KRAFT, KRAFT_EDGE, EDGE, LIFT + 2, 10, Vector4(14, 12, 14, 10))
	)

	theme.set_type_variation("Receipt", "PanelContainer")
	theme.set_stylebox(
		"panel", "Receipt", _box(RECEIPT, NOTE_EDGE, 0, LIFT, 2, Vector4(20, 8, 20, 8))
	)

	theme.set_type_variation("Dim", "Panel")
	var dim := StyleBoxFlat.new()
	dim.bg_color = DIM
	theme.set_stylebox("panel", "Dim", dim)

	theme.set_type_variation("Highlight", "Panel")
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = Color(GOLD, 0.12)
	highlight.border_color = GOLD
	highlight.set_border_width_all(6)
	highlight.set_corner_radius_all(14)
	theme.set_stylebox("panel", "Highlight", highlight)

	# a pencil line between the chip's numbers
	var pencil := StyleBoxLine.new()
	pencil.color = CARD_EDGE.darkened(0.15)
	pencil.thickness = 2
	pencil.vertical = true
	pencil.grow_begin = -10.0
	pencil.grow_end = -10.0
	theme.set_stylebox("separator", "VSeparator", pencil)
	theme.set_constant("separation", "VSeparator", 18)

	theme.set_constant("separation", "HBoxContainer", 12)
	theme.set_constant("separation", "VBoxContainer", 10)


## The build menu's tower tokens: the icon is the token, so the button itself is bare.
## Hover lifts the token; a tower the player cannot afford fades and its price turns red.
func _tokens(theme: Theme, display: FontFile) -> void:
	theme.set_type_variation("TowerToken", "Button")
	var rest := StyleBoxEmpty.new()
	rest.content_margin_top = 6
	rest.content_margin_bottom = 2
	var lifted := StyleBoxEmpty.new()
	lifted.content_margin_top = 0
	lifted.content_margin_bottom = 8
	for state in ["normal", "disabled", "focus"]:
		theme.set_stylebox(state, "TowerToken", rest)
	for state in ["hover", "pressed", "hover_pressed"]:
		theme.set_stylebox(state, "TowerToken", lifted)
	theme.set_font("font", "TowerToken", _weight(display, 800))
	theme.set_font_size("font_size", "TowerToken", 19)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(state, "TowerToken", INK)
	theme.set_color("font_hover_pressed_color", "TowerToken", INK)
	theme.set_color("font_disabled_color", "TowerToken", SHORT)
	for state in [
		"icon_normal_color",
		"icon_hover_color",
		"icon_focus_color",
		"icon_pressed_color",
		"icon_hover_pressed_color"
	]:
		theme.set_color(state, "TowerToken", Color.WHITE)
	theme.set_color("icon_disabled_color", "TowerToken", Color(1, 1, 1, 0.4))
	theme.set_constant("icon_max_width", "TowerToken", 88)
	theme.set_constant("h_separation", "TowerToken", 4)
	theme.set_constant("line_spacing", "TowerToken", -2)
