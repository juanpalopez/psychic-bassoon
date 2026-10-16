// Masking tape: crinkles across the strip, darker torn edges, and the mat's grid showing
// faintly through it. UV.x runs along the strip in metres, UV.y across it from 0 to 1.
shader_type spatial;
render_mode cull_disabled;

uniform vec2 board_half = vec2(8.0, 5.5);
uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 tape_light : source_color = vec3(0.71, 0.62, 0.46);
uniform vec3 tape_dark : source_color = vec3(0.67, 0.58, 0.42);
uniform vec3 edge_colour : source_color = vec3(0.53, 0.44, 0.30);
uniform vec3 grid_through : source_color = vec3(0.58, 0.58, 0.46);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 1 on a thin line where v is a whole number, anti-aliased by the screen-space slope
float grid_line(float v, float half_width) {
	float d = abs(v - round(v));
	float aa = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(half_width, half_width + aa, d);
}

float crinkle(vec2 uv) {
	return texture(paper_noise, vec2(uv.x * 0.45, uv.y * 0.11)).a;
}

void fragment() {
	float c = crinkle(UV);
	vec3 col = mix(tape_light, tape_dark, smoothstep(0.25, 0.75, c));
	vec2 g = world_pos.xz + board_half;
	float through = max(grid_line(g.x, 0.008), grid_line(g.y, 0.008));
	col = mix(col, grid_through, through * 0.22);
	float edge = max(1.0 - smoothstep(0.0, 0.07, UV.y), smoothstep(0.93, 1.0, UV.y));
	ALBEDO = mix(col, edge_colour, edge * 0.55);
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
	float dx = crinkle(UV + vec2(0.004, 0.0)) - c;
	float dy = crinkle(UV + vec2(0.0, 0.016)) - c;
	NORMAL_MAP = normalize(vec3(-dx * 2.5, -dy * 2.5, 1.0)) * 0.5 + 0.5;
}
