## Player actions. They are the only way in: state changes through commands
## and ticks, nothing else.
## Treat a command as immutable once submitted: the queue and any rejection
## event keep a reference to it.
class_name Command
extends RefCounted

enum Kind { BUILD, UPGRADE, SELL, LAUNCH_WAVE, CHOOSE_SPEC, ACTIVATE_ABILITY, MOVE_HERO }

var kind: Kind = Kind.LAUNCH_WAVE
## BUILD: a tower id from `content/towers.gd`.
var tower: String = ""
## BUILD: the plot cell; MOVE_HERO: the cell to walk to.
var col: int = 0
var row: int = 0
## UPGRADE, SELL, CHOOSE_SPEC and ACTIVATE_ABILITY: the tower's id.
var tower_id: int = 0
## CHOOSE_SPEC: a spec id from `content/specs.gd`.
var spec: String = ""


static func build(tower_type: String, cell_col: int, cell_row: int) -> Command:
	var command := Command.new()
	command.kind = Kind.BUILD
	command.tower = tower_type
	command.col = cell_col
	command.row = cell_row
	return command


static func upgrade(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.UPGRADE
	command.tower_id = id
	return command


static func sell(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.SELL
	command.tower_id = id
	return command


static func launch_wave() -> Command:
	var command := Command.new()
	command.kind = Kind.LAUNCH_WAVE
	return command


static func choose_spec(id: int, spec_id: String) -> Command:
	var command := Command.new()
	command.kind = Kind.CHOOSE_SPEC
	command.tower_id = id
	command.spec = spec_id
	return command


static func activate(id: int) -> Command:
	var command := Command.new()
	command.kind = Kind.ACTIVATE_ABILITY
	command.tower_id = id
	return command


static func move_hero(cell_col: int, cell_row: int) -> Command:
	var command := Command.new()
	command.kind = Kind.MOVE_HERO
	command.col = cell_col
	command.row = cell_row
	return command
