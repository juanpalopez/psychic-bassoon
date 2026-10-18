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
## Feet stand on the lane.
const GROUND := Board.ROAD_HEIGHT
## How much darker a foe at 0 hp is drawn.
const HURT_DARKEN := 0.6
const COLOURS := {
	"scrapGoblin": Color("c9b88a"),
	"corrugatedOrc": Color("b5834a"),
	"cardboardGolem": Color("8a6a43"),
	"inkShaman": Color("5b5a8a"),
	"razorMoth": Color("d9c7e0"),
}
const FALLBACK_COLOUR := Color("cccccc")
## The foes drawn with a model from `godot/assets/models/enemies` instead of a capsule
## (greybox models by the owner): its file and how tall it stands, in cells. A model is
## scaled to that height with its feet on the road and faces +Z at yaw 0, wears the painted
## paper of `PaperLook` in its materials' colours (the instance colour multiplies it, so the
## foe is darkened as it is hurt); a missing file leaves the capsule.
const MODELS := {
	"scrapGoblin": {"path": "res://assets/models/enemies/scrap_goblin.glb", "height": 0.8},
	"corrugatedOrc": {"path": "res://assets/models/enemies/corrugated_orc.glb", "height": 1.2},
	"cardboardGolem": {"path": "res://assets/models/enemies/cardboard_golem.glb", "height": 2.0},
	"inkShaman": {"path": "res://assets/models/enemies/ink_shaman.glb", "height": 1.0},
	"razorMoth": {"path": "res://assets/models/enemies/razor_moth.glb", "height": 0.8},
}
## A foe that has not moved yet faces along the road, towards +x.
const DEFAULT_YAW := PI / 2.0

## How much of the way to a new heading a foe turns each tick (a corner takes a few ticks).
const HEADING_EASE := 0.2

## Whether foes are moved by their `FoeSpread` offset (tests turn it off to read sim points).
var spread_enabled := true

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
## Per model type: its mesh, the scale that makes it its height and the height of its
## lowest point above the origin, so that it can stand on the road.
var _models := {}
## The way each foe last walked (radians about the vertical axis), by foe id.
var _yaws := {}
var _drawn_yaws := {}
## The way each foe last walked as a unit vector in world x/z, by foe id, for its spread.
var _headings := {}
## The health bars over the hurt foes (one MultiMesh for all of them).
var _bars: FoeBars


func _init(models: Dictionary = MODELS) -> void:
	for type in FOES.FOE_IDS:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		var mesh := (
			PaperLook.dress(ModelLoader.mesh(models[type].path)) if models.has(type) else null
		)
		if mesh != null:
			var box := mesh.get_aabb()
			var scale := float(models[type].height) / box.size.y
			_models[type] = {
				"mesh": mesh,
				"scale": scale,
				"foot": -box.position.y * scale,
				"height": float(models[type].height),
			}
			multimesh.mesh = mesh
		else:
			var capsule := CapsuleMesh.new()
			capsule.radius = CAPSULE_RADIUS
			capsule.height = CAPSULE_HEIGHT
			multimesh.mesh = capsule
		multimesh.instance_count = MAX_PER_TYPE
		multimesh.visible_instance_count = 0
		var instance := MultiMeshInstance3D.new()
		instance.name = type
		instance.multimesh = multimesh
		if mesh == null:
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
		_drawn_yaws[type] = _filled(0.0)
	_bars = FoeBars.new()
	add_child(_bars)


## A list of `MAX_PER_TYPE` copies of `value`.
func _filled(value: Variant) -> Array:
	var out := []
	out.resize(MAX_PER_TYPE)
	out.fill(value)
	return out


## Whether a foe type is drawn with a model (and not the capsule).
func uses_model(type: String) -> bool:
	return _models.has(type)


## The mesh a foe type is drawn with.
func mesh_of(type: String) -> Mesh:
	return (_multimeshes[type] as MultiMesh).mesh


## The way instance `index` of a model type faces (radians about the vertical axis).
func drawn_yaw(type: String, index: int) -> float:
	return _drawn_yaws[type][index]


