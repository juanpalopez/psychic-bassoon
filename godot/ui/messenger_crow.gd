## The Messenger Crow: an origami crow that flies across the top of the screen with a
## scroll, holds it in the middle, and flies on. Messages queue; the 3D view is drawn only
## while the crow is out. Fed by `deliver`, moved by `advance` (called every frame).
class_name MessengerCrow
extends Control

enum Phase { IDLE, FLYING_IN, HOLDING, FLYING_OUT }

const ALERTS := preload("res://content/alerts.gd")
const MODEL := "res://assets/models/ui/messenger_crow.glb"
const THEME := preload("res://ui/hud_theme.tres")
const VIEW_SIZE := 240
const TOP_MARGIN := 16.0
const SCROLL_GAP := 8.0
const BOB_HEIGHT := 10.0
const BOB_SPEED := 6.0
## The model is about half a unit wide; the camera fills the square view with it.
const CAMERA_POSITION := Vector3(0.0, 0.3, 1.5)
const CAMERA_TARGET := Vector3(0.0, 0.3, 0.0)
const FACE_RIGHT_DEGREES := 90.0

var _phase := Phase.IDLE
var _elapsed := 0.0
var _text := ""
var _queue: Array[String] = []
var _clock := 0.0
var _has_model := false
var _container: SubViewportContainer
var _viewport: SubViewport
var _scroll: PanelContainer
var _label: Label


func _ready() -> void:
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_view()
	_build_scroll()
	_show_phase()


## Queues a message for the crow to carry; an empty one is ignored.
func deliver(message: String) -> void:
	if message == "":
		return
	if _phase == Phase.IDLE:
		_start(message)
		return
	_queue.append(message)
	while _queue.size() > ALERTS.CROW_MAX_QUEUE:
		_queue.pop_front()


## Moves the flight on by `delta` seconds, through as many phases as that covers.
func advance(delta: float) -> void:
	_clock += delta
	var left := delta
	while left >= 0.0 and _phase != Phase.IDLE:
		var remaining := _duration(_phase) - _elapsed
		if left < remaining:
			_elapsed += left
			break
		left -= remaining
		_elapsed = 0.0
		_next_phase()
	_show_phase()


func phase() -> Phase:
	return _phase


func text() -> String:
	return _text


func pending() -> int:
	return _queue.size()


## Where the crow is across the screen, 0 at the left edge, 0.5 in the middle, 1 at the
## right edge (and while it rests).
func position_fraction() -> float:
	match _phase:
		Phase.FLYING_IN:
			return 0.5 * _elapsed / ALERTS.CROW_FLY_SECONDS
		Phase.HOLDING:
			return 0.5
		Phase.FLYING_OUT:
			return 0.5 + 0.5 * _elapsed / ALERTS.CROW_FLY_SECONDS
	return 1.0


## Whether the 3D view is being drawn.
func is_rendering() -> bool:
	return _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func has_model() -> bool:
	return _has_model


func _process(delta: float) -> void:
	advance(delta)


func _start(message: String) -> void:
	_text = message
	_phase = Phase.FLYING_IN
	_elapsed = 0.0
	_show_phase()


func _next_phase() -> void:
	match _phase:
		Phase.FLYING_IN:
			_phase = Phase.HOLDING
		Phase.HOLDING:
			_phase = Phase.FLYING_OUT
		Phase.FLYING_OUT:
			if _queue.is_empty():
				_phase = Phase.IDLE
			else:
				_text = _queue.pop_front()
				_phase = Phase.FLYING_IN


func _duration(phase_now: Phase) -> float:
	return ALERTS.CROW_HOLD_SECONDS if phase_now == Phase.HOLDING else ALERTS.CROW_FLY_SECONDS


## Shows or hides the view to match the phase, and puts the crow and its scroll in place.
func _show_phase() -> void:
	var active := _phase != Phase.IDLE
	visible = active
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	)
	_label.text = _text
	if not active:
		return
	var across := size.x + float(VIEW_SIZE)
	var x := position_fraction() * across - float(VIEW_SIZE)
	var y := TOP_MARGIN + sin(_clock * BOB_SPEED) * BOB_HEIGHT
	_container.position = Vector2(x, y)
	_scroll.reset_size()
	_scroll.position = Vector2(
		x + float(VIEW_SIZE) / 2.0 - _scroll.size.x / 2.0, y + float(VIEW_SIZE) + SCROLL_GAP
	)


func _build_view() -> void:
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.custom_minimum_size = Vector2(VIEW_SIZE, VIEW_SIZE)
	_container.size = Vector2(VIEW_SIZE, VIEW_SIZE)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_container.add_child(_viewport)
	var camera := Camera3D.new()
	_viewport.add_child(camera)
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)
	var light := DirectionalLight3D.new()
	_viewport.add_child(light)
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	var packed := ModelLoader.scene(MODEL)
	if packed != null:
		var crow := packed.instantiate() as Node3D
		crow.rotation_degrees.y = FACE_RIGHT_DEGREES
		_viewport.add_child(crow)
		_has_model = true


func _build_scroll() -> void:
	_scroll = PanelContainer.new()
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)
	_label = Label.new()
	_scroll.add_child(_label)
