## The Knight's Blade Whirl button: bottom-right, a thumb's reach from the edge, above the
## bottom row so it never covers the build bar. It shows the cooldown and asks for the cast;
## `main.gd` sends the command.
class_name HeroAbilityButton
extends Button

signal cast_requested


func _init() -> void:
	theme = preload("res://ui/hud_theme.tres")
	theme_type_variation = &"ActionButton"
	custom_minimum_size = Vector2(HudLayout.ROW, HudLayout.ROW)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -HudLayout.EDGE - HudLayout.ROW
	offset_right = -HudLayout.EDGE
	offset_bottom = -HudLayout.BOTTOM_CLEAR
	offset_top = offset_bottom - HudLayout.ROW
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	tooltip_text = "Blade Whirl: hurts every foe next to the Knight"
	visible = false
	pressed.connect(func() -> void: cast_requested.emit())


## Shows `hero`'s state; `covered` hides it while the build bar or the tower panel is open.
func show_hero(hero: Hero, covered: bool) -> void:
	var state := HeroAbilityState.of(hero)
	visible = state.visible and not covered
	disabled = not state.enabled
	text = state.text
