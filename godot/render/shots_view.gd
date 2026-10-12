## Tower shots and beams, drawn from what the sim reports. A shot is a thin line
## from the tower to its target that lasts a moment (and a flat ring for a
## blast); a beam is a line that lasts as long as its tower's lock. Both come
## from small fixed pools, so nothing is created while playing. It only reads.
class_name ShotsView
extends Node3D

## How long a shot stays on screen, in seconds.
const SHOT_SECONDS := 0.12
const MAX_SHOTS := 48
const MAX_BEAMS := 32
const LINE_WIDTH := 0.06
const BEAM_WIDTH := 0.1
const RING_HEIGHT := 0.03
## Where on a tower a shot or beam starts, above its tile.
const MUZZLE_HEIGHT := 1.1
## Where on a foe a shot or beam ends, above the ground.
const BODY_HEIGHT := 0.4
const SHOT_COLOUR := Color(1.0, 0.95, 0.6, 1.0)
const BEAM_COLOUR := Color(0.9, 0.5, 1.0, 1.0)
const RING_COLOUR := Color(1.0, 0.7, 0.3, 0.35)

var _lines: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _left: Array[float] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _next := 0
var _beams: Array[MeshInstance3D] = []
var _beam_from: Array[Vector3] = []
var _beam_to: Array[Vector3] = []
var _beams_shown := 0


func _init() -> void:
	var shot_mesh := _line_mesh(LINE_WIDTH)
	var shot_material := _unshaded(SHOT_COLOUR)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	var ring_material := _unshaded(RING_COLOUR)
	for i in MAX_SHOTS:
		_lines.append(_node(shot_mesh, shot_material))
		_rings.append(_node(disc, ring_material))
		_left.append(0.0)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
	var beam_mesh := _line_mesh(BEAM_WIDTH)
	var beam_material := _unshaded(BEAM_COLOUR)
	for i in MAX_BEAMS:
		_beams.append(_node(beam_mesh, beam_material))
		_beam_from.append(Vector3.ZERO)
		_beam_to.append(Vector3.ZERO)


## Where a shot or beam leaves a tower standing on a tile `surface` tall, over
## the middle of its socket block of `footprint` cells.
static func muzzle(tower: Tower, surface: float, footprint: int = 1) -> Vector3:
	var at := BoardSpace.footprint_centre(Vector2i(tower.col, tower.row), footprint)
	return Vector3(at.x, surface + MUZZLE_HEIGHT, at.z)


## Where a shot or beam lands on a foe at a sim position.
static func body_point(sim_x: float, sim_y: float) -> Vector3:
	var at := BoardSpace.point_to_world(sim_x, sim_y)
	return Vector3(at.x, BODY_HEIGHT, at.z)


## Draws a shot, and a ring `splash` cells wide at the target when it is above 0.
## When every slot is busy the oldest is reused.
func add_shot(from: Vector3, to: Vector3, splash: float) -> void:
	if from.is_equal_approx(to):
		return
	var slot := _next
	_next = (_next + 1) % MAX_SHOTS
	_place_line(_lines[slot], from, to)
	_left[slot] = SHOT_SECONDS
	_from[slot] = from
	_to[slot] = to
	var ring := _rings[slot]
	ring.visible = splash > 0.0
	if ring.visible:
		ring.position = Vector3(to.x, RING_HEIGHT, to.z)
		ring.scale = Vector3(splash, 1.0, splash)


## Ages the shots by `delta` seconds and hides the ones that ran out.
func update(delta: float) -> void:
	for i in MAX_SHOTS:
		if _left[i] <= 0.0:
			continue
		_left[i] -= delta
		if _left[i] <= 0.0:
			_lines[i].visible = false
			_rings[i].visible = false


## Draws one beam for every beam tower that holds a lock on a live foe, and none
## otherwise. `surface_height` takes a cell and returns the top of its tile.
func show_beams(game: GameState, surface_height: Callable) -> void:
	var shown := 0
	for tower in game.towers:
		if tower.target_id < 0 or shown >= MAX_BEAMS:
			continue
		var foe := _foe_with_id(game, tower.target_id)
		if foe == null:
			continue
		var surface := 0.0
		if surface_height.is_valid():
			surface = surface_height.call(Vector2i(tower.col, tower.row))
		_beam_from[shown] = muzzle(tower, surface, game.map.footprint)
		_beam_to[shown] = body_point(foe.x, foe.y)
		_place_line(_beams[shown], _beam_from[shown], _beam_to[shown])
		shown += 1
	for i in range(shown, _beams_shown):
		_beams[i].visible = false
	_beams_shown = shown


func visible_shots() -> int:
	var count := 0
	for line in _lines:
		if line.visible:
			count += 1
	return count


func visible_beams() -> int:
	return _beams_shown


func shot_line(index: int) -> MeshInstance3D:
	return _lines[index]


func shot_ring(index: int) -> MeshInstance3D:
	return _rings[index]


func drawn_from(index: int) -> Vector3:
	return _from[index]


func drawn_to(index: int) -> Vector3:
	return _to[index]


func beam_line(index: int) -> MeshInstance3D:
	return _beams[index]


func beam_from(index: int) -> Vector3:
	return _beam_from[index]


func beam_to(index: int) -> Vector3:
	return _beam_to[index]


func _foe_with_id(game: GameState, id: int) -> Foe:
	for foe in game.foes:
		if foe.id == id and foe.alive:
			return foe
	return null


## Lays a unit-long box between two points: centred between them, pointing along
## them and stretched to their distance.
func _place_line(line: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var up := Vector3.UP if absf(along.normalized().y) < 0.99 else Vector3.RIGHT
	var facing := Basis.looking_at(along.normalized(), up)
	# scale along the box's own long axis, not along the world's
	line.basis = facing * Basis.from_scale(Vector3(1.0, 1.0, along.length()))
	line.position = (from + to) / 2.0
	line.visible = true


func _node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.visible = false
	add_child(node)
	return node


func _line_mesh(width: float) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3(width, width, 1.0)
	return box


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
