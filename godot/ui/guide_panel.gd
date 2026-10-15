## The tower guide: a scrolling list with one entry per tower (name and cost line, stats,
## role, what it is good against, what it is bad at, a tip) and a Close button, on a card
## over a dimmed screen that also catches taps meant for the game.
class_name GuidePanel
extends Control

signal closed

const TOWERS := preload("res://content/towers.gd")
const GUIDE := preload("res://content/guide.gd")
const THEME := preload("res://ui/hud_theme.tres")
const HALF_WIDTH := 500.0
const LIST_HEIGHT := 420.0
const CLOSE_SIZE := Vector2(200.0, 96.0)

var _entries: Array[Label] = []
var _close := Button.new()
var _card: PanelContainer


func _ready() -> void:
	theme = THEME
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := Panel.new()
	dim.theme_type_variation = &"Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	get_viewport().size_changed.connect(_fit)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"Card"
	add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	var title := Label.new()
	title.text = "Tower guide"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(HALF_WIDTH * 2.0 - 40.0, LIST_HEIGHT)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for id in TOWERS.TOWER_IDS:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = HALF_WIDTH * 2.0 - 80.0
		label.text = _entry(id)
		list.add_child(label)
		_entries.append(label)
	_close.text = "Close"
	_close.custom_minimum_size = CLOSE_SIZE
	_close.pressed.connect(
		func() -> void:
			visible = false
			closed.emit()
	)
	box.add_child(_close)


func open() -> void:
	visible = true
	_fit()


## Covers the viewport (anchors do not size a Control under the HUD's CanvasLayer) and puts
## the card in its middle.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_card.reset_size()
	_card.position = (size - _card.size) / 2.0


func is_open() -> bool:
	return visible


func entry_count() -> int:
	return _entries.size()


func entry_text(index: int) -> String:
	return _entries[index].text


func close_button() -> Button:
	return _close


func _entry(id: String) -> String:
	var def: Dictionary = TOWERS.DEFS[id]
	var words: Dictionary = GUIDE.TOWERS[id]
	return (
		"%s: %s\n%s\nGood: %s\nWeak: %s\nTip: %s\n"
		% [def.name, words.role, GuideText.stats(def), words.strong, words.weak, words.tip]
	)


## The card, for tests.
func card() -> Control:
	return _card
