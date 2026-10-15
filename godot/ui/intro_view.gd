## The intro's speech bubble: the step's words, Next where the player has nothing to do on
## the map, and Skip always. It never blocks the map: only the bubble itself takes taps.
class_name IntroView
extends Control

const THEME := preload("res://ui/hud_theme.tres")
const BUBBLE_POSITION := Vector2(16.0, 84.0)
const BUBBLE_WIDTH := 640.0
## The small bubble used while the player acts on the map.
const COMPACT_WIDTH := 440.0
## The card's side padding, which the label's width leaves out.
const LABEL_MARGIN := 32.0
const BUTTON_SIZE := Vector2(160.0, 96.0)
const OUTLINE_GROW := 8.0

## Finds a HUD control by name; replaced in tests.
var target_resolver: Callable = _find_target

var _flow: IntroFlow
var _shown_step := IntroFlow.Step.IDLE
var _highlight: Panel
var _bubble: PanelContainer
var _label := Label.new()
var _next := Button.new()
var _skip := Button.new()


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_highlight = Panel.new()
	_highlight.theme_type_variation = &"Highlight"
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	add_child(_highlight)
	_bubble = PanelContainer.new()
	_bubble.theme_type_variation = &"Card"
	_bubble.position = BUBBLE_POSITION
	_bubble.custom_minimum_size.x = BUBBLE_WIDTH
	add_child(_bubble)
	var box := VBoxContainer.new()
	_bubble.add_child(box)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = BUBBLE_WIDTH - LABEL_MARGIN
	box.add_child(_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_skip.text = "Skip intro"
	_next.text = "Next"
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_skip)
	row.add_child(spacer)
	row.add_child(_next)
	for button in [_next, _skip]:
		button.custom_minimum_size = BUTTON_SIZE
	_next.pressed.connect(func() -> void: _flow.notify(IntroFlow.Event.NEXT))
	_skip.pressed.connect(func() -> void: _flow.skip())
	get_viewport().size_changed.connect(_fit)


func bind(flow: IntroFlow) -> void:
	_flow = flow


## Shows the flow's step, or hides the bubble when the intro is not running.
func refresh() -> void:
	visible = _flow != null and _flow.is_active()
	if not visible:
		_highlight.visible = false
		_shown_step = IntroFlow.Step.IDLE
		return
	if _flow.step() == _shown_step:
		# the words and the layout hold; only an outlined control may have come or gone
		if _flow.target() != "":
			_outline(_flow.target())
		return
	_shown_step = _flow.step()
	_fit()
	_label.text = _flow.text()
	var width := COMPACT_WIDTH if _flow.compact() else BUBBLE_WIDTH
	_label.custom_minimum_size.x = width - LABEL_MARGIN
	_bubble.custom_minimum_size.x = width
	_next.visible = _flow.offers_next()
	_next.text = "Done" if _flow.step() == IntroFlow.Step.DONE else "Next"
	_outline(_flow.target())
	_bubble.reset_size()


## The speech bubble, for tests.
func bubble() -> Control:
	return _bubble


func bubble_text() -> String:
	return _label.text


func next_button() -> Button:
	return _next


func skip_button() -> Button:
	return _skip


func highlight_visible() -> bool:
	return _highlight.visible


## A Control under the HUD's CanvasLayer is not sized by anchors, so it takes the viewport's size.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _outline(target_name: String) -> void:
	var target: Control = target_resolver.call(target_name) if target_name != "" else null
	# a control that is hidden (the Start wave button while a wave comes out) is not outlined
	_highlight.visible = target != null and target.is_visible_in_tree()
	if not _highlight.visible:
		return
	var rect := Rect2(target.global_position, target.size).grow(OUTLINE_GROW)
	_highlight.global_position = rect.position
	_highlight.size = rect.size


func _find_target(target_name: String) -> Control:
	return get_parent().get_node_or_null(target_name) as Control
