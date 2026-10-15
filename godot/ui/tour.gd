## The first-time tour: a card of steps over a dimmed screen, with Back, Next and Skip.
## A step may outline one HUD control. It only shows words; the scene decides when to open
## it, pauses the game while it is open and remembers that it was seen.
class_name Tour
extends Control

signal finished

const GUIDE := preload("res://content/guide.gd")
const THEME := preload("res://ui/hud_theme.tres")
const CARD_HALF_WIDTH := 380.0
const CARD_HALF_HEIGHT := 170.0
## The card moves this far off the middle, away from the control a step outlines.
const CARD_SHIFT := 60.0
const BUTTON_SIZE := Vector2(160.0, 96.0)
const OUTLINE_GROW := 8.0

## Finds a HUD control by name; replaced in tests.
var target_resolver: Callable = _find_target

var _index := 0
var _target_name := ""
var _open := false
var _dim: Panel
var _highlight: Panel
var _card: PanelContainer
var _title := Label.new()
var _body := Label.new()
var _counter := Label.new()
var _back := Button.new()
var _next := Button.new()
var _skip := Button.new()


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = Panel.new()
	_dim.theme_type_variation = &"Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_highlight = Panel.new()
	_highlight.theme_type_variation = &"Highlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	add_child(_highlight)
	_build_card()
	get_viewport().size_changed.connect(_fit)
	_back.pressed.connect(back)
	_next.pressed.connect(next)
	_skip.pressed.connect(_finish)


func start() -> void:
	_open = true
	visible = true
	_fit()
	go_to(0)


func is_open() -> bool:
	return _open


## Shows step `index`, clamped to the steps.
func go_to(index: int) -> void:
	_index = clampi(index, 0, GUIDE.TOUR_STEPS.size() - 1)
	var step: Dictionary = GUIDE.TOUR_STEPS[_index]
	_title.text = step.title
	_body.text = step.text
	_counter.text = "Step %d of %d" % [_index + 1, GUIDE.TOUR_STEPS.size()]
	_back.disabled = _index == 0
	_next.text = "Done" if _index == GUIDE.TOUR_STEPS.size() - 1 else "Next"
	_outline(step.target)


func next() -> void:
	if _index >= GUIDE.TOUR_STEPS.size() - 1:
		_finish()
	else:
		go_to(_index + 1)


func back() -> void:
	go_to(_index - 1)


func step_index() -> int:
	return _index


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func counter_text() -> String:
	return _counter.text


func next_button() -> Button:
	return _next


func back_button() -> Button:
	return _back


func skip_button() -> Button:
	return _skip


## The card's rectangle, for tests.
func card_rect() -> Rect2:
	return Rect2(_card.global_position, _card.size)


func highlight_visible() -> bool:
	return _highlight.visible


func highlight_rect() -> Rect2:
	return Rect2(_highlight.global_position, _highlight.size)


## A Control under the HUD's CanvasLayer is not sized by anchors, so it takes the viewport's size.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _open:
		_outline(_target_name)


func _finish() -> void:
	_open = false
	visible = false
	finished.emit()


func _outline(target_name: String) -> void:
	_target_name = target_name
	var target: Control = target_resolver.call(target_name) if target_name != "" else null
	# a control that is hidden (the Start wave button while a wave comes out) is not outlined
	_highlight.visible = target != null and target.is_visible_in_tree()
	_shift_card(0.0)
	if not _highlight.visible:
		return
	var rect := Rect2(target.global_position, target.size).grow(OUTLINE_GROW)
	_highlight.global_position = rect.position
	_highlight.size = rect.size
	# a control in the top half sends the card down, one in the bottom half sends it up
	var in_top_half := rect.get_center().y < size.y / 2.0
	_shift_card(CARD_SHIFT if in_top_half else -CARD_SHIFT)


func _shift_card(by: float) -> void:
	_card.offset_top = -CARD_HALF_HEIGHT + by
	_card.offset_bottom = CARD_HALF_HEIGHT + by


func _find_target(target_name: String) -> Control:
	return get_parent().get_node_or_null(target_name) as Control


func _build_card() -> void:
	var card := PanelContainer.new()
	_card = card
	card.theme_type_variation = &"Card"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -CARD_HALF_WIDTH
	card.offset_right = CARD_HALF_WIDTH
	card.offset_top = -CARD_HALF_HEIGHT
	card.offset_bottom = CARD_HALF_HEIGHT
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var box := VBoxContainer.new()
	card.add_child(box)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = CARD_HALF_WIDTH * 2.0 - 40.0
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for label in [_title, _body, _counter]:
		box.add_child(label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_back.text = "Back"
	_skip.text = "Skip tour"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_back)
	row.add_child(_skip)
	row.add_child(spacer)
	row.add_child(_next)
	for button in [_back, _next, _skip]:
		button.custom_minimum_size = BUTTON_SIZE
