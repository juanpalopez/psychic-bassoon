## Tower attacks, drawn from what the sim reports. The sim lands a shot the tick it is
## fired; the drawing gives it a flight: the Spool Guard's paper dart flies straight to the
## foe and pops into paper scraps, the Thimble Mortar's crumpled pellet arcs over and bursts
## into confetti in a ring as wide as its blast, and the Prism Spire's beam is a rainbow of
## split light that lasts as long as its lock, with a glow where it hits. Flights step at
## 12 frames a second like the rest of the stop-motion. Everything comes from small fixed
## pools, so nothing is created while playing, and nothing is random: the scraps' scatter is
## part of their mesh. It only reads.
class_name ShotsView
extends Node3D

enum Kind { DART, PELLET }

## The stop-motion frame rate the flights step at.
const FPS := 12.0
const MAX_SHOTS := 48
const MAX_BEAMS := 32
## A dart flies at this speed, but takes at least 2 and at most 4 frames.
const DART_SPEED := 22.0
const DART_MIN := 2.0 / 12.0
const DART_MAX := 4.0 / 12.0
## A pellet's flight, and how high its arc rises over the higher end per metre it travels.
const PELLET_SECONDS := 6.0 / 12.0
const ARC_BASE := 0.8
const ARC_PER_METRE := 0.3
## How long the pop or the burst at the target lasts.
const POP_SECONDS := 3.0 / 12.0
const BURST_SECONDS := 5.0 / 12.0
## The longest a shot can be on screen.
const SHOT_SECONDS := DART_MAX + POP_SECONDS
const BEAM_WIDTH := 0.22
const RING_HEIGHT := 0.03
## Where up the drawn tower a shot leaves it, as a share of its height.
const MUZZLE_SHARE := 0.8
## Where on a foe a shot or beam ends, above the ground.
const BODY_HEIGHT := 0.4
const RING_COLOUR := Color(1.0, 0.85, 0.55, 0.45)
const GLOW_COLOUR := Color(0.75, 0.9, 1.0, 1.0)
const DART_MODEL := "res://assets/models/towers/spool_guard.glb"
const DART_PART := "SpoolGuard_Dart"
const DART_SCALE := 0.9
const PELLET_RADIUS := 0.16
## The paper colours of the scraps and the confetti (sRGB).
const SCRAP_COLOURS: Array[Color] = [
	Color("f3ead6"), Color("c8392f"), Color("efc23e"), Color("3567a8"), Color("ded7c5")
]

var _bodies: Array[MeshInstance3D] = []
var _bursts: Array[MeshInstance3D] = []
var _rings: Array[MeshInstance3D] = []
var _kind: Array[int] = []
var _age: Array[float] = []
var _flight: Array[float] = []
var _life: Array[float] = []
var _splash: Array[float] = []
var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _next := 0
var _beams: Array[MeshInstance3D] = []
var _glows: Array[MeshInstance3D] = []
var _beam_from: Array[Vector3] = []
var _beam_to: Array[Vector3] = []
var _beams_shown := 0
var _dart_mesh: Mesh
var _pellet_mesh: Mesh


func _init() -> void:
	_dart_mesh = _load_dart()
	_pellet_mesh = _crumpled_ball(PELLET_RADIUS)
	var burst := _scraps()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	var ring_material := _unshaded(RING_COLOUR)
	for i in MAX_SHOTS:
		_bodies.append(_node(_dart_mesh, null))
		_bursts.append(_node(burst, null))
		_rings.append(_node(disc, ring_material))
		_kind.append(Kind.DART)
		_age.append(0.0)
		_flight.append(0.0)
		_life.append(0.0)
		_splash.append(0.0)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
	var tube := _tube(BEAM_WIDTH / 2.0, 8)
	var beam_material := PaperLook.material("prism_beam")
	var glow := SphereMesh.new()
	glow.radius = 0.22
	glow.height = 0.44
	glow.radial_segments = 10
	glow.rings = 5
	var glow_material := _unshaded(GLOW_COLOUR)
	glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for i in MAX_BEAMS:
		_beams.append(_node(tube, beam_material))
		_glows.append(_node(glow, glow_material))
		_beam_from.append(Vector3.ZERO)
		_beam_to.append(Vector3.ZERO)


