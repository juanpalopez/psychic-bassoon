// Corrugated cardboard: kraft liner on top, and on the cut sides the wavy fluting between
// two liners (UV.y runs 0 to 1 up each sheet; the wave follows the world, so it lines up
// across tiles).
shader_type spatial;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 kraft_a : source_color = vec3(0.62, 0.49, 0.33);
uniform vec3 kraft_b : source_color = vec3(0.70, 0.57, 0.40);
uniform vec3 fibre_colour : source_color = vec3(0.75, 0.63, 0.46);
uniform vec3 flute_colour : source_color = vec3(0.67, 0.54, 0.37);
uniform vec3 liner_colour : source_color = vec3(0.59, 0.46, 0.31);
uniform vec3 cavity_colour : source_color = vec3(0.12, 0.08, 0.05);
uniform float flute_length = 0.26;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 n = texture(paper_noise, world_pos.xz * 0.6);
	float top = smoothstep(0.5, 0.6, world_normal.y);
	vec2 along_dir = normalize(vec2(-world_normal.z, world_normal.x) + vec2(1e-5));
	float along = dot(world_pos.xz, along_dir);
	float v = UV.y;
	float aa = fwidth(v) + 0.01;
	float wave = 0.5 + 0.3 * sin(along * 6.2831853 / flute_length);
	float flute = 1.0 - smoothstep(0.06, 0.06 + aa, abs(v - wave));
	float liner = max(1.0 - smoothstep(0.11, 0.11 + aa, v), smoothstep(0.89 - aa, 0.89, v));
	vec3 side = mix(cavity_colour, flute_colour, flute);
	side = mix(side, liner_colour, liner);
	vec3 kraft = mix(kraft_a, kraft_b, n.g);
	kraft = mix(kraft, fibre_colour, n.r * 0.35);
	kraft *= 0.94 + 0.06 * sin(world_pos.x * 6.2831853 / flute_length);
	ALBEDO = mix(side, kraft, top);
	ROUGHNESS = mix(0.95, 0.85, top);
}
