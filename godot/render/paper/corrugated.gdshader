// Corrugated cardboard: kraft liner on top, and on the cut sides the wavy fluting between
// two liners (UV.y runs 0 to 1 up each sheet; the wave follows the world, so it lines up
// across tiles). Painted paper (painted.gdshaderinc).
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"

uniform vec3 kraft_a : source_color = vec3(0.62, 0.49, 0.33);
uniform vec3 kraft_b : source_color = vec3(0.70, 0.57, 0.40);
uniform vec3 fibre_colour : source_color = vec3(0.75, 0.63, 0.46);
uniform vec3 flute_colour : source_color = vec3(0.67, 0.54, 0.37);
uniform vec3 liner_colour : source_color = vec3(0.59, 0.46, 0.31);
uniform vec3 cavity_colour : source_color = vec3(0.12, 0.08, 0.05);
uniform float flute_length = 0.26;

void vertex() {
	PAINTED_VERTEX
}

void fragment() {
	vec4 n = texture(paper_noise, painted_world.xz * 0.6);
	float top = smoothstep(0.5, 0.6, painted_up.y);
	vec2 along_dir = normalize(vec2(-painted_up.z, painted_up.x) + vec2(1e-5));
	float along = dot(painted_world.xz, along_dir);
	float v = UV.y;
	float aa = fwidth(v) + 0.01;
	float wave = 0.5 + 0.3 * sin(along * 6.2831853 / flute_length);
	float flute = 1.0 - smoothstep(0.06, 0.06 + aa, abs(v - wave));
	float liner = max(1.0 - smoothstep(0.11, 0.11 + aa, v), smoothstep(0.89 - aa, 0.89, v));
	vec3 side = mix(cavity_colour, flute_colour, flute);
	side = mix(side, liner_colour, liner);
	vec3 kraft = mix(kraft_a, kraft_b, n.g);
	kraft = mix(kraft, fibre_colour, n.r * 0.35);
	kraft *= 0.94 + 0.06 * sin(painted_world.x * 6.2831853 / flute_length);
	PAINTED_PAPER(mix(side, kraft, top), 1.0)
}