## Where a shot or beam leaves a tower standing on a tile `surface` tall, over
## the middle of its socket block of `footprint` cells.
static func muzzle(tower: Tower, surface: float, footprint: int = 1) -> Vector3:
	var at := BoardSpace.footprint_centre(Vector2i(tower.col, tower.row), footprint)
	var height := TowerView.height_of(tower.level, TowerLooks.for_type(tower.type))
	return Vector3(at.x, surface + height * MUZZLE_SHARE, at.z)


## Where a shot or beam lands on a foe at a sim position.
static func body_point(sim_x: float, sim_y: float) -> Vector3:
	var at := BoardSpace.point_to_world(sim_x, sim_y)
	return Vector3(at.x, BODY_HEIGHT, at.z)


## What a tower of `type` throws: a blast (`splash` above 0) is a pellet, anything else a dart.
static func kind_for(splash: float) -> Kind:
	return Kind.PELLET if splash > 0.0 else Kind.DART


## How long a shot of `kind` takes to fly from `from` to `to`, in seconds.
static func flight_of(kind: Kind, from: Vector3, to: Vector3) -> float:
	if kind == Kind.PELLET:
		return PELLET_SECONDS
	return clampf(from.distance_to(to) / DART_SPEED, DART_MIN, DART_MAX)


## How long a shot of `kind` stays on screen: its flight and then its pop or burst.
static func life_of(kind: Kind, from: Vector3, to: Vector3) -> float:
	return flight_of(kind, from, to) + (BURST_SECONDS if kind == Kind.PELLET else POP_SECONDS)


## Where a shot of `kind` is at `share` (0 to 1) of its flight: a dart on the straight
## line, a pellet on an arc over it.
static func point_on_flight(kind: Kind, from: Vector3, to: Vector3, share: float) -> Vector3:
	var on_line := from.lerp(to, share)
	if kind != Kind.PELLET:
		return on_line
	var apex := (
		maxf(from.y, to.y)
		+ ARC_BASE
		+ ARC_PER_METRE * Vector2(to.x - from.x, to.z - from.z).length()
	)
	# a parabola through both ends that peaks at `apex` (above the straight line)
	var lift := 4.0 * share * (1.0 - share) * (apex - (from.y + to.y) / 2.0)
	return on_line + Vector3(0.0, lift, 0.0)


## Throws a shot of `kind` from `from` to `to`, with a confetti ring `splash` cells wide at
## the target when it is above 0. When every slot is busy the oldest is reused.
func add_shot(from: Vector3, to: Vector3, splash: float, kind: Kind = Kind.DART) -> void:
	if from.is_equal_approx(to):
		return
	if splash > 0.0:
		kind = Kind.PELLET
	var slot := _next
	_next = (_next + 1) % MAX_SHOTS
	_kind[slot] = kind
	_age[slot] = 0.0
	_flight[slot] = flight_of(kind, from, to)
	_life[slot] = life_of(kind, from, to)
	_splash[slot] = splash
	_from[slot] = from
	_to[slot] = to
	_bodies[slot].mesh = _pellet_mesh if kind == Kind.PELLET else _dart_mesh
	_rings[slot].visible = false
	_bursts[slot].visible = false
	_draw(slot)


## Ages the shots by `delta` seconds: they fly, pop and go.
func update(delta: float) -> void:
	for i in MAX_SHOTS:
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			_life[i] = 0.0
			_bodies[i].visible = false
			_bursts[i].visible = false
			_rings[i].visible = false
			continue
		_draw(i)


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
		_glows[shown].position = _beam_to[shown]
		_glows[shown].visible = true
		shown += 1
	for i in range(shown, _beams_shown):
		_beams[i].visible = false
		_glows[i].visible = false
	_beams_shown = shown


