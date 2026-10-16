// The white pencil circle etched round a socket. `glow` lets the board flash it.
shader_type spatial;

uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 pencil_a : source_color = vec3(0.62, 0.62, 0.60);
uniform vec3 pencil_b : source_color = vec3(0.74, 0.74, 0.72);
uniform float glow = 0.0;

void fragment() {
	float streak = texture(paper_noise, vec2(UV.x * 0.5, UV.y * 0.05)).r;
	ALBEDO = mix(pencil_a, pencil_b, streak);
	ROUGHNESS = 0.8;
	EMISSION = vec3(glow);
}
