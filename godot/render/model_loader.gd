## Loads the owner's greybox models (`assets/models`), and says nothing when a file is
## missing so that the caller can fall back to a primitive.
class_name ModelLoader
extends RefCounted

static var _bounds := {}


## The scene of a model file, or null when it is missing or not a scene.
static func scene(path: String) -> PackedScene:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


## The first mesh found in a model file, or null when the file is missing or has none.
static func mesh(path: String) -> Mesh:
	var packed := scene(path)
	if packed == null:
		return null
	var root := packed.instantiate()
	var found := first_mesh(root)
	root.free()
	return found


## The first mesh under a node (the node itself first), or null.
static func first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := first_mesh(child)
		if found != null:
			return found
	return null


## The box round every mesh of a model file in its rest pose, in the model's own space
## (cached per file), or an empty box when the file is missing.
static func bounds(path: String) -> AABB:
	if _bounds.has(path):
		return _bounds[path]
	var packed := scene(path)
	if packed == null:
		return AABB()
	var root := packed.instantiate() as Node3D
	var box := bounds_of(root, Transform3D.IDENTITY)
	root.free()
	_bounds[path] = box
	return box


## The box round every mesh under `node`, `to_root` placing `node` in the root's space.
static func bounds_of(node: Node, to_root: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := to_root
	if node is Node3D:
		here = to_root * (node as Node3D).transform if node.get_parent() != null else to_root
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = here * (node as MeshInstance3D).mesh.get_aabb()
		first = false
	for child in node.get_children():
		var inner := bounds_of(child, here)
		if inner.size == Vector3.ZERO:
			continue
		box = inner if first else box.merge(inner)
		first = false
	return box