func visible_shots() -> int:
	var count := 0
	for i in MAX_SHOTS:
		if _life[i] > 0.0:
			count += 1
	return count


func visible_beams() -> int:
	return _beams_shown


## The dart or pellet of a shot slot.
func shot_body(index: int) -> MeshInstance3D:
	return _bodies[index]


## The scraps or confetti a shot slot bursts into at its target.
func shot_burst(index: int) -> MeshInstance3D:
	return _bursts[index]


func shot_ring(index: int) -> MeshInstance3D:
	return _rings[index]


func shot_kind(index: int) -> Kind:
	return _kind[index] as Kind


func drawn_from(index: int) -> Vector3:
	return _from[index]


func drawn_to(index: int) -> Vector3:
	return _to[index]


func beam_line(index: int) -> MeshInstance3D:
	return _beams[index]


func beam_glow(index: int) -> MeshInstance3D:
	return _glows[index]


func beam_from(index: int) -> Vector3:
	return _beam_from[index]


func beam_to(index: int) -> Vector3:
	return _beam_to[index]


## Puts a slot where its stepped age says: in flight, or bursting at the target.
func _draw(slot: int) -> void:
	var age := floorf(_age[slot] * FPS + 1e-6) / FPS
	var kind := _kind[slot] as Kind
	var body := _bodies[slot]
	if age < _flight[slot]:
		var share := age / _flight[slot]
		var here := point_on_flight(kind, _from[slot], _to[slot], share)
		var ahead := point_on_flight(kind, _from[slot], _to[slot], minf(share + 0.05, 1.0))
		if kind == Kind.PELLET:
			# a tumbling ball of paper
			body.basis = Basis(Vector3(1, 0, 1).normalized(), age * 14.0)
		else:
			_point_along(body, ahead - here if ahead != here else _to[slot] - _from[slot])
		body.position = here
		body.visible = true
		return
	body.visible = false
	var t := (age - _flight[slot]) / (_life[slot] - _flight[slot])
	var burst := _bursts[slot]
	burst.position = _to[slot] + Vector3(0.0, -0.25 * t * t, 0.0)
	if kind == Kind.PELLET:
		var reach := maxf(_splash[slot], 0.5)
		burst.scale = Vector3.ONE * (0.4 + 0.8 * t) * reach
		var ring := _rings[slot]
		ring.visible = true
		ring.position = Vector3(_to[slot].x, RING_HEIGHT, _to[slot].z)
		var grow := (0.55 + 0.45 * t) * _splash[slot]
		ring.scale = Vector3(grow, 1.0, grow)
	else:
		burst.scale = Vector3.ONE * (0.15 + 0.35 * t)
	burst.rotation.y = age * 3.0
	burst.visible = true


## Turns a dart so its tip (the model's +Z) points along `along`.
func _point_along(body: MeshInstance3D, along: Vector3) -> void:
	var dir := along.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	body.basis = Basis.looking_at(-dir, up).scaled(Vector3.ONE * DART_SCALE)


func _foe_with_id(game: GameState, id: int) -> Foe:
	for foe in game.foes:
		if foe.id == id and foe.alive:
			return foe
	return null


