## The greybox scene (Phase 5, steps A1 to A3): the real map, building on it, and
## waves of foes walking it.
##
## It owns one game (`Game.create`), ticks it at 30 Hz through the clock, turns a
## tap into a board cell, and sends build commands with `Game.submit`. It only
## reads the game's state and its events; it never changes them directly.
##
## Tap "Next seed" to look at another map (a new game); on the web, open the
## page with `?seed=42` to start on a given seed.
extends Node3D

const EARLY_RULES := preload("res://content/game_rules.gd")
const MESSAGE_SECONDS := 2.0
const FREE_COLOUR := Color(0.2, 0.9, 0.9, 0.55)
const BLOCKED_COLOUR := Color(0.95, 0.3, 0.25, 0.55)
## Pixels of drag that one unit of a trackpad pan gesture stands for.
const PAN_GESTURE_PIXELS := 12.0

var _game: GameState
var _clock := Clock.new()
var _selected := BoardSpace.NO_CELL
var _message_left := 0.0
var _gestures := Gestures.new()
var _speed := GameSpeed.new()

@onready var _board: Board = $Board
@onready var _rig: CameraRig = $CameraRig
@onready var _camera: Camera3D = _rig.camera()
@onready var _highlight: CellHighlight = $Highlight
@onready var _towers: TowersView = $Towers
@onready var _foes: FoesView = $Foes
@onready var _shots: ShotsView = $Shots
@onready var _guards: GuardsView = $Guards
@onready var _launch: Button = $Hud/LaunchWave
@onready var _top_bar: TopBar = $Hud/TopBar
@onready var _speed_bar: SpeedBar = $Hud/SpeedBar
@onready var _game_over: GameOverPanel = $Hud/GameOver
@onready var _message: Label = $Hud/Message
@onready var _menu: BuildMenu = $Hud/BuildMenu
@onready var _panel: TowerPanel = $Hud/TowerPanel
@onready var _ring: RangeRing = $RangeRing
@onready var _next_seed: Button = $Hud/NextSeed


func _ready() -> void:
	var from_url: Variant = _seed_from_url()
	_start(from_url if from_url is int else _board.map_seed)
	_next_seed.pressed.connect(func() -> void: _start(_game.seed + 1))
	_menu.tower_chosen.connect(_on_tower_chosen)
	_speed_bar.speed_chosen.connect(_on_speed_chosen)
	_speed_bar.pause_toggled.connect(_on_pause_toggled)
	_game_over.play_again.connect(func() -> void: _start(_game.seed))
	_panel.upgrade_pressed.connect(_on_upgrade)
	_panel.sell_pressed.connect(_on_sell)
	_launch.pressed.connect(func() -> void: Game.submit(_game, Command.launch_wave()))
	_gestures.tapped.connect(_on_tap)
	_gestures.panned.connect(_rig.pan_by_pixels)
	_gestures.pinched.connect(func(factor: float, _centre: Vector2) -> void: _rig.zoom_by(factor))
	_gestures.ended.connect(_rig.release_pan)
	# the browser smoke test waits for this flag
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.scraplineReady = true")


func _process(delta: float) -> void:
	var ticks_speed := _speed.ticks_speed()
	if ticks_speed > 0:
		Frame.step(_game, _clock, delta, ticks_speed, Callable(), _after_tick)
	_towers.sync(_game.towers, _board.surface_height, _game.map.footprint)
	_foes.update(_game, _clock.accumulator / Game.TICK_SECONDS)
	_guards.update(_game)
	if ticks_speed > 0:
		_shots.update(delta)
	_shots.show_beams(_game, _board.surface_height)
	_update_launch_button()
	_menu.set_buttons(_game.buttons)
	_refresh_panel()
	_message_left = maxf(0.0, _message_left - delta)
	_message.visible = _message_left > 0.0
	_top_bar.show_state(_game)
	_speed_bar.show_speed(_speed)
	if _game.won:
		_game_over.show_won(_game.wave)
	elif _game.over:
		_game_over.show_for(_game.wave)
	else:
		_game_over.close()


