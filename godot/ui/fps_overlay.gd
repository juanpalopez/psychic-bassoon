## A small line of numbers at the bottom of the screen for the phone check: frames per second,
## draw calls, foes and triangles, refreshed four times a second. It never takes a tap.
class_name FpsOverlay
extends Label

const THEME := preload("res://ui/hud_theme.tres")
## Seconds between two readings.
const INTERVAL := 0.25
const BOTTOM_MARGIN := 36.0

var _foes: Callable
var _since := 0.0


func _ready() -> void:
	theme = THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the overlay; `foes` returns how many foes are on the board.
func enable(foes: Callable) -> void:
	_foes = foes
	visible = true
	refresh()


func refresh() -> void:
	if not _foes.is_valid():
		return
	var info := RenderingServer
	var count: int = _foes.call()
	text = FpsText.format(
		int(Engine.get_frames_per_second()),
		int(info.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		count,
		int(info.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameFoes = %d" % count)
	var port := get_viewport_rect().size
	position = Vector2((port.x - size.x) / 2.0, port.y - BOTTOM_MARGIN - size.y)


func advance(delta: float) -> void:
	_since += delta
	if _since >= INTERVAL or not _foes.is_valid():
		_since = 0.0
		refresh()


func _process(delta: float) -> void:
	if visible:
		advance(delta)