## Lays a unit-long tube between two points: centred between them, pointing along
## them and stretched to their distance.
func _place_line(line: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var up := Vector3.UP if absf(along.normalized().y) < 0.99 else Vector3.RIGHT
	var facing := Basis.looking_at(along.normalized(), up)
	# scale along the tube's own long axis, not along the world's
	line.basis = facing * Basis.from_scale(Vector3(1.0, 1.0, along.length()))
	line.position = (from + to) / 2.0
	line.visible = true


func _node(mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	if material != null:
		node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


## The Spool Guard's own dart (its model's Dart part, in the papercraft look), or a thin box.
func _load_dart() -> Mesh:
	var packed := ModelLoader.scene(DART_MODEL)
	if packed != null:
		var root := packed.instantiate()
		var part := root.find_child(DART_PART) as MeshInstance3D
		var found: Mesh = PaperLook.dress(part.mesh) if part != null else null
		root.free()
		if found != null:
			return found
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.6)
	box.material = PaperLook.paper(SCRAP_COLOURS[0])
	return box


## A crumpled ball of paper: a low sphere whose corners are pushed in and out by a hash of
## where they are, flat shaded, in the paper look.
func _crumpled_ball(radius: float) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var rings := 5
	var segments := 7
	var points: Array[Vector3] = []
	for r in rings + 1:
		var lat := PI * float(r) / float(rings)
		for s in segments:
			var lon := TAU * float(s) / float(segments)
			var dir := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			var dent := 0.78 + 0.34 * CellHash.of(r, s, 7, 31)
			points.append(dir * radius * (dent if r > 0 and r < rings else 0.9))
	surface.set_color(Color(SCRAP_COLOURS[4].srgb_to_linear(), 0.0))
	for r in rings:
		for s in segments:
			var a := points[r * segments + s]
			var b := points[r * segments + (s + 1) % segments]
			var c := points[(r + 1) * segments + (s + 1) % segments]
			var d := points[(r + 1) * segments + s]
			for p in [a, c, b, a, d, c]:
				surface.add_vertex(p)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, PaperLook.material("paper_vc"))
	return mesh


## Paper scraps flung out round a point: small cards at fixed places and tilts, each in a
## paper colour, one mesh so a burst is one draw call. Scaled up as it flies apart.
func _scraps() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 10
	for k in count:
		var ang := TAU * float(k) / float(count) + 0.4 * CellHash.of(k, 1, 3, 41)
		var out := 0.6 + 0.4 * CellHash.of(k, 2, 3, 41)
		var centre := Vector3(cos(ang) * out, 0.25 + 0.5 * CellHash.of(k, 3, 3, 41), sin(ang) * out)
		var tilt := Basis(
			Vector3(cos(ang), 0.3, sin(ang)).normalized(), TAU * CellHash.of(k, 4, 3, 41)
		)
		var half := 0.07 + 0.04 * CellHash.of(k, 5, 3, 41)
		var colour := SCRAP_COLOURS[k % SCRAP_COLOURS.size()].srgb_to_linear()
		surface.set_color(Color(colour, 0.0))
		surface.set_normal(tilt.y)
		var corners := [
			centre + tilt * Vector3(-half, 0, -half),
			centre + tilt * Vector3(half, 0, -half),
			centre + tilt * Vector3(half, 0, half),
			centre + tilt * Vector3(-half, 0, half)
		]
		for i in [0, 1, 2, 0, 2, 3]:
			surface.add_vertex(corners[i])
	var mesh := surface.commit()
	mesh.surface_set_material(0, PaperLook.material("paper_vc"))
	return mesh


## A unit-long tube along z (UV.x round it, UV.y along it from the tower end), for the beam.
func _tube(radius: float, sides: int) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in sides:
		var a0 := TAU * float(s) / float(sides)
		var a1 := TAU * float(s + 1) / float(sides)
		var p := [
			Vector3(cos(a0) * radius, sin(a0) * radius, 0.5),
			Vector3(cos(a1) * radius, sin(a1) * radius, 0.5),
			Vector3(cos(a1) * radius, sin(a1) * radius, -0.5),
			Vector3(cos(a0) * radius, sin(a0) * radius, -0.5)
		]
		var uv := [
			Vector2(float(s) / sides, 0.0),
			Vector2(float(s + 1) / sides, 0.0),
			Vector2(float(s + 1) / sides, 1.0),
			Vector2(float(s) / sides, 1.0)
		]
		var n0 := Vector3(cos(a0), sin(a0), 0.0)
		var n1 := Vector3(cos(a1), sin(a1), 0.0)
		var normals := [n0, n1, n1, n0]
		for i in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(normals[i])
			surface.set_uv(uv[i])
			surface.add_vertex(p[i])
	return surface.commit()


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
