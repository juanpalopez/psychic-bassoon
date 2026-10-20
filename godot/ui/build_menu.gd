## The build bar: while a free socket is selected, the bottom HUD row becomes one row of
## tower tokens (icon, name and price; faded when too dear) and a Close square. Nothing floats
## over the world. It announces the choice and does not touch the game (the scene turns the
## choice into a command).
class_name BuildMenu
extends HBoxContainer

signal tower_chosen(tower: String)
## A tower button was hovered or held: show its card; the pointer left: clear it.
signal info_requested(tower: String)
signal info_cleared
## Close was pressed: the scene drops the selection.
signal closed

const TOWERS := preload("res://content/towers.gd")
const CLOSE_ICON := preload("res://assets/icons/close.svg")
## The tower disc beside a token's name, smaller than its 88 px picture.
const TOKEN_ICON := 64
## One token picture per tower id.
const ICONS := {
	"spoolGuard": preload("res://assets/icons/tower_spool_guard.svg"),
	"thimbleMortar": preload("res://assets/icons/tower_thimble_mortar.svg"),
	"prismSpire": preload("res://assets/icons/tower_prism_spire.svg"),
	"guardTent": preload("res://assets/icons/tower_guard_tent.svg"),
	"messTent": preload("res://assets/icons/tower_mess_tent.svg"),
}
## How long a press must last to count as a hold (a look, not a choice).
const HOLD_SECONDS := 0.4

## The plot the bar was opened for.
var cell := BoardSpace.NO_CELL

var _tower_buttons: Array[Button] = []
var _close: Button
var _buttons := 0
var _hold_timer: Timer
var _held_id := ""
var _hold_fired := false


func _ready() -> void:
	visible = false
	# a box lets taps through its gaps; a tap between two tokens must not reach the board
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_SECONDS
	_hold_timer.timeout.connect(hold_elapsed)
	add_child(_hold_timer)
	for id in TOWERS.TOWER_IDS:
		var button := Button.new()
		var def: Dictionary = TOWERS.DEFS[id]
		button.text = "%s\n%d" % [def.name, def.cost[0]]
		button.custom_minimum_size = Vector2(0.0, HudLayout.ROW)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = ICONS.get(id)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", TOKEN_ICON)
		button.tooltip_text = def.name
		# a long name wraps beside its disc, so five towers share one row
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.theme_type_variation = &"BarToken"
		button.pressed.connect(_choose.bind(id))
		button.mouse_entered.connect(_hover.bind(id))
		button.mouse_exited.connect(func() -> void: info_cleared.emit())
		button.button_down.connect(_start_hold.bind(id))
		button.button_up.connect(_stop_hold)
		add_child(button)
		_tower_buttons.append(button)
	_close = Button.new()
	_close.text = "Close"
	_close.icon = CLOSE_ICON
	_close.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close.theme_type_variation = &"IconButton"
	_close.custom_minimum_size = Vector2(HudLayout.ROW, HudLayout.ROW)
	_close.pressed.connect(
		func() -> void:
			close()
			closed.emit()
	)
	add_child(_close)


## The tower buttons, in the order of `TOWER_IDS`.
func tower_buttons() -> Array[Button]:
	return _tower_buttons


func close_button() -> Button:
	return _close


## Opens the bar for a socket, with the Buttons the player has now.
func open_for(plot: Vector2i, buttons: int) -> void:
	cell = plot
	set_buttons(buttons)
	visible = true


## Whether a socket drawn at `socket` on a screen of `port` size sits under the bar or the top
## row, or runs off the side: then the camera should bring it to the middle.
static func needs_room(socket: Rect2, port: Vector2) -> bool:
	return (
		socket.end.y > port.y - HudLayout.BOTTOM_CLEAR
		or socket.position.y < HudLayout.TOP_CLEAR
		or socket.position.x < 0.0
		or socket.end.x > port.x
	)


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
