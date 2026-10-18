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

## How far past the 44 pt threshold a flight aims, in canvas pixels (see `_fly_to_socket`).
const FLIGHT_AIM_MARGIN := 0.5
const EARLY_RULES := preload("res://content/game_rules.gd")
const MESSAGE_SECONDS := 2.0
## Said when even the closest zoom draws a socket under 44 pt (a very small window).
const TOO_SMALL_MESSAGE := "Make the window bigger to build here"
## Where the tower card sits: beside the build menu, this far from it and from the edges.
const CARD_MARGIN := 14.0
const MENU_ICON := preload("res://assets/icons/menu.svg")
const CLOSE_ICON := preload("res://assets/icons/close.svg")
const FREE_COLOUR := Color(0.2, 0.9, 0.9, 0.55)
const BLOCKED_COLOUR := Color(0.95, 0.3, 0.25, 0.55)
## Pixels of drag that one unit of a trackpad pan gesture stands for.
const PAN_GESTURE_PIXELS := 12.0

## Points per canvas pixel for the 44 pt rule; 0 reads them from the display. Tests set the
## phone's, because a headless run has no display.
var points_per_pixel := 0.0
## The render quality (a `RenderQuality.Level`); below 0 asks the platform. A test sets it
## before the scene enters the tree.
var render_quality: int = -1

var _game: GameState
var _clock := Clock.new()
var _selected := BoardSpace.NO_CELL
var _message_left := 0.0
var _gestures := Gestures.new()
var _fingers := TouchFingers.new()
var _speed := GameSpeed.new()
var _hold := HitHold.new()
var _audio := AudioPlayer.new()
var _crow := MessengerCrow.new()
var _flow := IntroFlow.new()
var _intro := IntroView.new()
var _glow := SocketGlow.new()
var _card := TowerCard.new()
var _glow_shown := false
## How many foes the phone check keeps walking (the `?stress=` page parameter), 0 for none.
var _stress_foes := 0
var _fps := FpsOverlay.new()
var _guide := GuidePanel.new()
var _auto := AutoWave.new()
var _progress := IntroProgress.default()
## The tilt-shift and the haze, fitted to the camera each time the view moves.
var _lens := DioramaLens.new()
# whether the game was paused by the player when an overlay opened over it
var _paused_before_overlay := false
# the socket a tap flew the camera to, selected when the camera arrives
var _fly_target := BoardSpace.NO_CELL
# the zoom last frame, to see the player zoom out past a selected socket
var _zoom_seen := 0.0

@onready var _world: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun
@onready var _board: Board = $Board
@onready var _rig: CameraRig = $CameraRig
@onready var _camera: Camera3D = _rig.camera()
@onready var _highlight: CellHighlight = $Highlight
@onready var _towers: TowersView = $Towers
@onready var _foes: FoesView = $Foes
@onready var _shots: ShotsView = $Shots
@onready var _guards: GuardsView = $Guards
@onready var _launch: Button = $Hud/LaunchWave
@onready var _auto_button: Button = $Hud/AutoWave
@onready var _top_bar: TopBar = $Hud/TopBar
@onready var _speed_bar: SpeedBar = $Hud/SpeedBar
@onready var _game_over: GameOverPanel = $Hud/GameOver
@onready var _message: Label = $Hud/Message
@onready var _menu: BuildMenu = $Hud/BuildMenu
@onready var _panel: TowerPanel = $Hud/TowerPanel
@onready var _ring: RangeRing = $RangeRing
@onready var _next_seed: Button = $Hud/NextSeed
@onready var _sound: Button = $Hud/Sound
@onready var _menu_button: Button = $Hud/MenuButton
@onready var _how_to_play: Button = $Hud/HowToPlay
@onready var _tower_guide: Button = $Hud/TowerGuide


