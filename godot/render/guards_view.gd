## The guards of the Guard Tents, drawn at their posts on the road: a capsule each
## with a health bar over it, hidden while the guard is down. One node per guard,
## kept between calls, so calling `update` every frame creates nothing. It only
## reads the game.
class_name GuardsView
extends Node3D

## Where the road surface is, so a guard stands on it (as the foes do).
const GROUND := 0.06
const BODY_RADIUS := 0.2
const BODY_HEIGHT := 0.7
const BAR_WIDTH := 0.5
const BAR_THICKNESS := 0.06
const BAR_GAP := 0.12
const BODY_COLOUR := Color("d94a3d")
const BAR_COLOUR := Color("7be07b")

var _nodes := {}


## Shows each guard of the game at its post, adds the new ones and drops the gone.
func update(game: GameState) -> void:
	var seen := {}
	for guard in game.guards:
		seen[guard.id] = true
		var node: Node3D = _nodes.get(guard.id)
		if node == null:
			node = _make()
			_nodes[guard.id] = node
			add_child(node)
		var at := game.routes[0].position_at(guard.post)
		var world := BoardSpace.point_to_world(at.x, at.y)
		node.position = Vector3(world.x, GROUND + BODY_HEIGHT / 2.0, world.z)
		node.visible = guard.alive
		var bar := node.get_node("Bar") as Node3D
		bar.scale.x = clampf(guard.hp / guard.max_hp, 0.0, 1.0)
	for id in _nodes.keys():
		if not seen.has(id):
			var gone: Node = _nodes[id]
			_nodes.erase(id)
			remove_child(gone)
			gone.queue_free()


func guard_count() -> int:
	return _nodes.size()


func is_shown(guard_id: int) -> bool:
	return (_nodes[guard_id] as Node3D).visible


func position_of(guard_id: int) -> Vector3:
	return (_nodes[guard_id] as Node3D).position


## The bar's length as a share of the full bar.
func health_fraction_of(guard_id: int) -> float:
	return ((_nodes[guard_id] as Node3D).get_node("Bar") as Node3D).scale.x


func _make() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body.mesh = capsule
	body.material_override = _flat(BODY_COLOUR)
	root.add_child(body)
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var box := BoxMesh.new()
	box.size = Vector3(BAR_WIDTH, BAR_THICKNESS, BAR_THICKNESS)
	bar.mesh = box
	bar.material_override = _flat(BAR_COLOUR)
	bar.position.y = BODY_HEIGHT / 2.0 + BAR_GAP
	root.add_child(bar)
	return root


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
