// The green self-healing cutting mat: a printed grid on the cell edges (and half-cell
// lines inside the board), faint healed cuts, and a dark core on the cut edge of the mat.
// Painted paper (painted.gdshaderinc), matte like the rest.
shader_type spatial;

#include "res://render/paper/painted.gdshaderinc"

uniform vec2 board_half = vec2(8.0, 5.5);
uniform sampler2D cuts : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 mat_dark : source_color = vec3(0.10, 0.29, 0.21);
uniform vec3 mat_light : source_color = vec3(0.13, 0.33, 0.24);
uniform vec3 line_major : source_color = vec3(0.37, 0.57, 0.44);
uniform vec3 line_minor : source_color = vec3(0.29, 0.48, 0.37);
uniform vec3 cut_colour : source_color = vec3(0.25, 0.43, 0.33);
uniform vec3 core_colour : source_color = vec3(0.06, 0.06, 0.07);

void vertex() {
	PAINTED_VERTEX
}

// 1 on a thin line where v is a whole number, anti-aliased by the screen-space slope
float grid_line(float v, float half_width) {
	float d = abs(v - round(v));
	float aa = max(fwidth(v), 1e-4);
	return 1.0 - smoothstep(half_width, half_width + aa, d);
}

void fragment() {
	vec2 g = painted_world.xz + board_half;
	float inside = step(abs(painted_world.x), board_half.x - 0.01) * step(abs(painted_world.z), board_half.y - 0.01);
	float major = max(grid_line(g.x, 0.008), grid_line(g.y, 0.008));
	float minor = max(grid_line(g.x * 2.0, 0.008), grid_line(g.y * 2.0, 0.008)) * inside;
	vec4 n = texture(paper_noise, painted_world.xz * 0.37);
	vec3 col = mix(mat_dark, mat_light, n.b);
	col = mix(col, line_minor, minor * 0.35);
	col = mix(col, line_major, major * 0.8);
	float cut = texture(cuts, painted_world.xz * 0.21).r * smoothstep(0.35, 0.65, n.g);
	col = mix(col, cut_colour, cut * 0.5);
	float side = 1.0 - smoothstep(0.5, 0.6, abs(painted_up.y));
	vec3 side_col = mix(core_colour, mat_light, step(-0.035, painted_world.y));
	PAINTED_PAPER(mix(col, side_col, side), 1.0, 0.0)
}
