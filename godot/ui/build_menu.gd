## A strip of kraft paper with one token per tower: its icon, name and what it costs. It opens
## next to the tapped socket (above it when there is room, else below), fades what the player
## cannot afford, and announces the choice; it does not touch the game (the scene turns the
## choice into a command).
class_name BuildMenu
extends PanelContainer

signal tower_chosen(tower: String)
## A tower button was hovered or held: show its card; the pointer left: clear it.
signal info_requested(tower: String)
signal info_cleared

const TOWERS := preload("res://content/towers.gd")
const BUTTON_SIZE := Vector2(120.0, 176.0)
## One token picture per tower id.
const ICONS := {
	"spoolGuard": preload("res://assets/icons/tower_spool_guard.svg"),
	"thimbleMortar": preload("res://assets/icons/tower_thimble_mortar.svg"),
	"prismSpire": preload("res://assets/icons/tower_prism_spire.svg"),
	"guardTent": preload("res://assets/icons/tower_guard_tent.svg"),
	"messTent": preload("res://assets/icons/tower_mess_tent.svg"),
}
## Room kept clear for the corner controls above and the Start wave row below, and the
## gap between the menu and the socket it was opened for.
const TOP_RESERVE := 112.0
const BOTTOM_RESERVE := 120.0
const EDGE_MARGIN := 14.0
const SOCKET_GAP := 12.0
## How long a press must last to count as a hold (a look, not a choice).
const HOLD_SECONDS := 0.4

## The plot the menu was opened for.
var cell := BoardSpace.NO_CELL

var _tower_buttons: Array[Button] = []
var _buttons := 0
var _hold_timer: Timer
var _held_id := ""
var _hold_fired := false


func _ready() -> void:
	visible = false
	theme_type_variation = &"Kraft"
	var box := HBoxContainer.new()
	add_child(box)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_SECONDS
	_hold_timer.timeout.connect(hold_elapsed)
	add_child(_hold_timer)
	for id in TOWERS.TOWER_IDS:
		var button := Button.new()
		var def: Dictionary = TOWERS.DEFS[id]
		button.text = "%s\n%d" % [def.name, def.cost[0]]
		button.custom_minimum_size = BUTTON_SIZE
		button.icon = ICONS.get(id)
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = def.name
		# long names wrap inside the fixed width, so five towers fit in one row
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.theme_type_variation = &"TowerToken"
		button.pressed.connect(_choose.bind(id))
		button.mouse_entered.connect(_hover.bind(id))
		button.mouse_exited.connect(func() -> void: info_cleared.emit())
		button.button_down.connect(_start_hold.bind(id))
		button.button_up.connect(_stop_hold)
		box.add_child(button)
		_tower_buttons.append(button)


## The tower buttons, in the order of `TOWER_IDS`.
func tower_buttons() -> Array[Button]:
	return _tower_buttons


## Opens the menu for a socket, with the Buttons the player has now.
func open_for(plot: Vector2i, buttons: int) -> void:
	cell = plot
	set_buttons(buttons)
	visible = true


## Moves the menu next to a socket drawn at `socket` (its rectangle on screen) in a
## screen of `port` size.
func place_near(socket: Rect2, port: Vector2) -> void:
	reset_size()
	position = placement(socket, size, port)


## Where a menu of `menu_size` goes for a socket drawn at `socket`: centred above it when
## that leaves the corner controls clear, else below it, else (a socket in the middle band)
## beside it; always inside the screen between the top and bottom rows of controls.
static func placement(socket: Rect2, menu_size: Vector2, port: Vector2) -> Vector2:
	var centred := socket.get_center().x - menu_size.x / 2.0
	centred = clampf(centred, EDGE_MARGIN, maxf(EDGE_MARGIN, port.x - EDGE_MARGIN - menu_size.x))
	var lowest := maxf(TOP_RESERVE, port.y - BOTTOM_RESERVE - menu_size.y)
	var above := socket.position.y - SOCKET_GAP - menu_size.y
	if above >= TOP_RESERVE:
		return Vector2(centred, above)
	# a socket under the top row still gets its menu below that row
	var below := maxf(socket.end.y + SOCKET_GAP, TOP_RESERVE)
	if below <= lowest:
		return Vector2(centred, below)
	var level := clampf(socket.get_center().y - menu_size.y / 2.0, TOP_RESERVE, lowest)
	var right := socket.end.x + SOCKET_GAP
	if right + menu_size.x <= port.x - EDGE_MARGIN:
		return Vector2(right, level)
	var left := socket.position.x - SOCKET_GAP - menu_size.x
	if left >= EDGE_MARGIN:
		return Vector2(left, level)
	# a screen too small for any of these: below, pushed up as far as the rows allow
	return Vector2(centred, clampf(below, TOP_RESERVE, lowest))


func close() -> void:
	visible = false
	_hold_timer.stop()
	_held_id = ""
	_hold_fired = false


## Greys out the towers that cost more than `buttons`.
func set_buttons(buttons: int) -> void:
	_buttons = buttons
	for i in _tower_buttons.size():
		var cost: int = TOWERS.DEFS[TOWERS.TOWER_IDS[i]].cost[0]
		_tower_buttons[i].disabled = cost > _buttons


## A mouse hovering over a button asks for its card; a touch also produces a mouse enter, but
## with the button already down, and that is the start of a tap or a hold, not a hover.
func _hover(id: String) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		info_requested.emit(id)


## A press that lasted long enough: show the card instead of choosing.
func hold_elapsed() -> void:
	if _held_id == "" or not visible:
		return
	_hold_fired = true
	info_requested.emit(_held_id)


func _start_hold(id: String) -> void:
	_held_id = id
	_hold_fired = false
	if _hold_timer.is_inside_tree():
		_hold_timer.start()


func _stop_hold() -> void:
	_hold_timer.stop()
	_held_id = ""
	if _hold_fired:
		# the look is over once the finger lets go
		info_cleared.emit()


func _choose(id: String) -> void:
	if _hold_fired:
		# the press was a look: keep the menu open and the card showing
		_hold_fired = false
		return
	info_cleared.emit()
	tower_chosen.emit(id)
	close()
