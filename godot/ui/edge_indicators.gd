## Arrows on the screen's edge for what the camera does not show: foes close to the Heartstone
## and the hero. It only reads the game and the camera and never takes a tap.
class_name EdgeIndicators
extends Control

const RULES := preload("res://content/indicators.gd")

## With reduced motion the arrows hold still instead of pulsing. On until the in-game Reduce
## motion setting (#319) exists to say otherwise, so the pulse is gated until then.
var reduced_motion := true:
	set(value):
		reduced_motion = value
		set_process(not value)

var _game: GameState
var _camera: Camera3D
var _clock := 0.0
var _near: Array[Foe] = []
var _left := PackedFloat64Array()


func _ready() -> void:
	theme = preload("res://ui/hud_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(not reduced_motion)


## Reads the game and the camera each frame to place the arrows.
func show_state(game: GameState, camera: Camera3D) -> void:
	_game = game
	_camera = camera
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta


## The share of its size an arrow is drawn at: 1 held still, swinging with the pulse otherwise.
func pulse() -> float:
	if reduced_motion:
		return 1.0
	return 1.0 + RULES.PULSE_SHARE * sin(_clock * TAU * RULES.PULSE_HERTZ)


## The part of the canvas the HUD rows leave free: arrows stay inside it.
func room(canvas: Vector2) -> Rect2:
	var top := HudLayout.TOP_CLEAR
	var bottom := canvas.y - HudLayout.BOTTOM_CLEAR
	var side := HudLayout.EDGE + RULES.ARROW_LENGTH
	return Rect2(side, top, canvas.x - 2.0 * side, bottom - top)


func _draw() -> void:
	if _game == null or _camera == null:
		return
	ArrowTargets.foes_near_heartstone(
		_game, RULES.FOE_NEAR_HEARTSTONE, RULES.MAX_FOE_ARROWS, _near, _left
	)
	for foe in _near:
		_arrow(foe.x, foe.y, &"foe")
	if _game.hero != null:
		_arrow(_game.hero.x, _game.hero.y, &"hero")


func _arrow(sim_x: float, sim_y: float, colour: StringName) -> void:
	var world := BoardSpace.point_to_world(sim_x, sim_y)
	var spot := EdgeArrows.spot(
		_camera.unproject_position(world), _camera.is_position_behind(world), size, room(size)
	)
	if spot == null:
		return
	var length := RULES.ARROW_LENGTH * pulse()
	var half := RULES.ARROW_WIDTH * pulse() / 2.0
	var turn := Transform2D(spot.angle, spot.position)
	var tip := turn * Vector2.ZERO
	var points := PackedVector2Array(
		[tip, turn * Vector2(-length, -half), turn * Vector2(-length, half)]
	)
	draw_colored_polygon(points, get_theme_color(colour, &"Arrow"))
	points.append(tip)
	draw_polyline(points, get_theme_color(&"edge", &"Arrow"), RULES.ARROW_EDGE_WIDTH, true)
