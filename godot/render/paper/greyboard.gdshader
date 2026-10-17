// Laminated grey board: sheets 10 cm thick in slightly different greys with darker glue
// lines between them, a speckled top, and the odd coloured recycled fleck.
shader_type spatial;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 grey_dark : source_color = vec3(0.38, 0.37, 0.36);
uniform vec3 grey_light : source_color = vec3(0.60, 0.59, 0.57);
uniform vec3 glue_colour : source_color = vec3(0.27, 0.26, 0.25);
uniform vec3 top_a : source_color = vec3(0.55, 0.54, 0.52);
uniform vec3 top_b : source_color = vec3(0.62, 0.61, 0.59);
uniform vec3 fleck_colour : source_color = vec3(0.35, 0.40, 0.53);
uniform float sheet = 0.1;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(float k) {
	return fract(sin(k * 127.1) * 43758.5453);
}

void fragment() {
	float k = floor(world_pos.y / sheet);
	float f = fract(world_pos.y / sheet);
	vec3 side = mix(grey_dark, grey_light, hash(k));
	float glue = 1.0 - smoothstep(0.03, 0.07 + fwidth(f), f);
	side = mix(side, glue_colour, glue * 0.7);
	vec4 n = texture(paper_noise, world_pos.xz * 0.7 + vec2(world_pos.y * 0.3));
	vec3 top_col = mix(top_a, top_b, n.g);
	float top = smoothstep(0.5, 0.6, world_normal.y);
	vec3 col = mix(side, top_col, top);
	ALBEDO = mix(col, fleck_colour, smoothstep(0.8, 0.84, n.b) * 0.5);
	ROUGHNESS = 0.92;
}
