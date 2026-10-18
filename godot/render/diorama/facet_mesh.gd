## A mesh of flat-shaded facets with their colours in the vertex colours, for the diorama's
## generated props: each triangle keeps its own normal, so the faces read as folded card, and the
## whole prop is one surface (one draw call). Triangles are wound so that their front faces
## point away from the `centre` given with them (Godot's front faces are clockwise).
class_name FacetMesh
extends RefCounted

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colours := PackedColorArray()


## How many triangles so far.
func triangle_count() -> int:
	return _vertices.size() / 3


## One facet, its front facing away from `centre` (a point inside the solid it is part of).
func triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color, centre: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-14:
		return
	normal = normal.normalized()
	if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
		normal = -normal
		var swap := b
		b = c
		c = swap
	# counter-clockwise seen from the normal's side, turned to Godot's clockwise front
	for point: Vector3 in [a, c, b]:
		_vertices.append(point)
		_normals.append(normal)
		_colours.append(colour)


## One facet with a colour at each corner (soft across the face, as on a dirt patch or a blade
## of grass), its front facing away from `centre`.
func shaded_triangle(corners: Array[Vector3], colours: Array[Color], centre: Vector3) -> void:
	var a := corners[0]
	var b := corners[1]
	var c := corners[2]
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-14:
		return
	normal = normal.normalized()
	var order: Array[int] = [0, 2, 1]
	if normal.dot((a + b + c) / 3.0 - centre) < 0.0:
		normal = -normal
		order = [0, 1, 2]
	for k in order:
		_vertices.append(corners[k])
		_normals.append(normal)
		_colours.append(colours[k])


## A flat four-sided facet (two triangles), corners in order round its edge.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, centre: Vector3) -> void:
	triangle(a, b, c, colour, centre)
	triangle(a, c, d, colour, centre)


## A box of `size` centred on `at`, turned by `basis`; the faces looking down are left out when
## `bottom` is false (a box resting on something never shows them). Side faces take `colour` a
## little darker than the top, as card does when the light comes from above.
func box(at: Vector3, basis: Basis, size: Vector3, colour: Color, bottom: bool = true) -> void:
	var h := size / 2.0
	var corners: Array[Vector3] = []
	for k in 8:
		var local := Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z)
		corners.append(at + basis * local)
	var side := colour.darkened(0.12)
	quad(corners[2], corners[3], corners[7], corners[6], colour, at)
	quad(corners[0], corners[1], corners[3], corners[2], side, at)
	quad(corners[4], corners[5], corners[7], corners[6], side, at)
	quad(corners[0], corners[4], corners[6], corners[2], side.darkened(0.05), at)
	quad(corners[1], corners[5], corners[7], corners[3], side.darkened(0.05), at)
	if bottom:
		quad(corners[0], corners[1], corners[5], corners[4], side.darkened(0.2), at)


## A thin square beam from `from` to `to`, `thickness` across, with no end caps.
func beam(from: Vector3, to: Vector3, thickness: float, colour: Color) -> void:
	var along := to - from
	if along.length_squared() < 1e-12:
		return
	var axis := along.normalized()
	var helper := Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u := axis.cross(helper).normalized() * thickness / 2.0
	var v := axis.cross(u).normalized() * thickness / 2.0
	var centre := (from + to) / 2.0
	var ring: Array[Vector3] = [u + v, u - v, -u - v, -u + v]
	for k in 4:
		var p := ring[k]
		var q := ring[(k + 1) % 4]
		var shade := colour.darkened(0.08 * float(k % 2))
		quad(from + p, to + p, to + q, from + q, shade, centre)


## The mesh, one surface wearing `material`. The colours were given in sRGB (as the palette is
## written) and are stored linear, which is what a shader's ALBEDO wants.
func commit(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _vertices.is_empty():
		return mesh
	var linear := PackedColorArray()
	linear.resize(_colours.size())
	for i in _colours.size():
		linear[i] = _colours[i].srgb_to_linear()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = linear
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
