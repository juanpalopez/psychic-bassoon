## Triangles collected for one mesh: flat-shaded corners with vertex colours (rgb in linear
## light, alpha the baked contact shading), turned so the front face looks along its normal.
class_name MeshBucket
extends RefCounted

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colours := PackedColorArray()


## One triangle facing `normal` (its corners are swapped if they wind the other way). Godot
## draws clockwise triangles as front faces, so the corners' own right-handed normal must
## point away from `normal`.
func tri(
	a: Vector3, b: Vector3, c: Vector3, normal: Vector3, ca: Color, cb: Color, cc: Color
) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
		var swap_colour := cb
		cb = cc
		cc = swap_colour
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	colours.append(ca)
	colours.append(cb)
	colours.append(cc)


## A flat quad a, b, c, d (in order round its edge) facing `normal`.
func quad(
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3,
	ca: Color,
	cb: Color,
	cc: Color,
	cd: Color
) -> void:
	tri(a, b, c, normal, ca, cb, cc)
	tri(a, c, d, normal, ca, cc, cd)


## A triangle whose normal comes from its corners, turned to face along `outward`.
func facet(
	a: Vector3, b: Vector3, c: Vector3, outward: Vector3, ca: Color, cb: Color, cc: Color
) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		return
	normal = normal.normalized()
	if normal.dot(outward) < 0.0:
		normal = -normal
	tri(a, b, c, normal, ca, cb, cc)


func triangle_count() -> int:
	return int(vertices.size() / 3.0)


func is_empty() -> bool:
	return vertices.is_empty()


func to_mesh() -> ArrayMesh:
	return DioramaBuilder.triangles_mesh(vertices, normals, colours)
