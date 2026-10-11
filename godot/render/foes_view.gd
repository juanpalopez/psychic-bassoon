## The foes on the board: one MultiMesh per foe type (capsules sized by the foe's
## radius, coloured by type and darker as hp falls), never a node per foe.
##
## The sim ticks at 30 Hz and the screen draws more often, so the view keeps each
## foe's previous position and blends to the current one by `alpha`, the share of
## a tick that has passed since the last one. It only reads the game's foes.
class_name FoesView
extends Node3D

const FOES := preload("res://content/foes.gd")
## Instances reserved per type; more foes than this are not drawn.
const MAX_PER_TYPE := 160
## Capsule dimensions at scale 1 (the foe's radius scales it).
const CAPSULE_RADIUS := 0.5
const CAPSULE_HEIGHT := 1.6
## Where the road surface is, so a foe stands on it.
const GROUND := 0.06
## How much darker a foe at 0 hp is drawn.
const HURT_DARKEN := 0.6
const COLOURS := {
	"scrapGoblin": Color("c9b88a"),
	"corrugatedOrc": Color("b5834a"),
	"cardboardGolem": Color("8a6a43"),
}
const FALLBACK_COLOUR := Color("cccccc")

var _multimeshes := {}
var _tick_seen := -1
var _previous := {}
var _current := {}
var _used := {}
# what was last written to each type's MultiMesh, kept so a headless test can
# read it back (the dummy renderer does not store instance data)
var _drawn_positions := {}
var _drawn_scales := {}
var _drawn_colours := {}


func _init() -> void:
	for type in FOES.FOE_IDS:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		var capsule := CapsuleMesh.new()
		capsule.radius = CAPSULE_RADIUS
		capsule.height = CAPSULE_HEIGHT
		multimesh.mesh = capsule
		multimesh.instance_count = MAX_PER_TYPE
		multimesh.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.name = type
		instance.multimesh = multimesh
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		instance.material_override = material
		add_child(instance)
		_multimeshes[type] = multimesh
		_used[type] = 0
		# plain Arrays: a Packed array inside a Dictionary is copied on write
		_drawn_positions[type] = _filled(Vector3.ZERO)
		_drawn_scales[type] = _filled(0.0)
		_drawn_colours[type] = _filled(Color.WHITE)


## A list of `MAX_PER_TYPE` copies of `value`.
func _filled(value: Variant) -> Array:
	var out := []
	out.resize(MAX_PER_TYPE)
	out.fill(value)
	return out


## How many foes of this type are drawn right now.
func visible_count(type: String) -> int:
	if not _multimeshes.has(type):
		return 0
	return (_multimeshes[type] as MultiMesh).visible_instance_count


## Where instance `index` of a type was last drawn (world position).
func drawn_position(type: String, index: int) -> Vector3:
	return _drawn_positions[type][index]


## The uniform scale of instance `index` of a type.
func drawn_scale(type: String, index: int) -> float:
	return _drawn_scales[type][index]


## The colour of instance `index` of a type.
func drawn_colour(type: String, index: int) -> Color:
	return _drawn_colours[type][index]


## Forgets the previous positions (a new game starts: ids are used again).
func reset() -> void:
	_tick_seen = -1
	_previous.clear()
	_current.clear()
	for type in _multimeshes:
		(_multimeshes[type] as MultiMesh).visible_instance_count = 0


## Draws the foes of `game`. `alpha` is how far we are from the last tick to the
## next, 0 to 1.
func update(game: GameState, alpha: float) -> void:
	if game.tick_count != _tick_seen:
		_tick_seen = game.tick_count
		var next := {}
		for foe in game.foes:
			next[foe.id] = Vector2(foe.x, foe.y)
		var before := {}
		for foe in game.foes:
			before[foe.id] = _current.get(foe.id, next[foe.id])
		_previous = before
		_current = next
	var blend := clampf(alpha, 0.0, 1.0)
	for type in _used:
		_used[type] = 0
	for foe in game.foes:
		var multimesh: MultiMesh = _multimeshes.get(foe.type)
		if multimesh == null:
			continue
		var index: int = _used[foe.type]
		if index >= MAX_PER_TYPE:
			continue
		_used[foe.type] = index + 1
		var from: Vector2 = _previous.get(foe.id, Vector2(foe.x, foe.y))
		var to: Vector2 = _current.get(foe.id, Vector2(foe.x, foe.y))
		var at := from.lerp(to, blend)
		var scale := foe.radius / CAPSULE_RADIUS
		var position := BoardSpace.point_to_world(at.x, at.y)
		position.y = GROUND + CAPSULE_HEIGHT * scale / 2.0
		multimesh.set_instance_transform(
			index, Transform3D(Basis.from_scale(Vector3(scale, scale, scale)), position)
		)
		var health := float(foe.hp) / maxf(float(foe.max_hp), 1.0)
		var base: Color = COLOURS.get(foe.type, FALLBACK_COLOUR)
		var colour := base.darkened(HURT_DARKEN * (1.0 - clampf(health, 0.0, 1.0)))
		multimesh.set_instance_color(index, colour)
		_drawn_positions[foe.type][index] = position
		_drawn_scales[foe.type][index] = scale
		_drawn_colours[foe.type][index] = colour
	for type in _multimeshes:
		(_multimeshes[type] as MultiMesh).visible_instance_count = _used[type]
