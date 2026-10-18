// Magic: painted paper lit from inside by a cool glow (STYLE.md: cool cyan, and the Blot's
// purple when a material asks for it), bright enough for the Environment's glow to bloom it
// against the warm sun. The vertex alpha masks where it glows (1 everywhere by default); the
// glow is strongest where the surface faces the camera and softer at its rim, like light
// coming through card.
shader_type spatial;
render_mode cull_disabled;

#include "res://render/paper/painted.gdshaderinc"

// The paper under the glow, pale so the sun on it does not wash the glow out to white.
uniform vec3 tint : source_color = vec3(0.6, 0.8, 0.85);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// The cool cyan of the Prism Spire and the Heartstone's magic (#5ff0ff).
uniform vec3 magic : source_color = vec3(0.373, 0.941, 1.0);
uniform float magic_energy : hint_range(0.0, 8.0) = 1.6;
uniform float magic_rim : hint_range(0.0, 1.0) = 0.45;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	vec3 base = tint * texture(albedo_map, UV).rgb * COLOR.rgb;
	PAINTED_PAPER(base, 1.0)
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = magic * magic_energy * COLOR.a * mix(1.0, facing, magic_rim);
}
