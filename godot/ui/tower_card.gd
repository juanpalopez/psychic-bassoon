## The card shown while a tower button is hovered or held: its name, role, stats, what it is
## good and weak against, and a tip. Words only; it never takes a tap.
class_name TowerCard
extends PanelContainer

const TOWERS := preload("res://content/towers.gd")
const GUIDE := preload("res://content/guide.gd")
const THEME := preload("res://ui/hud_theme.tres")

var _label := Label.new()
var _id := ""


func _ready() -> void:
	theme = THEME
	theme_type_variation = &"Card"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 400.0
	_label.theme_type_variation = &"CardText"
	add_child(_label)


func show_for(id: String) -> void:
	var def: Dictionary = TOWERS.DEFS[id]
	var words: Dictionary = GUIDE.TOWERS[id]
	_id = id
	_label.text = (
		"%s: %s\n%s\nGood: %s\nWeak: %s\nTip: %s"
		% [def.name, words.role, GuideText.stats(def), words.strong, words.weak, words.tip]
	)
	visible = true


func hide_card() -> void:
	_id = ""
	visible = false


func shown_id() -> String:
	return _id


func text() -> String:
	return _label.text
