## Draws the hero, the ring that says it is selected, the cell it was sent to and the walk
## still ahead of it (#335). It only reads the hero the game holds; orders go out as commands.
## Placeholder shapes until the Knight's model arrives (Phase 6).
class_name HeroView
extends Node3D

const BODY_HEIGHT := 0.7
const BODY_RADIUS := 0.22
const RING_RADIUS := 0.45
const RING_THICKNESS := 0.04
const MARKER_SIZE := 0.8
## How far the marker and the path rest above the ground, so neither sinks into a terrace.
const LIFT := 0.06
const BODY_COLOUR := Color(0.95, 0.8, 0.25)
const RING_COLOUR := Color(0.2, 0.9, 0.9, 0.8)
const TARGET_COLOUR := Color(0.2, 0.9, 0.9, 0.5)
const PATH_COLOUR := Color(0.2, 0.9, 0.9, 0.9)

var _body := MeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _target := CellHighlight.new()
var _path := MeshInstance3D.new()
var _line := ImmediateMesh.new()
# the walk the line was drawn for, to redraw it only when the walk changes
var _drawn: Array[Vector2i] = []


func _init() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	_body.mesh = capsule
	_body.material_override = _unshaded(BODY_COLOUR)
	_body.position.y = BODY_HEIGHT / 2.0
	add_child(_body)
	var disc := CylinderMesh.new()
	disc.top_radius = RING_RADIUS
	disc.bottom_radius = RING_RADIUS
	disc.height = RING_THICKNESS
	_ring.mesh = disc
	_ring.material_override = _unshaded(RING_COLOUR)
	add_child(_ring)
	_path.mesh = _line
	_path.material_override = _unshaded(PATH_COLOUR)
	_path.top_level = true
	add_child(_path)
	_target.top_level = true
	add_child(_target)
	visible = false
	_ring.visible = false


## Puts the hero where the game has it (`surface_height` takes a cell and gives the top of its
## tile), the ring on when it is `selected`, and the target and the walk ahead of it.
func sync(hero: Hero, surface_height: Callable, selected: bool) -> void:
	visible = hero != null and hero.alive
	if not visible:
		_hide_walk()
		return
	var at := BoardSpace.point_to_world(hero.x, hero.y)
	at.y = float(surface_height.call(hero.cell))
	position = at
	_ring.visible = selected
	if hero.path.is_empty():
		_hide_walk()
		return
	if hero.path != _drawn:
		_draw_walk(hero.path, surface_height)
	_path.visible = true


## The world points of a walk: the middle of each cell, resting `LIFT` above its tile.
static func walk_points(cells: Array[Vector2i], surface_height: Callable) -> PackedVector3Array:
	var points := PackedVector3Array()
	for cell in cells:
		var at := BoardSpace.cell_to_world(cell.x, cell.y)
		at.y = float(surface_height.call(cell)) + LIFT
		points.append(at)
	return points


## Whether the target marker is up.
func target_shown() -> bool:
	return _target.visible


func _draw_walk(cells: Array[Vector2i], surface_height: Callable) -> void:
	_drawn = cells.duplicate()
	_line.clear_surfaces()
	var points := walk_points(cells, surface_height)
	# a line needs two points; a one-cell walk shows only the marker
	if points.size() >= 2:
		_line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point in points:
			_line.surface_add_vertex(point)
		_line.surface_end()
	var end := cells[cells.size() - 1]
	_target.show_cell(end, float(surface_height.call(end)), TARGET_COLOUR)
	_target.scale = Vector3(MARKER_SIZE, 1.0, MARKER_SIZE)


func _hide_walk() -> void:
	_path.visible = false
	_target.hide_cell()
	_drawn = []
	_line.clear_surfaces()


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