## The first pointer is the mouse, or the first finger (Godot turns a touch into
## mouse events too, and the build menu's buttons rely on that); extra fingers
## arrive as touch events with an index of 1 or more. A drag pans, a pinch (or
## the wheel, or a trackpad pinch) zooms and tilts, and only a tap selects.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_rig.zoom_steps(1.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_rig.zoom_steps(-1.0)
		elif button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			_gestures.press(0, button.position)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_gestures.move(0, motion.position)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).index >= 1:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_gestures.press(touch.index, touch.position)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index >= 1:
		var drag := event as InputEventScreenDrag
		_gestures.move(drag.index, drag.position)
	elif event is InputEventMagnifyGesture:
		_rig.zoom_by((event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		# a two-finger trackpad swipe moves the scene; it springs back if it overshoots
		_rig.pan_by_pixels((event as InputEventPanGesture).delta * PAN_GESTURE_PIXELS)
		_rig.release_pan()


## A release is safe for the tracker to see even when a button took it (it only
## acts on a pointer it saw go down), so letting go over the menu cannot leave a
## finger stuck in the tracker.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_gestures.release(0, button.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index >= 1 and not touch.pressed:
			_gestures.release(touch.index, touch.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_gestures.cancel()


func _on_tap(position: Vector2) -> void:
	var cell := CellPicker.cell_at(_camera, position, _board.surface_height)
	select_cell(cell)
	if cell == BoardSpace.NO_CELL:
		_show_message("Tap a socket")


## The game being played (read it; change it only with commands).
func game() -> GameState:
	return _game


## The selected cell, or `BoardSpace.NO_CELL`.
func selected_cell() -> Vector2i:
	return _selected


## Selects a cell: highlights it and, for a free socket (any cell of its block),
## opens the build menu. A socket selects its anchor, the block's top-left cell.
## `BoardSpace.NO_CELL` clears the selection.
func select_cell(cell: Vector2i) -> void:
	_selected = cell
	_menu.close()
	_panel.close()
	_ring.hide_range()
	if cell == BoardSpace.NO_CELL:
		_highlight.hide_cell()
		return
	var height := _board.surface_height(cell)
	if _game.map.tiles[cell.y][cell.x] == GameMap.Tile.ROAD:
		_highlight.show_cell(cell, height, BLOCKED_COLOUR)
		_show_message("That is road: build on a socket")
		return
	var anchor := _game.map.socket_anchor_at(cell)
	if anchor == GameMap.NO_SOCKET:
		_highlight.show_cell(cell, height, BLOCKED_COLOUR)
		_show_message(RejectText.of(GameEvent.RejectReason.NOT_A_SOCKET))
		return
	# any cell of a socket block selects the block, by its anchor
	_selected = anchor
	var footprint := _game.map.footprint
	var tower := _tower_on(anchor)
	if tower != null:
		_highlight.show_block(anchor, footprint, height, FREE_COLOUR)
		_panel.show_tower(tower, _game.buttons, TowerInfo.effective_range(_game.map, tower))
		_show_ring(tower)
		return
	if _game.over or _game.won:
		var why := (
			GameEvent.RejectReason.GAME_WON if _game.won else GameEvent.RejectReason.GAME_OVER
		)
		_highlight.show_block(anchor, footprint, height, BLOCKED_COLOUR)
		_show_message(RejectText.of(why))
		return
	_highlight.show_block(anchor, footprint, height, FREE_COLOUR)
	_menu.open_for(anchor, _game.buttons)


## Starts a fresh game on a map seed.
func _start(map_seed: int) -> void:
	_board.map_seed = map_seed
	_game = Game.create(map_seed)
	_clock = Clock.new()
	_foes.reset()
	_guards.reset()
	select_cell(BoardSpace.NO_CELL)
	_game_over.close()
	_speed = GameSpeed.new()
	_towers.sync(_game.towers, _board.surface_height, _game.map.footprint)
	_update_launch_button()


func _tower_on(cell: Vector2i) -> Tower:
	for tower in _game.towers:
		if tower.col == cell.x and tower.row == cell.y:
			return tower
	return null


## Shows the range ring for a tower, at the top of its tile.
func _show_ring(tower: Tower) -> void:
	var cell := Vector2i(tower.col, tower.row)
	var at := BoardSpace.footprint_centre(cell, _game.map.footprint)
	at.y = _board.surface_height(cell)
	_ring.show_range(at, TowerInfo.effective_range(_game.map, tower))


## Keeps the panel and ring true after a tick: an upgrade grows the range, and a
## tower gone (sold) closes both.
func _refresh_panel() -> void:
	var open := _panel.tower()
	if open == null:
		return
	if not _game.towers.has(open):
		select_cell(BoardSpace.NO_CELL)
		return
	_panel.set_reach(TowerInfo.effective_range(_game.map, open))
	_panel.set_buttons(_game.buttons)
	_show_ring(open)


## Orders are queued for the next tick, so while paused they wait for the
## player to resume; say so instead of looking broken.
func _note_if_paused() -> void:
	if _speed.paused:
		_show_message("Paused: orders run when you resume")


func _on_upgrade(tower_id: int) -> void:
	_note_if_paused()
	Game.submit(_game, Command.upgrade(tower_id))


func _on_sell(tower_id: int) -> void:
	_note_if_paused()
	Game.submit(_game, Command.sell(tower_id))
	select_cell(BoardSpace.NO_CELL)


func _on_speed_chosen(value: int) -> void:
	_speed.choose(value)


func _on_pause_toggled() -> void:
	_speed.toggle_pause()


func _on_tower_chosen(tower: String) -> void:
	_note_if_paused()
	Game.submit(_game, Command.build(tower, _selected.x, _selected.y))
	select_cell(BoardSpace.NO_CELL)


## Reads what the tick reported: a refused command becomes a short message.
func _after_tick(game: GameState) -> void:
	for event in game.events:
		if event.kind == GameEvent.Kind.COMMAND_REJECTED:
			_show_message(RejectText.of(event.reason))
		elif event.kind == GameEvent.Kind.TOWER_FIRED:
			_draw_shot(game, event)


## Draws the shot a tower fired this tick, from the tower to where its target stood.
func _draw_shot(game: GameState, event: GameEvent) -> void:
	for tower in game.towers:
		if tower.id == event.tower_id:
			var surface := _board.surface_height(Vector2i(tower.col, tower.row))
			_shots.add_shot(
				ShotsView.muzzle(tower, surface, game.map.footprint),
				ShotsView.body_point(event.x, event.y),
				event.splash
			)
			return


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_SECONDS
	_message.visible = true


## The `seed` query parameter of the page as an int, or null when there is none
## (or it is not a whole number of at most 16 characters).
func _seed_from_url() -> Variant:
	if not OS.has_feature("web"):
		return null
	var value: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed')")
	if value is String and (value as String).length() <= 16 and (value as String).is_valid_int():
		return int(value)
	return null


## The launch button says what a press would do, and rests while it cannot.
func _update_launch_button() -> void:
	var next := _game.wave + 1
	if _game.won:
		_launch.text = "You won"
		_launch.disabled = true
	elif _game.over:
		_launch.text = "Game over"
		_launch.disabled = true
	elif not _game.spawners.is_empty():
		_launch.text = "Wave %d is coming..." % _game.wave
		_launch.disabled = true
	elif _game.wave >= EARLY_RULES.WIN_WAVE:
		_launch.text = "Final wave"
		_launch.disabled = true
	elif _game.running:
		var bonus: int = EARLY_RULES.EARLY_CALL_BASE + _game.wave * EARLY_RULES.EARLY_CALL_PER_WAVE
		_launch.text = "Call wave %d early (+%d)" % [next, bonus]
		_launch.disabled = false
	else:
		_launch.text = "Start wave %d" % next
		_launch.disabled = false