func _ready() -> void:
	var level: int = RenderQuality.from_platform() if render_quality < 0 else render_quality
	RenderQuality.apply(level as RenderQuality.Level, _world.environment, _sun, _tilt_shift())
	_lens.shadow_cap = RenderQuality.shadow_cap(level as RenderQuality.Level)
	var from_url: Variant = _seed_from_url()
	_rig.flight_ended.connect(_on_flight_ended)
	_start(from_url if from_url is int else _board.map_seed)
	add_child(_audio)
	_menu_button.toggled.connect(
		func(on: bool) -> void:
			_menu_button.icon = CLOSE_ICON if on else MENU_ICON
			_next_seed.visible = on
			_sound.visible = on
			_how_to_play.visible = on
			_tower_guide.visible = on
	)
	_sound.toggled.connect(
		func(on: bool) -> void:
			_audio.set_muted(not on)
			_sound.text = "Sound on" if on else "Sound off"
	)
	$Hud.add_child(_crow)
	$Hud.add_child(_guide)
	$Hud.add_child(_intro)
	_intro.bind(_flow)
	_flow.finished.connect(_on_intro_finished)
	$Hud.add_child(_card)
	$Hud.add_child(_fps)
	_read_phone_check_params()
	add_child(_glow)
	_menu.info_requested.connect(_on_info_requested)
	_menu.info_cleared.connect(_card.hide_card)
	_guide.closed.connect(func() -> void: _pause_for_overlay(false))
	_how_to_play.pressed.connect(_start_intro)
	_tower_guide.pressed.connect(_open_guide)
	_next_seed.pressed.connect(func() -> void: _start(_game.seed + 1))
	_menu.tower_chosen.connect(_on_tower_chosen)
	_speed_bar.speed_chosen.connect(_on_speed_chosen)
	_speed_bar.pause_toggled.connect(_on_pause_toggled)
	_game_over.play_again.connect(func() -> void: _start(_game.seed))
	_panel.upgrade_pressed.connect(_on_upgrade)
	_panel.sell_pressed.connect(_on_sell)
	_panel.spec_pressed.connect(_on_spec)
	_panel.ability_pressed.connect(_on_ability)
	_launch.pressed.connect(
		func() -> void:
			# a tap during the Auto countdown starts the wave now, and only once
			_auto.launched_by_player()
			Game.submit(_game, Command.launch_wave())
	)
	_auto_button.toggled.connect(func(on: bool) -> void: _auto.enabled = on)
	_gestures.tapped.connect(_on_tap)
	_gestures.panned.connect(_rig.pan_by_pixels)
	_gestures.pinched.connect(
		func(factor: float, centre: Vector2) -> void: _rig.zoom_by(factor, centre)
	)
	_gestures.ended.connect(_rig.release_pan)
	# the browser smoke test waits for this flag
	# the phone check plays without the intro
	var tour_param := "0" if _stress_foes > 0 else _tour_param()
	if IntroProgress.wanted(_progress.seen(), tour_param, DisplayServer.get_name() == "headless"):
		_start_intro()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameReady = true")


func _process(delta: float) -> void:
	_lens.follow(_camera, _world.environment, _tilt_shift(), _sun)
	var ticks_speed := _speed.ticks_speed()
	# Auto start counts game time, so it holds while paused, runs faster at 2x and 3x, and
	# a slow frame counts no more than the clock lets the game run
	if _auto.advance(_game, minf(delta, EARLY_RULES.MAX_FRAME_SECONDS) * float(ticks_speed)):
		Game.submit(_game, Command.launch_wave())
	if ticks_speed > 0:
		Frame.step(_game, _clock, delta, ticks_speed, _before_tick, _after_tick)
	# shots and the hits they hold back age in game time, so at 2x and 3x they keep up
	var game_seconds := delta * float(ticks_speed)
	_hold.advance(game_seconds)
	for i in _hold.take_landed_kills():
		_audio.play_sfx(SoundMap.EVENT_SOUNDS[GameEvent.Kind.FOE_KILLED])
	_towers.sync(_game.towers, _board.surface_height, _game.map.footprint)
	_foes.update(_game, _clock.accumulator / Game.TICK_SECONDS, _hold)
	_guards.update(_game)
	if ticks_speed > 0:
		_shots.update(game_seconds)
	_shots.show_beams(_game, _board.surface_height)
	_audio.set_music(SoundMap.music_for(_game))
	_update_launch_button()
	_sync_intro()
	_menu.set_buttons(_game.buttons)
	_close_if_zoomed_out()
	if _menu.visible:
		# the camera may have panned or zoomed since the menu opened
		_place_menu()
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


