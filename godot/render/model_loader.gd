## Loads the owner's greybox models (`assets/models`), and says nothing when a file is
## missing so that the caller can fall back to a primitive.
class_name ModelLoader
extends RefCounted


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