## How many health bars are drawn.
func bar_count() -> int:
	return _bars.bar_count()


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
	_yaws.clear()
	_headings.clear()
	_bars.begin()
	_bars.finish()
	for type in _multimeshes:
		(_multimeshes[type] as MultiMesh).visible_instance_count = 0


## Eases each walking foe's heading towards the way it walked this tick, and forgets the
## foes that are gone. A foe at a road corner turns its heading over several ticks, so its
## spread offset glides round the corner instead of jumping across the road.
func _ease_headings(game: GameState) -> void:
	var alive := {}
	for foe in game.foes:
		alive[foe.id] = true
		var walked: Vector2 = _current[foe.id] - _previous[foe.id]
		if walked.length_squared() <= 1e-9:
			continue
		var raw := walked.normalized()
		if not _headings.has(foe.id):
			_headings[foe.id] = raw
			continue
		var old: Vector2 = _headings[foe.id]
		# easing between opposite ways collapses back to the old one, so a reversal takes the
		# new way at once (the sim's roads do not reverse; a knock-back could)
		if old.dot(raw) < -0.5:
			_headings[foe.id] = raw
		else:
			_headings[foe.id] = old.lerp(raw, HEADING_EASE).normalized()
	for id in _headings.keys():
		if not alive.has(id):
			_headings.erase(id)
	for id in _yaws.keys():
		if not alive.has(id):
			_yaws.erase(id)


## Draws the foes of `game`. `alpha` is how far we are from the last tick to the
## next, 0 to 1. With a `hold`, a foe shows the health it had until the shot that hit it
## lands, and a killed foe stands where it fell until then.
func update(game: GameState, alpha: float, hold: HitHold = null) -> void:
	if hold != null:
		hold.observe(game)
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
		_ease_headings(game)
	var blend := clampf(alpha, 0.0, 1.0)
	for type in _used:
		_used[type] = 0
	_bars.begin()
	var drawn: Array[Foe] = game.foes if hold == null else hold.drawn_foes(game)
	for foe in drawn:
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
		var position := BoardSpace.point_to_world(at.x, at.y)
		var walked := to - from
		var lift := 0.0
		if spread_enabled:
			var spread := FoeSpread.offset(foe.id, _headings.get(foe.id, Vector2.RIGHT), foe.flying)
			position.x += spread.x
			position.z += spread.z
			lift = spread.y
		var scale := foe.radius / CAPSULE_RADIUS
		var basis := Basis.from_scale(Vector3(scale, scale, scale))
		position.y = GROUND + lift + CAPSULE_HEIGHT * scale / 2.0
		var head_y := GROUND + lift + CAPSULE_HEIGHT * scale
		if _models.has(foe.type):
			var model: Dictionary = _models[foe.type]
			if walked.length_squared() > 1e-9:
				_yaws[foe.id] = atan2(walked.x, walked.y)
			var yaw: float = _yaws.get(foe.id, DEFAULT_YAW)
			scale = model.scale
			basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(scale, scale, scale))
			position.y = GROUND + lift + float(model.foot)
			head_y = GROUND + lift + float(model.height)
			_drawn_yaws[foe.type][index] = yaw
		multimesh.set_instance_transform(index, Transform3D(basis, position))
		var hp := foe.hp if hold == null else hold.shown_hp(foe)
		var standing := foe.alive or (hold != null and hold.is_ghost(foe.id))
		var health := FoeBars.share(hp, foe.max_hp)
		var base: Color = (
			Color.WHITE if _models.has(foe.type) else COLOURS.get(foe.type, FALLBACK_COLOUR)
		)
		var colour := base.darkened(HURT_DARKEN * (1.0 - health))
		multimesh.set_instance_color(index, colour)
		_drawn_positions[foe.type][index] = position
		_drawn_scales[foe.type][index] = scale
		_drawn_colours[foe.type][index] = colour
		if FoeBars.is_shown(hp, foe.max_hp, standing):
			_bars.add(Vector3(position.x, head_y, position.z), health, foe.type)
	_bars.finish()
	for type in _multimeshes:
		(_multimeshes[type] as MultiMesh).visible_instance_count = _used[type]
