// The painted paper and card of the diorama (terrain, props, towers, foes): the colour is the
// vertex colour times `tint` times an optional `albedo_map`, and the contact shading and the
// folds are baked by the builder into the vertex alpha, UV2 or a map on UV2. The light, the
// paper and the matte finish come from painted.gdshaderinc. Closed models only (the back
// faces are culled).
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// The vertex colours of a glTF are linear; a mesh built in Godot with sRGB colours sets this.
uniform bool vertex_colour_is_srgb = false;
// What the builder baked: contact (1 open, 0 shut in) in the vertex alpha or the bake map's
// red, and folds (1 on a crease) in UV2.x or the bake map's green.
uniform int contact_from : hint_enum("None", "Vertex alpha", "Bake map on UV2 (red)") = 1;
uniform int fold_from : hint_enum("None", "UV2.x", "Bake map on UV2 (green)") = 0;
uniform sampler2D bake_map : hint_default_white, filter_linear_mipmap;

void vertex() {
	PAINTED_VERTEX
	if (vertex_colour_is_srgb) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	vec3 base = tint * texture(albedo_map, UV).rgb * COLOR.rgb;
	vec2 mapped = texture(bake_map, UV2).rg;
	float baked = contact_from == 1 ? COLOR.a : (contact_from == 2 ? mapped.r : 1.0);
	float folded = fold_from == 1 ? UV2.x : (fold_from == 2 ? mapped.g : 0.0);
	PAINTED_PAPER(base, baked, folded)
}
