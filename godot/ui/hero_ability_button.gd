## The Knight's Blade Whirl button: bottom-right, a thumb's reach from the edge, above the
## bottom row so it never covers the build bar. It shows the cooldown and asks for the cast;
## `main.gd` sends the command.
class_name HeroAbilityButton
extends Button

signal cast_requested

# what was last drawn, so a frame with nothing new builds no string and no state object
var _key := -1


func _init() -> void:
	theme = preload("res://ui/hud_theme.tres")
	theme_type_variation = &"ActionButton"
	custom_minimum_size = Vector2(HudLayout.ROW, HudLayout.ROW)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# the same rect the edge arrows keep clear of (HudLayout.ability_rect), as offsets from
	# the bottom-right corner
	var rect := HudLayout.ability_rect(Vector2.ZERO)
	offset_left = rect.position.x
	offset_top = rect.position.y
	offset_right = rect.end.x
	offset_bottom = rect.end.y
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	tooltip_text = "Blade Whirl: hurts every foe next to the Knight"
	visible = false
	pressed.connect(func() -> void: cast_requested.emit())


## Shows `hero`'s state; `covered` hides it while the build bar or the tower panel is open and
## `paused` turns it off.
func show_hero(hero: Hero, covered: bool, paused: bool = false) -> void:
	var key := HeroAbilityState.seconds_left(hero) * 16
	key += (1 if hero != null else 0) + (2 if hero != null and hero.alive else 0)
	key += (4 if covered else 0) + (8 if paused else 0)
	if key == _key:
		return
	_key = key
	var state := HeroAbilityState.of(hero, paused)
	visible = state.visible and not covered
	disabled = not state.enabled
	text = state.text