func _tilt_shift() -> CameraAttributesPractical:
	return _world.camera_attributes as CameraAttributesPractical


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
	elif event is InputEventScreenTouch:
		# the first finger is read from the emulated mouse events above; only the
		# extra fingers come from touch events, whatever indexes the browser gave them
		var touch := event as InputEventScreenTouch
		var pointer := _fingers.press(touch.index) if touch.pressed else TouchFingers.MOUSE
		if touch.pressed and pointer != TouchFingers.MOUSE:
			_gestures.press(pointer, touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var pointer := _fingers.pointer_of(drag.index)
		if pointer != TouchFingers.MOUSE:
			_gestures.move(pointer, drag.position)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_rig.zoom_by(magnify.factor, magnify.position)
	elif event is InputEventPanGesture:
		# a two-finger trackpad swipe moves the scene; it springs back if it overshoots
		_rig.pan_by_pixels((event as InputEventPanGesture).delta * PAN_GESTURE_PIXELS)
		_rig.release_pan()


## A release is safe for the tracker to see even when a button took it (it only
## acts on a pointer it saw go down), so letting go over the menu cannot leave a
## finger stuck in the tracker.
func _input(event: InputEvent) -> void:
	# the first press of any kind (board or button) lets audio start: browsers block it before
	if (
		(event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	):
		_audio.unlock()
	elif (
		(event is InputEventMouseButton and not (event as InputEventMouseButton).pressed)
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed)
	):
		_audio.confirm_unlock()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_gestures.release(0, button.position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# every touch is seen here, even one a button takes, so the fingers stay counted
			_fingers.press(touch.index)
		else:
			var pointer := _fingers.release(touch.index)
			if pointer != TouchFingers.MOUSE:
				_gestures.release(pointer, touch.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_gestures.cancel()
		_fingers.reset()


## A tap picks a cell. A socket (or the tower on it) drawn under 44 pt, as at the overview,
## is not selected yet: the camera flies in to it first and selects it on arrival (#328).
func _on_tap(position: Vector2) -> void:
	_rig.cancel_flight()
	var cell := CellPicker.cell_at(_camera, position, _board.surface_height)
	if cell != BoardSpace.NO_CELL:
		var anchor := _game.map.socket_anchor_at(cell)
		if anchor != GameMap.NO_SOCKET and not socket_tappable(anchor):
			_fly_to_socket(anchor)
			return
	select_cell(cell)
	if cell == BoardSpace.NO_CELL:
		_show_message("Tap a socket")


## Whether a socket block is drawn big enough to build, upgrade or sell on: its narrowest
## width on screen is at least `TapZoom.MIN_POINTS`.
func socket_tappable(anchor: Vector2i) -> bool:
	return _rig.square_pixels(_socket_top(anchor), float(_game.map.footprint)) >= tap_pixels()


## The least width, in canvas pixels, that a tap target needs on this screen (44 pt).
func tap_pixels() -> float:
	if points_per_pixel > 0.0:
		return TapZoom.MIN_POINTS / points_per_pixel
	# the only display reads (a headless run has no window: 0, and then a pixel is a point);
	# #97 logs them on the iPhone
	return tap_pixels_for(
		get_viewport().get_visible_rect().size.y,
		float(DisplayServer.window_get_size().y),
		DisplayServer.screen_get_scale()
	)


## The least width, in canvas pixels, of a 44 pt tap target on a canvas `canvas_height` pixels
## tall, drawn in a window `window_pixels` tall on a screen of `screen_scale` pixels per point.
static func tap_pixels_for(
	canvas_height: float, window_pixels: float, screen_scale: float
) -> float:
	return TapZoom.MIN_POINTS / TapZoom.points_per_pixel(canvas_height, window_pixels, screen_scale)


## Flies the camera in to a socket until it is drawn at least 44 pt, then selects it.
func _fly_to_socket(anchor: Vector2i) -> void:
	select_cell(BoardSpace.NO_CELL)
	var top := _socket_top(anchor)
	var side := float(_game.map.footprint)
	# aim a hair past the threshold: the flight lands through 32-bit lerps, so a zoom found
	# exactly at 44 pt can land a few millionths of a pixel under it and fail the re-check
	var aim := tap_pixels() + FLIGHT_AIM_MARGIN
	_rig.fly_to(top, maxf(_rig.zoom, _rig.zoom_to_show(top, side, aim)))
	# set after `fly_to`, which ends any earlier flight (and drops its target)
	_fly_target = anchor


func _on_flight_ended(arrived: bool) -> void:
	var target := _fly_target
	_fly_target = BoardSpace.NO_CELL
	if not arrived or target == BoardSpace.NO_CELL:
		return
	# a window so small that even the closest zoom draws a socket under 44 pt builds nothing
	if socket_tappable(target):
		select_cell(target)
	else:
		_show_message(TOO_SMALL_MESSAGE)


## Building, upgrading and selling happen only where the socket is drawn at least 44 pt: when
## the player zooms out past that, the build menu or tower panel closes.
func _close_if_zoomed_out() -> void:
	var zoomed_out := _rig.zoom < _zoom_seen
	_zoom_seen = _rig.zoom
	if not zoomed_out or _selected == BoardSpace.NO_CELL:
		return
	if not (_menu.visible or _panel.tower() != null):
		return
	if not socket_tappable(_selected):
		select_cell(BoardSpace.NO_CELL)


## The middle of a socket block, at the top of its tile.
func _socket_top(anchor: Vector2i) -> Vector3:
	var top := BoardSpace.footprint_centre(anchor, _game.map.footprint)
	top.y = _board.surface_height(anchor)
	return top


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
	if OS.has_feature("web"):
		# the end-to-end test reads the selection the way a person sees it
		JavaScriptBridge.eval("window.gameSelected = '%d,%d'" % [cell.x, cell.y])
	_menu.close()
	_card.hide_card()
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
	# the build menu may open over the Menu's dropdown: tapping the board closes it
	_menu_button.button_pressed = false
	_menu.open_for(anchor, _game.buttons)
	_place_menu()
	# the intro moves on only when the build row really opened for a free socket
	_flow.notify(IntroFlow.Event.SOCKET_SELECTED)


## Starts a fresh game on a map seed.
func _start(map_seed: int) -> void:
	_crow.clear()
	_auto.cancel()
	_game = Game.create(map_seed)
	# the board draws the game's own map (the diorama is built from its snapshot)
	_board.show_map(_game.map, _game.routes)
	_clock = Clock.new()
	_foes.reset()
	_hold.reset()
	_guards.reset()
	select_cell(BoardSpace.NO_CELL)
	_game_over.close()
	_speed = GameSpeed.new()
	_speed.paused = _guide.is_open()
	# a new game has no pause of the player's to give back
	_paused_before_overlay = false
	if _flow.is_active():
		_flow.skip()
	_towers.sync(_game.towers, _board.surface_height, _game.map.footprint)
	_update_launch_button()
	# a run starts on the spawn side, at a zoom where its sockets can be tapped (#328)
	var spawn: Vector2i = _game.map.path[0]
	_rig.start_view(
		BoardSpace.cell_to_world(spawn.x, spawn.y), float(_game.map.footprint), tap_pixels()
	)
	_zoom_seen = _rig.zoom


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


func _on_spec(tower_id: int, spec_id: String) -> void:
	_note_if_paused()
	Game.submit(_game, Command.choose_spec(tower_id, spec_id))


func _on_ability(tower_id: int) -> void:
	_note_if_paused()
	Game.submit(_game, Command.activate(tower_id))


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


## The intro moves on when the player builds a tower, starts a wave or clears it.
func _tell_intro(event: GameEvent) -> void:
	if event.kind == GameEvent.Kind.TOWER_BUILT:
		_flow.notify(IntroFlow.Event.TOWER_BUILT)
	elif event.kind == GameEvent.Kind.WAVE_LAUNCHED:
		_flow.notify(IntroFlow.Event.WAVE_LAUNCHED)
	elif event.kind == GameEvent.Kind.WAVE_CLEARED:
		_flow.notify(IntroFlow.Event.WAVE_CLEARED)
	elif event.kind == GameEvent.Kind.GAME_OVER or event.kind == GameEvent.Kind.GAME_WON:
		# the intro has nothing left to say once the game has ended
		_flow.skip()


## The phone check tops the crowd up before each tick.
func _before_tick(game: GameState) -> void:
	Stress.top_up(game, _stress_foes)
	_hold.before_tick(game)


## Turns on the phone check from the page: `?stress=80` and `?fps`.
func _read_phone_check_params() -> void:
	_stress_foes = StressParams.foes(_url_param("stress"))
	if StressParams.fps_on(_url_param("fps")):
		_fps.enable(_count_foes)


func _count_foes() -> int:
	return _game.foes.size()


## Reads what the tick reported: a refused command becomes a short message.
func _after_tick(game: GameState) -> void:
	for event in game.events:
		# a kill whose shot is still flying snaps when the shot lands (see _process)
		var held := event.kind == GameEvent.Kind.FOE_KILLED and _hold.hold_kill(event.foe_id)
		if not held:
			_audio.play_sfx(SoundMap.sfx_for(event, game))
		_crow.deliver(CrowAlerts.text_for(event))
		_tell_intro(event)
		if event.kind == GameEvent.Kind.COMMAND_REJECTED:
			_show_message(RejectText.of(event.reason))
		elif event.kind == GameEvent.Kind.TOWER_FIRED:
			_draw_shot(game, event)
			_towers.fire(event.tower_id, ShotsView.body_point(event.x, event.y))
		elif event.kind == GameEvent.Kind.GUARD_RAISED:
			_towers.act(event.tower_id, "deploy")
		elif event.kind == GameEvent.Kind.FOE_LEAKED:
			_hold.release(event.foe_id)
	_hold.after_tick(game)


## Draws the shot a tower fired this tick, from the tower to where its target stood, and
## holds back what it did to the foes it hit until it is drawn landing.
func _draw_shot(game: GameState, event: GameEvent) -> void:
	for tower in game.towers:
		if tower.id == event.tower_id:
			var surface := _board.surface_height(Vector2i(tower.col, tower.row))
			var from := ShotsView.muzzle(tower, surface, game.map.footprint)
			var to := ShotsView.body_point(event.x, event.y)
			var kind := ShotsView.kind_for(tower.type)
			_shots.add_shot(from, to, event.splash, kind)
			if not from.is_equal_approx(to):
				_hold.hold(event, ShotsView.landing_of(kind, from, to))
			return


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_SECONDS
	_message.visible = true


## The page's `?tour=` value ("0" turns the first-visit intro off), or "".
func _tour_param() -> String:
	var value: Variant = _url_param("tour")
	return value if value is String and (value as String).length() <= 4 else ""


## One query parameter of the page as a String (empty for `?name`), or null when it is absent
## or the game is not on the web.
func _url_param(param_name: String) -> Variant:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.eval("new URLSearchParams(location.search).get('%s')" % param_name)


## Starts the intro wave: speech bubbles on the map, sockets glowing, Skip always there.
func _start_intro() -> void:
	_flow.start()
	_tell_page_tour(true)


## The browser smoke test reads whether the intro is open.
func _tell_page_tour(open: bool) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameTourOpen = %s" % str(open))


func _on_intro_finished(_skipped: bool) -> void:
	_progress.mark_seen()
	_glow.hide_all()
	_glow_shown = false
	_intro.refresh()
	_tell_page_tour(false)


func _open_guide() -> void:
	_pause_for_overlay(true)
	_guide.open()


## Keeps the glow and the bubble true to the intro's step; called every frame.
func _sync_intro() -> void:
	var wanted := _flow.highlights_sockets()
	if wanted and not _glow_shown:
		_glow.show_blocks(_free_sockets(), _game.map.footprint, _board.surface_height)
	elif not wanted and _glow_shown:
		_glow.hide_all()
	_glow_shown = wanted
	_intro.refresh()


## The sockets with no tower on them, which the intro asks the player to tap.
func _free_sockets() -> Array[Vector2i]:
	var free: Array[Vector2i] = []
	for anchor in _game.map.sockets:
		if _tower_on(anchor) == null:
			free.append(anchor)
	return free


## Shows a tower's card beside the build menu (hover, or press and hold): to its right when
## there is room, else to its left, and always on screen.
func _on_info_requested(id: String) -> void:
	_card.show_for(id)
	_card.reset_size()
	var port := get_viewport().get_visible_rect().size
	var menu := Rect2(_menu.position, _menu.size)
	var x := menu.end.x + CARD_MARGIN
	if x + _card.size.x > port.x - CARD_MARGIN:
		x = menu.position.x - CARD_MARGIN - _card.size.x
	_card.position = Vector2(
		clampf(x, CARD_MARGIN, maxf(CARD_MARGIN, port.x - CARD_MARGIN - _card.size.x)),
		clampf(menu.position.y, CARD_MARGIN, maxf(CARD_MARGIN, port.y - CARD_MARGIN - _card.size.y))
	)


## Puts the build menu beside the selected socket as it is drawn now.
func _place_menu() -> void:
	if _selected == BoardSpace.NO_CELL:
		return
	_menu.place_near(_socket_on_screen(_selected), get_viewport().get_visible_rect().size)


## The rectangle a socket block covers on screen: its four top corners, projected.
func _socket_on_screen(anchor: Vector2i) -> Rect2:
	var footprint := _game.map.footprint
	var centre := BoardSpace.footprint_centre(anchor, footprint)
	centre.y = _board.surface_height(anchor)
	var half := float(footprint) / 2.0
	var rect := Rect2(_camera.unproject_position(centre), Vector2.ZERO)
	for corner in [
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	]:
		rect = rect.expand(_camera.unproject_position(centre + Vector3(corner.x, 0.0, corner.y)))
	return rect


## The guide pauses the game while it is open and gives the pause back as the player had it.
func _pause_for_overlay(opening: bool) -> void:
	if opening:
		if not _guide.is_open():
			_paused_before_overlay = _speed.paused
		_speed.paused = true
	else:
		_speed.paused = _paused_before_overlay


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
	_launch.visible = true
	if _game.won:
		_launch.text = "You won"
		_launch.disabled = true
	elif _game.over:
		_launch.text = "Game over"
		_launch.disabled = true
	elif not _game.spawners.is_empty():
		# the Messenger Crow says the wave is coming; the button just steps aside
		_launch.visible = false
		_launch.disabled = true
		return
	elif _game.wave >= EARLY_RULES.WIN_WAVE:
		_launch.text = "Final wave"
		_launch.disabled = true
	elif _game.running:
		var bonus: int = EARLY_RULES.EARLY_CALL_BASE + _game.wave * EARLY_RULES.EARLY_CALL_PER_WAVE
		_launch.text = "Call wave %d early (+%d)" % [next, bonus]
		_launch.disabled = false
	elif _auto.counting():
		# Auto start: the button counts down, and a tap starts the wave at once
		_launch.text = "Wave %d in %d" % [next, _auto.seconds_left()]
		_launch.disabled = false
	else:
		_launch.text = "Start wave %d" % next
		_launch.disabled = false
