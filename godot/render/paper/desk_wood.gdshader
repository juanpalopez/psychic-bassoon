// The varnished wooden desk round the mat: grain along x, planks across z.
shader_type spatial;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 wood_dark : source_color = vec3(0.58, 0.42, 0.27);
uniform vec3 wood_light : source_color = vec3(0.69, 0.52, 0.35);
uniform vec3 seam_colour : source_color = vec3(0.30, 0.20, 0.12);
uniform float plank = 4.5;

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

void fragment() {
	float n = texture(paper_noise, vec2(world_pos.x * 0.035, world_pos.z * 0.45)).g;
	float rings = fract(n * 9.0);
	vec3 col = mix(wood_dark, wood_light, smoothstep(0.2, 0.8, rings));
	float seam = grid_line(world_pos.z / plank + 0.3, 0.002);
	ALBEDO = mix(col, seam_colour, seam);
	ROUGHNESS = 0.32 + rings * 0.12;
	SPECULAR = 0.5;
}
