## A small map of the whole board in the left margin, under the stats chip: the road, the
## sockets, the foes, the hero and where the camera looks. A tap or a drag on it asks for the
## camera to go there. It only reads the game.
class_name Minimap
extends Control

## The camera should look at this point of the ground (x and z, in world units).
signal jump_requested(world: Vector2)

const RULES := preload("res://content/indicators.gd")

## Where the camera looks now, in world units (the rig's pan), drawn as a ring.
var view_at := Vector2.ZERO

var _game: GameState
var _dragging := false
var _fitted := Vector2.ZERO
var _roads: Array[PackedVector2Array] = []
var _since := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)


func _ready() -> void:
	theme = preload("res://ui/hud_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows a new game: sizes the minimap to its board.
func bind(game: GameState) -> void:
	_game = game
	var fitted := MinimapMap.fit(game.map.cols, game.map.rows, RULES.MINIMAP_MAX)
	_fitted = fitted
	_roads.clear()
	for route in game.routes:
		var line := PackedVector2Array()
		for i in route.xs.size():
			line.append(_pixel(Vector2(route.xs[i], route.ys[i])))
		_roads.append(line)
	custom_minimum_size = fitted
	offset_left = HudLayout.EDGE
	offset_right = HudLayout.EDGE + fitted.x
	offset_top = HudLayout.TOP_CLEAR
	offset_bottom = HudLayout.TOP_CLEAR + fitted.y
	queue_redraw()


## Draws again with the game as it is now, at most `MINIMAP_REFRESH` apart.
func refresh(view: Vector2, delta: float) -> void:
	view_at = view
	_since += delta
	if _since >= RULES.MINIMAP_REFRESH:
		_since = 0.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
	elif not (event is InputEventMouseMotion and _dragging):
		return
	if not _dragging:
		return
	accept_event()
	var at: Vector2 = (event as InputEventMouse).position
	jump_requested.emit(MinimapMap.to_world(at, _game.map.cols, _game.map.rows, _fitted))


func _draw() -> void:
	if _game == null:
		return
	var map := _game.map
	draw_rect(Rect2(Vector2.ZERO, _fitted), get_theme_color(&"paper", &"Minimap"))
	var road := get_theme_color(&"road", &"Minimap")
	for line in _roads:
		draw_polyline(line, road, RULES.MINIMAP_ROAD_WIDTH, true)
	var block := Vector2(map.footprint, map.footprint) / Vector2(map.cols, map.rows) * _fitted
	for anchor in map.sockets:
		draw_rect(Rect2(_pixel(Vector2(anchor)), block), get_theme_color(&"socket", &"Minimap"))
	for foe in _game.foes:
		if foe.alive:
			_dot(Vector2(foe.x, foe.y), RULES.MINIMAP_FOE_DOT, &"foe")
	if _game.hero != null:
		_dot(Vector2(_game.hero.x, _game.hero.y), RULES.MINIMAP_HERO_DOT, &"hero")
	var seen := MinimapMap.to_pixel(
		view_at + Vector2(map.cols, map.rows) / 2.0, map.cols, map.rows, _fitted
	)
	var ring := get_theme_color(&"view", &"Minimap")
	var points := RULES.MINIMAP_RING_POINTS
	draw_arc(seen, RULES.MINIMAP_VIEW_RADIUS, 0.0, TAU, points, ring, RULES.MINIMAP_VIEW_WIDTH)


func _pixel(sim: Vector2) -> Vector2:
	return MinimapMap.to_pixel(sim, _game.map.cols, _game.map.rows, _fitted)


func _dot(sim: Vector2, radius: float, colour: StringName) -> void:
	draw_circle(_pixel(sim), radius, get_theme_color(colour, &"Minimap"))
